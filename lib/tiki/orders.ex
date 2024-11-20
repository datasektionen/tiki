defmodule Tiki.Orders do
  @moduledoc """
  The Orders context.
  """

  import Ecto.Query, warn: false
  alias Tiki.Tickets.TicketType
  alias Ecto.Multi
  alias Phoenix.PubSub
  alias Tiki.Tickets.Ticket
  alias Tiki.Tickets
  alias Tiki.Repo

  alias Tiki.Orders.Order

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
    query =
      from o in Order,
        where: o.id == ^id,
        left_join: t in assoc(o, :tickets),
        left_join: tt in assoc(t, :ticket_type),
        join: u in assoc(o, :user),
        preload: [tickets: {t, ticket_type: tt}, user: u]

    Repo.one!(query)
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
    |> Repo.insert()
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

  alias Tiki.Orders.Ticket

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
        preload: [ticket_type: tt, order: {o, user: u}]

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
    |> Repo.insert()
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
  def reserve_tickets(event_id, ticket_types, user_id) do
    dbg(ticket_types)

    result =
      Multi.new()
      |> Multi.run(:positive_tickets, fn _repo, _ ->
        case Map.values(ticket_types) |> Enum.sum() do
          0 -> {:error, "Du måste välja minst en biljett"}
          _ -> {:ok, :ok}
        end
      end)
      |> Multi.run(:total_price, fn repo, _ ->
        tt_ids = Enum.map(ticket_types, fn {tt, _} -> tt end)
        prices = repo.all(from tt in TicketType, where: tt.id in ^tt_ids)
        {:ok, Enum.reduce(prices, 0, fn tt, acc -> tt.price * ticket_types[tt.id] + acc end)}
      end)
      |> Multi.insert(
        :order,
        fn %{total_price: total_price} ->
          change_order(%Order{}, %{event_id: event_id, status: :pending, price: total_price})
        end,
        returning: [:id]
      )
      |> Multi.insert_all(:tickets, Ticket, fn %{order: order} ->
        Enum.flat_map(ticket_types, fn {tt, count} ->
          for _ <- 1..count do
            %{ticket_type_id: tt, order_id: order.id}
          end
        end)
      end)
      |> Tickets.get_availible_ticket_types_multi(event_id)
      |> Multi.run(:check_availability, fn _repo, %{ticket_types_availible: available} ->
        case Enum.all?(available, &(&1.available >= 0)) do
          true -> {:ok, :ok}
          false -> {:error, "Det fanns inte tillräckligt med biljetter"}
        end
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{order: order, ticket_types_availible: ticket_types}} ->
        broadcast(
          order.event_id,
          {:tickets_updated, Tickets.put_avalable_ticket_meta(ticket_types)}
        )

        {:ok, order}

      {:error, :check_availability, message, _} ->
        {:error, message}

      {:error, :positive_tickets, message, _} ->
        {:error, message}
    end
  end

  @doc """
  Confirms an order, ie. marks it as paid. Returns the order.

  ## Examples
      iex> confirm_order(%Order{})
      {:ok, %Order{}}

      iex> confirm_order(%Order{})
      {:error, %Ecto.Changeset{}}
  """
  def confirm_order(order) do
    case update_order(order, %{status: "paid"}) do
      {:error, changeset} ->
        {:error, changeset}

      {:ok, order} ->
        broadcast(
          order.event_id,
          {:tickets_updated, Tickets.get_availible_ticket_types(order.event_id)}
        )

        broadcast(
          order.event_id,
          :purchases,
          {:order_confirmed, get_order!(order.id)}
        )

        {:ok, order}
    end
  end

  @doc """
  Cancels an order if it exists. Returns the order.

  ## Examples
      iex> cancel_order(%Order{})
      {:ok, %Order{}}

      iex> cancel_order(%Order{})
      {:error, reason}
  """
  def maybe_cancel_reservation(order) do
    multi =
      Multi.new()
      |> Multi.run(:order, fn repo, _changes ->
        case repo.one(from o in Order, where: o.id == ^order.id) do
          nil -> {:error, :not_found}
          %Order{status: :pending} -> {:ok, order}
          %Order{} -> {:error, :not_pending}
        end
      end)
      |> Multi.delete_all(:delete_tickets, fn %{order: order} ->
        from t in Ticket, where: t.order_id == ^order.id
      end)
      |> Multi.update(:set_order_failed, fn %{order: order} ->
        change_order(order, %{status: :cancelled})
      end)

    result = multi |> Repo.transaction()

    case result do
      {:ok, _} ->
        broadcast(
          order.event_id,
          {:tickets_updated, Tickets.get_availible_ticket_types(order.event_id)}
        )

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
    query =
      from o in Order,
        where: o.event_id == ^event_id,
        join: t in assoc(o, :tickets),
        join: tt in assoc(t, :ticket_type),
        join: u in assoc(o, :user),
        order_by: [desc: o.inserted_at],
        preload: [tickets: {t, ticket_type: tt}, user: u]

    Repo.all(query)
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
      from o in Order,
        join: e in assoc(o, :event),
        where: e.team_id == ^team_id,
        join: t in assoc(o, :tickets),
        join: tt in assoc(t, :ticket_type),
        join: u in assoc(o, :user),
        order_by: [desc: o.inserted_at],
        preload: [tickets: {t, ticket_type: tt}, user: u, event: e]

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

  defp broadcast(event_id, :purchases, message) do
    PubSub.broadcast(Tiki.PubSub, "event:#{event_id}:purchases", message)
  end

  def broadcast(event_id, message) do
    PubSub.broadcast(Tiki.PubSub, "event:#{event_id}", message)
  end

  def subscribe(event_id, :purchases) do
    PubSub.subscribe(Tiki.PubSub, "event:#{event_id}:purchases")
  end

  def subscribe(event_id) do
    PubSub.subscribe(Tiki.PubSub, "event:#{event_id}")
  end

  def unsubscribe(event_id) do
    PubSub.unsubscribe(Tiki.PubSub, "event:#{event_id}")
  end
end
