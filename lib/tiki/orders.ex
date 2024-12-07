defmodule Tiki.Orders do
  @moduledoc """
  The Orders context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Phoenix.PubSub
  alias Tiki.Orders.Order
  alias Tiki.Orders.Ticket
  alias Tiki.Tickets
  alias Tiki.Repo

  alias Tiki.OrderHandler

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
  Reserves tickets for an event. Returns the order.

  ## Examples
      iex> reserve_tickets(123, %{12 => 2, 1 => 1, ...}, 456)
      {:ok, %Order{}}

      iex> reserve_tickets(232, %{12 => 0}, 456)
      {:error, "order must contain at least one ticket"}
  """
  def reserve_tickets(event_id, ticket_types) do
    with {:ok, _pid} <- OrderHandler.Worker.ensure_started(event_id),
         {:ok, order, ticket_types} <- OrderHandler.Worker.reserve_tickets(event_id, ticket_types) do
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
          {:tickets_updated, Tickets.get_available_ticket_types(order.event_id)}
        )

        broadcast_order(order.id, :cancelled, order)

        {:ok, order}

      {:error, :order, :not_found, _} ->
        {:error, "order not found, nothing to cancel"}

      {:error, :order, :not_pending, _} ->
        {:error, "order is not pending"}

      _ ->
        {:error, "could not cancel reservation"}
    end
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
    |> join(:inner, [o], e in assoc(o, :event))
    |> where([o, ..., e], e.team_id == ^team_id and o.status in ^statuses)
    |> order_by([o], desc: o.inserted_at)
    |> preload([..., e], event: e)
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
