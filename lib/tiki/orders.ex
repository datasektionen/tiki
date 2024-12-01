defmodule Tiki.Orders do
  @moduledoc """
  The Orders context.
  """

  import Ecto.Query, warn: false
  alias Tiki.Tickets.TicketType
  alias Ecto.Multi
  alias Phoenix.PubSub
  alias Tiki.Orders.Order
  alias Tiki.Orders.Ticket
  alias Tiki.Tickets
  alias Tiki.Repo

  @doc """
  Returns the list of order.

  ## Examples

      iex> list_orders()
      [%Order{}, ...]

  """
  def list_orders do
    Repo.all(Order)
  end

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
      left_join: t in assoc(o, :tickets),
      left_join: tt in assoc(t, :ticket_type),
      left_join: u in assoc(o, :user),
      left_join: stc in assoc(o, :stripe_checkout),
      left_join: swc in assoc(o, :swish_checkout),
      preload: [tickets: {t, ticket_type: tt}, user: u, stripe_checkout: stc, swish_checkout: swc]
  end

  @doc """
  Creates a order.

  ## Examples

      iex> create_order(%{field: value})
      {:ok, %Order{}}

      iex> create_order(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_order(attrs \\ %{}) do
    %Order{}
    |> Order.changeset(attrs)
    |> Repo.insert(returning: [:id])
  end

  @doc """
  Updates a order.

  ## Examples

      iex> update_order(order, %{field: new_value})
      {:ok, %Order{}}

      iex> update_order(order, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_order(%Order{} = order, attrs) do
    order
    |> Order.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a order.

  ## Examples

      iex> delete_order(order)
      {:ok, %Order{}}

      iex> delete_order(order)
      {:error, %Ecto.Changeset{}}

  """
  def delete_order(%Order{} = order) do
    Repo.delete(order)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking order changes.

  ## Examples

      iex> change_order(order)
      %Ecto.Changeset{data: %Order{}}

  """
  def change_order(%Order{} = order, attrs \\ %{}) do
    Order.changeset(order, attrs)
  end

  @doc """
  Returns the list of ticket.

  ## Examples

      iex> list_ticket()
      [%Ticket{}, ...]

  """
  def list_tickets do
    Repo.all(Ticket)
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
  Creates a ticket.

  ## Examples

      iex> create_ticket(%{field: value})
      {:ok, %Ticket{}}

      iex> create_ticket(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ticket(attrs \\ %{}) do
    %Ticket{}
    |> Ticket.changeset(attrs)
    |> Repo.insert(returning: [:id])
  end

  @doc """
  Deletes a ticket.

  ## Examples

      iex> delete_ticket(ticket)
      {:ok, %Ticket{}}

      iex> delete_ticket(ticket)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ticket(%Ticket{} = ticket) do
    Repo.delete(ticket)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ticket changes.

  ## Examples

      iex> change_ticket(ticket)
      %Ecto.Changeset{data: %Ticket{}}

  """
  def change_ticket(%Ticket{} = ticket, attrs \\ %{}) do
    Ticket.changeset(ticket, attrs)
  end

  @doc """
  Reserves tickets for an event. Returns the order.

  ## Examples
      iex> reserve_tickets(123, [12, 1, ...], 456)
      {:ok, %Order{}}

      iex> reserve_tickets(232, [], 456)
      {:error, "Du måste välja minst en biljett"}
  """
  def reserve_tickets(event_id, ticket_types, _user_id \\ nil) do
    result =
      Multi.new()
      |> Multi.run(:positive_tickets, fn _repo, _ ->
        case Map.values(ticket_types) |> Enum.sum() do
          0 -> {:error, "order must contain at least one ticket"}
          _ -> {:ok, :ok}
        end
      end)
      |> Multi.run(:prices, fn repo, _ ->
        tt_ids = Enum.map(ticket_types, fn {tt, _} -> tt end)

        prices =
          repo.all(from tt in TicketType, where: tt.id in ^tt_ids, select: {tt.id, tt.price})
          |> Enum.into(%{})

        total = Enum.reduce(prices, 0, fn {tt, price}, acc -> price * ticket_types[tt] + acc end)

        {:ok, Map.put(prices, :total, total)}
      end)
      |> Multi.insert(
        :order,
        fn %{prices: %{total: total_price}} ->
          change_order(%Order{}, %{event_id: event_id, status: :pending, price: total_price})
        end,
        returning: [:id]
      )
      |> Multi.insert_all(
        :tickets,
        Ticket,
        fn %{order: order, prices: prices} ->
          Enum.flat_map(ticket_types, fn {tt, count} ->
            for _ <- 1..count do
              %{ticket_type_id: tt, order_id: order.id, price: prices[tt]}
            end
          end)
        end,
        returning: true
      )
      |> Tickets.get_availible_ticket_types_multi(event_id)
      |> Multi.run(:check_availability, fn _repo, %{ticket_types_availible: available} ->
        valid_for_event? =
          Map.keys(ticket_types)
          |> Enum.all?(fn tt -> Enum.any?(available, &(&1.ticket_type.id == tt)) end)

        with true <- valid_for_event?,
             true <- Enum.all?(available, &(&1.available >= 0)) do
          {:ok, :ok}
        else
          _ -> {:error, "not enough tickets available"}
        end
      end)
      |> Multi.run(:preloaded_order, fn _repo,
                                        %{
                                          order: order,
                                          tickets: {_, tickets},
                                          ticket_types_availible: available
                                        } ->
        ticket_types =
          Enum.map(available, & &1.ticket_type)
          |> Enum.reduce(%{}, &Map.put(&2, &1.id, &1))

        tickets = Enum.map(tickets, &Map.put(&1, :ticket_type, ticket_types[&1.ticket_type_id]))
        {:ok, Map.put(order, :tickets, tickets)}
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{preloaded_order: order, ticket_types_availible: ticket_types}} ->
        # Monitor the order, automatically cancels it if it's not paid in time
        Tiki.PurchaseMonitor.monitor(order)

        broadcast(
          order.event_id,
          {:tickets_updated, Tickets.put_avalable_ticket_meta(ticket_types)}
        )

        broadcast_order(order.id, :created, order)

        {:ok, order}

      {:error, :check_availability, message, _} ->
        {:error, message}

      {:error, :positive_tickets, message, _} ->
        {:error, message}
    end
  end

  @doc """
  <<<<<<< HEAD
  Confirms an order, ie. marks it as paid. Returns the order.

  ## Examples
      iex> confirm_order(%Order{})
      {:ok, %Order{}}

      iex> confirm_order(%Order{})
      {:error, %Ecto.Changeset{}}
  """
  def confirm_order(order, user_id) do
    case update_order(order, %{status: "paid", user_id: user_id}) do
      {:error, changeset} ->
        {:error, changeset}

      {:ok, order} ->
        broadcast(order.event_id, {:tickets_updated, get_availible_ticket_types(order.event_id)})

        broadcast(
          order.event_id,
          :purchases,
          {:order_confirmed, get_order!(order.id)}
        )

        {:ok, order}
    end
  end

  @doc """
  =======
  >>>>>>> main
  Cancels an order if it exists. Returns the order.

  ## Examples
      iex> cancel_order(%Order{})
      {:ok, %Order{}}

      iex> cancel_order(%Order{})
      {:error, reason}
  """
  def maybe_cancel_reservation(order_id) do
    multi =
      Multi.new()
      |> Multi.run(:order, fn repo, _changes ->
        case repo.one(from o in Order, where: o.id == ^order_id) do
          nil -> {:error, :not_found}
          %Order{status: :pending} = order -> {:ok, order}
          %Order{} -> {:error, :not_pending}
        end
      end)
      |> Multi.delete_all(:delete_tickets, fn %{order: order} ->
        from t in Ticket, where: t.order_id == ^order.id
      end)
      |> Multi.update(:order_failed, fn %{order: order} ->
        change_order(order, %{status: :cancelled})
      end)

    case Repo.transaction(multi) do
      {:ok, %{order_failed: order}} ->
        broadcast(
          order.event_id,
          {:tickets_updated, Tickets.get_availible_ticket_types(order.event_id)}
        )

        broadcast_order(order.id, :cancelled, order)

        {:ok, order}

      {:error, :order, :not_found, _} ->
        {:error, "Order not found, nothing to cancel"}

      {:error, :order, :not_pending, _} ->
        {:error, "Order is not pending"}

      _ ->
        {:error, "Could not cancel reservation"}
    end
  end

  @doc """
  Returns the orders for an event, ordered by most recent first.

  ## Examples

      iex> list_orders_for_event(event_id)
      [%Order{tickets: [%Ticket{ticket_type: %TicketType{}}, ...], user: %User{}}, ...]
  """
  def list_orders_for_event(event_id) do
    order_query()
    |> where([o], o.event_id == ^event_id)
    |> order_by([o], desc: o.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the orders for all events in a team, ordered by most recent first.

  Options:
    * `:limit` - The maximum number of tickets to return.

  ## Examples

      iex> list_team_orders(event_id)
      [%Order{tickets: [%Ticket{ticket_type: %TicketType{}}, ...], user: %User{}}, ...]
  """
  def list_team_orders(team_id, opts \\ []) do
    query =
      order_query()
      |> join(:inner, [o], e in assoc(o, :event))
      |> where([..., e], e.team_id == ^team_id)
      |> order_by([o], desc: o.inserted_at)
      |> preload([..., e], event: e)

    case Keyword.get(opts, :limit) do
      nil -> query
      limit -> query |> limit(^limit)
    end
    |> Repo.all()

    Repo.all(query)
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
    query =
      from t in Ticket,
        join: o in assoc(t, :order),
        join: tt in assoc(t, :ticket_type),
        join: u in assoc(o, :user),
        order_by: [desc: o.inserted_at],
        where: o.event_id == ^event_id,
        preload: [ticket_type: tt, order: {o, user: u}]

    case Keyword.get(opts, :limit) do
      nil -> query
      limit -> query |> limit(^limit)
    end
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
