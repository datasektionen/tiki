defmodule Tiki.Orders do
  @moduledoc """
  The Orders context.
  """

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
  Reserves tickets for an event. Returns the order.

  ## Examples
      iex> reserve_tickets(123, %{12 => 2, 1 => 1, ...}, 456)
      {:ok, %Order{}}

      iex> reserve_tickets(232, %{12 => 0}, 456)
      {:error, "order must contain at least one ticket"}
  """
  def reserve_tickets(event_id, ticket_types) do
    with {:ok, order, ticket_types} <- OrderHandler.Worker.reserve_tickets(event_id, ticket_types) do
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
  def init_checkout(order, payment_method, %{name: name, email: email} = userdata) do
    locale = Map.get(userdata, :locale, "en")

    case Accounts.upsert_user_email(email, name, locale: locale) do
      {:ok, user} -> init_checkout(order, payment_method, user.id)
      {:error, reason} -> {:error, reason}
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
  defp create_payment(order, "swish"), do: Checkouts.create_swish_payment_request(order)
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

  ## Examples

      iex> list_tickets_for_event(event_id)
      [%Ticket{ticket_type: %TicketType{}}, %Order{user: %User{}}], ...]
  """
  def list_tickets_for_event(event_id, opts \\ []) do
    from(t in Ticket,
      join: o in assoc(t, :order),
      join: tt in assoc(t, :ticket_type),
      join: u in assoc(o, :user),
      order_by: [desc: o.inserted_at],
      where: o.event_id == ^event_id,
      preload: [ticket_type: tt, order: {o, user: u}]
    )
    |> then(fn query ->
      case Keyword.get(opts, :limit) do
        nil -> query
        limit -> query |> limit(^limit)
      end
    end)
    |> Repo.all()
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

  def subscribe(event_id, :purchases) do
    PubSub.subscribe(Tiki.PubSub, "event:#{event_id}:purchases")
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
end
