defmodule Tiki.Orders do
  @moduledoc """
  The Orders context.
  """

  use Gettext, backend: TikiWeb.Gettext

  import Ecto.Query, warn: false
  alias Tiki.Accounts
  alias Tiki.Checkouts
  alias Tiki.Orders.OrderNotifier
  alias Ecto.Multi
  alias Phoenix.PubSub
  alias Tiki.Orders.Order
  alias Tiki.Orders.Ticket
  alias Tiki.Orders.AuditLog
  alias Tiki.Tickets
  alias Tiki.Repo

  alias Tiki.OrderHandler
  alias Tiki.Orders.CancelWorker

  @doc """
  Gets a single order.

  Raises `Ecto.NoResultsError` if the Order does not exist.

  ## Examples

      iex> get_order!(123)
      %Order{}

      iex> get_order!(456)
      ** (Ecto.NoResultsError)

  """
  def get_order!(id) do
    order_query()
    |> where([o], o.id == ^id)
    |> Repo.one!()
  end

  defp order_query(_opts \\ []) do
    from o in Order,
      join: e in assoc(o, :event),
      left_join: t in assoc(o, :tickets),
      left_join: tt in assoc(t, :ticket_type),
      left_join: u in assoc(o, :user),
      left_join: stc in assoc(o, :stripe_checkout),
      left_join: swc in assoc(o, :swish_checkout),
      preload: [
        tickets: {t, ticket_type: tt},
        user: u,
        stripe_checkout: stc,
        swish_checkout: swc,
        event: e
      ]
  end

  def get_order_logs(id) do
    Repo.all(from ol in AuditLog, where: ol.order_id == ^id, order_by: {:desc, ol.inserted_at})
  end

  @doc """
  Gets a single ticket.

  Raises `Ecto.NoResultsError` if the Ticket does not exist.

  ## Examples

      iex> get_ticket!(123)
      %Ticket{}

      iex> get_ticket!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ticket!(id) do
    query =
      from t in Ticket,
        where: t.id == ^id,
        join: tt in assoc(t, :ticket_type),
        join: o in assoc(t, :order),
        join: u in assoc(o, :user),
        left_join: fr in assoc(t, :form_response),
        left_join: fqr in assoc(fr, :question_responses),
        left_join: q in assoc(fqr, :question),
        preload: [
          ticket_type: tt,
          order: {o, user: u},
          form_response: {fr, question_responses: {fqr, question: q}}
        ]

    Repo.one!(query)
  end

  @doc """
  Toggles check in on a ticket in a ticket. Returns the ticket. Sets the checked in time to the current time.

  Options:
    * `:check_out` - If true, removes the checked in time from the ticket if it was previously checked in. Defaults to true.
  """
  def toggle_check_in(event_id, ticket_id, opts \\ []) do
    transaction =
      Repo.transaction(fn ->
        ticket =
          case tickets_query()
               |> where([t], t.id == ^ticket_id)
               |> Repo.one() do
            %Ticket{} = ticket -> ticket
            nil -> Repo.rollback(gettext("Ticket not found"))
          end

        if ticket.order.event_id != event_id,
          do: Repo.rollback(gettext("Ticket not valid for event"))

        case ticket.checked_in_at do
          nil ->
            Repo.update!(Ticket.changeset(ticket, %{checked_in_at: DateTime.utc_now()}))

          _ ->
            if Keyword.get(opts, :check_out, true),
              do: Repo.update!(Ticket.changeset(ticket, %{checked_in_at: nil})),
              else: Repo.rollback(gettext("Ticket already checked in"))
        end
      end)

    case transaction do
      {:ok, ticket} ->
        broadcast_ticket(ticket.order.event_id, ticket)
        {:ok, ticket}

      err ->
        err
    end
  end

  @doc """
  Reserves tickets for an event. Returns the order.

  ## Examples
      iex> reserve_tickets(123, %{12 => 2, 1 => 1, ...}, 456)
      {:ok, %Order{}}

      iex> reserve_tickets(232, %{12 => 0}, 456)
      {:error, "order must contain at least one ticket"}
  """
  def reserve_tickets(event_id, ticket_types, user_id \\ nil) do
    with {:ok, order, ticket_types} <-
           OrderHandler.Worker.reserve_tickets(event_id, ticket_types, user_id) do
      # Monitor the order, automatically cancels it if it's not paid in time
      Tiki.PurchaseMonitor.monitor(order)

      broadcast(
        order.event_id,
        {:tickets_updated, Tickets.put_available_ticket_meta(ticket_types)}
      )

      broadcast_order(order.id, :created, order)

      {:ok, order}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Cancels a pending order if it exists. Does not modify paid or cancelled orders.
  Returns the order.

  ## Examples
      iex> cancel_order(%Order{})
      {:ok, %Order{}}

      iex> cancel_order(%Order{})
      {:error, reason}
  """
  def maybe_cancel_order(order_id) do
    multi =
      Multi.new()
      |> Multi.run(:order, fn repo, _changes ->
        case repo.one(from o in Order, where: o.id == ^order_id) do
          nil -> {:error, :not_found}
          %Order{} = order -> {:ok, order}
        end
      end)
      |> Multi.run(:transition_valid, fn _repo, %{order: order} ->
        Order.valid_transition?(order.status, :cancelled) |> wrap_bool("invalid transition")
      end)
      |> Multi.delete_all(:delete_tickets, fn %{order: order} ->
        from t in Ticket, where: t.order_id == ^order.id
      end)
      |> Multi.update(:order_failed, fn %{order: order} ->
        Order.changeset(order, %{status: :cancelled})
      end)
      |> Multi.run(:audit, fn _repo, %{order_failed: order} ->
        AuditLog.log(order.id, "order.cancelled", order)
      end)

    case Repo.transaction(multi) do
      {:ok, %{order_failed: order}} ->
        broadcast(
          order.event_id,
          {:tickets_updated, Tickets.get_available_ticket_types(order.event_id)}
        )

        broadcast_order(order.id, :cancelled, order)

        # Queue the Swish cancellation job if there's a Swish checkout
        CancelWorker.enqueue(order.id)

        {:ok, order}

      {:error, :order, :not_found, _} ->
        {:error, "order not found, nothing to cancel"}

      {:error, :transition_valid, _, _} ->
        {:error, "order is not cancellable"}

      _ ->
        {:error, "could not cancel reservation"}
    end
  end

  defp wrap_bool(bool, message) do
    case bool do
      true -> {:ok, :ok}
      false -> {:error, message}
    end
  end

  @doc """
  Initializes a checkout for an order. Returns the uptaded order with associated checkout.

  Can be provided with a user_id to associate the checkout with a user, or a user_data map
  to create a new user and associate the checkout with that user. The keys `name` and
  `email` are required.

  ## Examples

      iex> init_checkout(order, "credit_card", user_id: 123)
      {:ok, %Order{}}

      iex> init_checkout(order, "credit_card", %{name: "John Doe", email: "john@doe.com", locale: "sv"})
      {:ok, %Order{}}

  """

  def init_checkout(%Order{} = order, payment_method, %{name: name, email: email} = userdata) do
    locale = Map.get(userdata, :locale, "en")

    case Accounts.upsert_user_email(email, name, locale: locale) do
      {:ok, user} -> init_checkout(order, payment_method, user.id)
      {:error, reason} -> {:error, reason}
    end
  end

  def init_checkout(%Order{price: 0} = order, _payment_method, user_id)
      when is_integer(user_id) do
    with true <- Order.valid_transition?(order.status, :paid),
         {:ok, order} <- update_order(order, %{user_id: user_id, status: :paid}) do
      AuditLog.log(order.id, "order.checkout.free", order)

      confirm_order(order)

      {:ok, order}
    else
      {:error, reason} ->
        {:error, reason}

      false ->
        {:error, "cannot initiate checkout from order state"}
    end
  end

  def init_checkout(order, payment_method, user_id) when is_integer(user_id) do
    with true <- Order.valid_transition?(order.status, :checkout),
         {:ok, order} <- update_order(order, %{user_id: user_id, status: :checkout}),
         {:ok, checkout} <- create_payment(order, payment_method),
         order <- put_checkout(order, checkout) do
      AuditLog.log(order.id, "order.checkout.#{payment_method}", order)

      {:ok, order}
    else
      {:error, reason} ->
        {:error, reason}

      false ->
        {:error, "cannot initiate checkout from order state"}
    end
  end

  def init_checkout(_, _, _), do: {:error, "user_id or userdata is invalid"}

  defp update_order(%Order{} = order, attrs) do
    order
    |> Order.changeset(attrs)
    |> Repo.update()
  end

  defp create_payment(order, "credit_card"), do: Checkouts.create_stripe_payment_intent(order)

  defp create_payment(%Order{event: %Tiki.Events.Event{}} = order, "swish"),
    do: Checkouts.create_swish_payment_request(order)

  defp create_payment(_order, _), do: {:error, "not a valid payment method"}

  defp put_checkout(order, %Checkouts.SwishCheckout{} = checkout),
    do: Map.put(order, :swish_checkout, checkout)

  defp put_checkout(order, %Checkouts.StripeCheckout{} = checkout),
    do: Map.put(order, :stripe_checkout, checkout)

  @doc """
  Confirms an order after it has been paid. Returns the order. Does
  some stuff like sending emails, logging, and broadcasting the order
  over PubSub.
  """
  def confirm_order(%Order{status: :paid} = order) do
    order = get_order!(order.id)

    # Send email confirmaiton
    OrderNotifier.deliver(order)
    # Audit log
    AuditLog.log(order.id, "order.paid", order)

    broadcast_order(order.id, :paid, order)

    broadcast(
      order.event_id,
      {:tickets_updated, Tickets.get_available_ticket_types(order.event_id)}
    )
  end

  @doc """
  Returns the orders for an event, ordered by most recent first.

  Options:
    * `:status` - The status of the orders to return.

  ## Examples

      iex> list_orders_for_event(event_id, status: [:paid])
      [%Order{tickets: [%Ticket{ticket_type: %TicketType{}}, ...], user: %User{}}, ...]
  """
  def list_orders_for_event(event_id, opts \\ []) do
    statuses = Keyword.get(opts, :status, Ecto.Enum.dump_values(Order, :status))

    order_query()
    |> where([o], o.event_id == ^event_id)
    |> where([o], o.status in ^statuses)
    |> order_by([o], desc: o.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the orders for all events in a team, ordered by most recent first.

  Options:
    * `:limit` - The maximum number of tickets to return.
    * `:status` - The status of the orders to return.

  ## Examples

      iex> list_team_orders(event_id, limit: 10, status: [:paid])
      [%Order{tickets: [%Ticket{ticket_type: %TicketType{}}, ...], user: %User{}}, ...]
  """
  def list_team_orders(team_id, opts \\ []) do
    statuses = Keyword.get(opts, :status, Ecto.Enum.dump_values(Order, :status))

    order_query()
    |> where([o, e], e.team_id == ^team_id and o.status in ^statuses)
    |> order_by([o], desc: o.inserted_at)
    |> then(fn query ->
      case Keyword.get(opts, :limit) do
        nil -> query
        limit -> limit(query, ^limit)
      end
    end)
    |> Repo.all()
  end

  @doc """
  Returns the tikets for an event, ordered by most recent first.

  Options:
    * `:limit` - The maximum number of tickets to return.
    * `:query` - Search query to filter the tickets by, by searching the ticket name or order name.
    * `:ticket_type` - Filter the tickets by ticket type.
    * `:paginate` - A map of pagination options, needs to contain an `after` key,
       which is the cursor to use for pagination and may be `nil` to get the first page. Does not paginate if
       using a search query.

  ## Examples

      iex> list_tickets_for_event(event_id)
      [%Ticket{ticket_type: %TicketType{}}, %Order{user: %User{}}], ...]

      iex> list_tickets_for_event(event_id, query: "John Doe", ticket_type: "asdfsadf-sadfsadf", limit: 10)
      [%Ticket{ticket_type: %TicketType{}}, %Order{user: %User{}}], ...]
  """
  def list_tickets_for_event(event_id, opts \\ []) do
    list_tickets_for_event(event_id, Keyword.get(opts, :paginate, false), opts)
  end

  defp list_tickets_for_event(event_id, false, opts) do
    tickets_query()
    |> where([_t, o], o.event_id == ^event_id)
    |> if_not_empty(Keyword.get(opts, :query), fn query, search_term ->
      query
      |> where(
        [..., u, r],
        fragment(
          "word_similarity(COALESCE(?, ?), ?) > 0.2",
          r.name,
          u.full_name,
          ^search_term
        )
      )
      |> order_by(
        [..., u, r],
        fragment(
          "word_similarity(COALESCE(?, ?), ?)",
          r.name,
          u.full_name,
          ^search_term
        )
      )
    end)
    |> if_not_empty(Keyword.get(opts, :ticket_type), fn query, type ->
      where(query, [t], t.ticket_type_id == ^type)
    end)
    |> if_not_empty(Keyword.get(opts, :limit), fn query, limit -> limit(query, ^limit) end)
    |> Repo.all()
  end

  defp list_tickets_for_event(event_id, %{after: cursor}, opts) do
    limit = Keyword.get(opts, :limit) || raise "limit is required for paginated query"

    pagination_options =
      [
        cursor_fields: [{{:order, :inserted_at}, :desc}],
        limit: limit
      ]
      |> then(fn options ->
        if Keyword.get(opts, :query) in [nil, ""] do
          Keyword.put(options, :after, cursor)
        else
          options
        end
      end)

    tickets_query()
    |> where([_t, o], o.event_id == ^event_id)
    |> if_not_empty(Keyword.get(opts, :query), fn query, search_term ->
      query
      |> where(
        [..., u, r],
        fragment(
          "word_similarity(COALESCE(?, ?), ?) > 0.2",
          r.name,
          u.full_name,
          ^search_term
        )
      )
      |> order_by(
        [..., u, r],
        fragment("word_similarity(COALESCE(?, ?), ?)", r.name, u.full_name, ^search_term)
      )
    end)
    |> if_not_empty(Keyword.get(opts, :ticket_type), fn query, type ->
      where(query, [t], t.ticket_type_id == ^type)
    end)
    |> Repo.paginate(pagination_options)
  end

  defp if_not_empty(query, arg, fun) when is_function(fun, 2) do
    case arg do
      nil -> query
      "" -> query
      arg -> fun.(query, arg)
    end
  end

  defp tickets_query() do
    from(t in Ticket,
      join: o in assoc(t, :order),
      as: :order,
      join: tt in assoc(t, :ticket_type),
      join: u in assoc(o, :user),
      left_join:
        response in subquery(
          from r in Tiki.Forms.Response,
            join: qr in assoc(r, :question_responses),
            join: q in assoc(qr, :question),
            where: q.type == :attendee_name or q.type == :email,
            select: %{
              ticket_id: r.ticket_id,
              name: fragment("MAX(CASE WHEN ? = 'attendee_name' THEN ? END)", q.type, qr.answer),
              email: fragment("MAX(CASE WHEN ? = 'email' THEN ? END)", q.type, qr.answer)
            },
            group_by: r.ticket_id
        ),
      on: response.ticket_id == t.id,
      order_by: [desc: o.inserted_at],
      preload: [ticket_type: tt, order: {o, user: u}],
      select_merge: %{
        name: fragment("COALESCE(?, ?)", response.name, u.full_name),
        email: fragment("COALESCE(?, ?)", response.email, u.email)
      }
    )
  end

  def order_stats_query() do
    from o in Order,
      where: o.status == :paid,
      join: t in assoc(o, :tickets),
      group_by: o.id,
      select: %{
        order_price: o.price,
        ticket_count: count(t.id)
      }
  end

  @doc """
  Lists all orders for a user. Options:

    * `:status` - The status of the orders to return.

  ## Examples

      iex> list_orders_for_user(user_id, status: [:paid])
      [%Order{tickets: [%Ticket{ticket_type: %TicketType{}}, ...], user: %User{}}, ...]
  """
  def list_orders_for_user(user_id, opts \\ []) do
    statuses = Keyword.get(opts, :status, Ecto.Enum.dump_values(Order, :status))

    order_query()
    |> where([o], o.user_id == ^user_id)
    |> where([o], o.status in ^statuses)
    |> order_by([o], desc: o.inserted_at)
    |> Repo.all()
  end

  def broadcast_order(order_id, :created, order) do
    PubSub.broadcast(Tiki.PubSub, "order:#{order_id}", {:created, order})
  end

  def broadcast_order(order_id, :cancelled, order) do
    PubSub.broadcast(Tiki.PubSub, "order:#{order_id}", {:cancelled, order})
  end

  def broadcast_order(order_id, :paid, order) do
    PubSub.broadcast(Tiki.PubSub, "order:#{order_id}", {:paid, order})
  end

  def broadcast(event_id, message) do
    PubSub.broadcast(Tiki.PubSub, "event:#{event_id}", message)
  end

  def broadcast_ticket(event_id, ticket) do
    PubSub.broadcast(Tiki.PubSub, "event:#{event_id}:tickets", {:ticket_updated, ticket})
  end

  def subscribe(event_id, :purchases) do
    PubSub.subscribe(Tiki.PubSub, "event:#{event_id}:purchases")
  end

  def subscribe(event_id, :tickets) do
    PubSub.subscribe(Tiki.PubSub, "event:#{event_id}:tickets")
  end

  def subscribe_to_order(order_id) do
    PubSub.subscribe(Tiki.PubSub, "order:#{order_id}")
  end

  def subscribe(event_id) do
    PubSub.subscribe(Tiki.PubSub, "event:#{event_id}")
  end

  def unsubscribe(event_id) do
    PubSub.unsubscribe(Tiki.PubSub, "event:#{event_id}")
  end

  @doc """
  Changes the ticket type of a ticket.

  Validates that:
  - The new ticket type exists and belongs to the same event
  - Changing the ticket type doesn't violate ticket batch limits
  - The user has permission to make this change

  Returns {:ok, ticket} on success or {:error, reason} on failure.

  ## Examples

      iex> change_ticket_type(scope, ticket_id, new_ticket_type_id)
      {:ok, %Ticket{}}

      iex> change_ticket_type(scope, ticket_id, invalid_ticket_type_id)
      {:error, "ticket type does not belong to the same event"}
  """
  def change_ticket_type(%Tiki.Accounts.Scope{} = scope, ticket_id, new_ticket_type_id) do
    multi =
      Multi.new()
      |> Multi.run(:ticket, fn repo, _ ->
        case repo.one(
               from t in Ticket,
                 where: t.id == ^ticket_id,
                 join: tt in assoc(t, :ticket_type),
                 join: o in assoc(t, :order),
                 join: e in assoc(o, :event),
                 preload: [ticket_type: tt, order: {o, event: e}]
             ) do
          nil -> {:error, gettext("ticket not found")}
          ticket -> {:ok, ticket}
        end
      end)
      |> Multi.run(:authorize, fn _repo, %{ticket: ticket} ->
        case Tiki.Policy.authorize(:event_manage, scope.user, ticket.order.event) do
          :ok -> {:ok, :authorized}
          {:error, _} -> {:error, :unauthorized}
        end
      end)
      |> Multi.run(:new_ticket_type, fn repo, %{ticket: ticket} ->
        case repo.one(
               from tt in Tickets.TicketType,
                 where: tt.id == ^new_ticket_type_id,
                 join: tb in assoc(tt, :ticket_batch),
                 where: tb.event_id == ^ticket.order.event_id,
                 preload: [ticket_batch: tb]
             ) do
          nil -> {:error, gettext("ticket type does not belong to the same event")}
          new_ticket_type -> {:ok, new_ticket_type}
        end
      end)
      |> Multi.run(:validate_limits, fn _repo,
                                        %{
                                          ticket: ticket,
                                          new_ticket_type: new_ticket_type
                                        } ->
        old_ticket_type = ticket.ticket_type

        if old_ticket_type.id == new_ticket_type.id do
          {:error, gettext("ticket type is already set to this value")}
        else
          validate_ticket_type_change(
            ticket.order.event_id,
            old_ticket_type.id,
            new_ticket_type.id
          )
        end
      end)
      |> Multi.update(:updated_ticket, fn %{ticket: ticket, new_ticket_type: new_ticket_type} ->
        Ticket.changeset(ticket, %{
          ticket_type_id: new_ticket_type.id,
          price: new_ticket_type.price
        })
      end)
      |> Multi.run(:audit, fn _repo,
                              %{
                                ticket: old_ticket,
                                updated_ticket: ticket,
                                new_ticket_type: new_ticket_type
                              } ->
        old_ticket_type = old_ticket.ticket_type

        AuditLog.log(ticket.order_id, "ticket.type_changed", %{
          ticket_id: ticket.id,
          old_ticket_type: %{id: old_ticket_type.id, name: old_ticket_type.name},
          new_ticket_type: %{id: new_ticket_type.id, name: new_ticket_type.name},
          changed_by: scope.user.id
        })
      end)

    case Repo.transaction(multi) do
      {:ok, %{updated_ticket: ticket, ticket: original_ticket}} ->
        event_id = original_ticket.order.event_id

        broadcast(
          event_id,
          {:tickets_updated, Tickets.get_available_ticket_types(event_id)}
        )

        broadcast_ticket(event_id, ticket)

        {:ok, get_ticket!(ticket.id)}

      {:error, :authorize, :unauthorized, _} ->
        {:error, :unauthorized}

      {:error, _step, error, _} ->
        {:error, error}
    end
  end

  defp validate_ticket_type_change(event_id, _old_ticket_type_id, new_ticket_type_id) do
    ticket_types = Tickets.get_available_ticket_types(event_id)

    new_tt = Enum.find(ticket_types, &(&1.id == new_ticket_type_id))

    cond do
      is_nil(new_tt) ->
        {:error, gettext("new ticket type not found")}

      new_tt.available < 0 ->
        {:error, gettext("not enough tickets available for the new ticket type")}

      true ->
        {:ok, :valid}
    end
  end
end
