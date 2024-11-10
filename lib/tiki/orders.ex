defmodule Tiki.Orders do
  @moduledoc """
  The Orders context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Phoenix.PubSub
  alias Tiki.Tickets.TicketBatch
  alias Tiki.Tickets.TicketType
  alias Tiki.Tickets.Ticket
  alias Tiki.Repo

  alias Tiki.Orders.Order

  defmodule TreeBuilder do
    @moduledoc """
    Module for building a tree of ticket batches.
    """

    @doc """
    Builds a tree of ticket batches from a :digraph recursively.
    Propagates the purchased count up the tree and mutates the graph.

    ## Examples

        iex> build(graph, 0)
        %{batch: %Tiki.Tickets.TicketBatch{...}, children: [...], purchased: 0}
    """
    def build(graph, vertex) do
      children =
        for child <- :digraph.in_neighbours(graph, vertex) do
          build(graph, child)
        end

      {^vertex, label} = :digraph.vertex(graph, vertex)

      sum_purchased = Enum.reduce(children, 0, fn child, acc -> acc + child.purchased end)

      label =
        Map.put(label, :children, children)
        |> Map.put(:purchased, sum_purchased + label.purchased)

      :digraph.add_vertex(graph, vertex, label)
      label
    end

    @doc """
    Returns a map of available tickets for each batch in the tree, note
    that tree must be built first to propagate the purchased count up the tree.

    ## Examples

        iex> available(graph, 0)
        %{0 => :infinity, 2 => 3, ...}
    """
    def available(graph, node) do
      available_helper(graph, node, :infinity)
    end

    defp available_helper(graph, vertex, count) do
      {^vertex, label} = :digraph.vertex(graph, vertex)

      available =
        case label.batch.max_size do
          nil -> count
          max_size -> min(count, max_size - label.purchased)
        end

      children = :digraph.in_neighbours(graph, vertex)

      available_childs =
        Enum.reduce(children, %{}, fn child, acc ->
          Map.merge(acc, available_helper(graph, child, available))
        end)

      Map.merge(available_childs, %{vertex => available})
    end
  end

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
        join: t in assoc(o, :tickets),
        join: tt in assoc(t, :ticket_type),
        left_join: u in assoc(o, :user),
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
  Updates a ticket.

  ## Examples

      iex> update_ticket(ticket, %{field: new_value})
      {:ok, %Ticket{}}

      iex> update_ticket(ticket, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ticket(%Ticket{} = ticket, attrs) do
    ticket
    |> Ticket.changeset(attrs)
    |> Repo.update()
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
      iex> reserve_tickets(123, [%TicketType{}, ...], 456)
      {:ok, %Order{}}

      iex> reserve_tickets(232, [%TicketType{}, ...], 456)
      {:error, "Du måste välja minst en biljett"}
  """
  def reserve_tickets(event_id, ticket_types, user_id) do
    result =
      Multi.new()
      |> Multi.run(:positive_tickets, fn _repo, _ ->
        case length(ticket_types) do
          0 -> {:error, "Du måste välja minst en biljett"}
          _ -> {:ok, :ok}
        end
      end)
      |> Multi.insert(:order, %Order{user_id: user_id, event_id: event_id, status: :pending})
      |> Multi.insert_all(:tickets, Ticket, fn %{order: order} ->
        Enum.flat_map(ticket_types, fn tt ->
          for _ <- 1..tt.count do
            %{ticket_type_id: tt.id, order_id: order.id}
          end
        end)
      end)
      |> get_availible_ticket_types_multi(event_id)
      |> Multi.run(:check_availability, fn _repo, %{ticket_types_availible: available} ->
        case Enum.all?(available, &(&1.available >= 0)) do
          true -> {:ok, :ok}
          false -> {:error, "Det fanns inte tillräckligt med biljetter"}
        end
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{order: order}} ->
        broadcast(order.event_id, {:tickets_updated, get_availible_ticket_types(order.event_id)})
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
        broadcast(order.event_id, {:tickets_updated, get_availible_ticket_types(order.event_id)})
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
  Returns the availible ticket types for an event. Returns a list of ticket types,
  with the number of available tickets, purchased tickets and pending tickets.

  ## Examples
      iex> get_availible_ticket_types(123)
      [
        %TicketType{
          available: 10,
          purchased: 0,
          pending: 0,
          ...
        },
        %TicketType{
          available: 10,
          purchased: 4,
          pending: 2,
          ...
        }
      ]
  """
  def get_availible_ticket_types(event_id) do
    result =
      Multi.new()
      |> get_availible_ticket_types_multi(event_id)
      |> Repo.transaction()

    case result do
      {:ok, %{ticket_types_availible: ticket_types}} ->
        Enum.map(ticket_types, fn tt ->
          tt.ticket_type
          |> Map.put(:available, tt.available)
          |> Map.put(:purchased, tt.purchased)
          |> Map.put(:pending, tt.pending)
        end)

      other ->
        other
    end
  end

  defp get_availible_ticket_types_multi(multi, event_id) do
    # Subquery for counting tickets based on status
    sub =
      from tt in TicketType,
        join: tb in assoc(tt, :ticket_batch),
        left_join: t in assoc(tt, :tickets),
        join: o in assoc(t, :order),
        where: tb.event_id == ^event_id,
        group_by: tt.id,
        select: %{ticket_type_id: tt.id, count: count(t.id)}

    sub_pending = sub |> where([tt, tb, t, o], o.status == ^"pending")
    sub_purchased = sub |> where([tt, tb, t, o], o.status == ^"paid")

    # Query for ticket types and their counts
    query =
      from tt in TicketType,
        join: tb in assoc(tt, :ticket_batch),
        left_join: pt in subquery(sub_pending),
        on: tt.id == pt.ticket_type_id,
        left_join: pt2 in subquery(sub_purchased),
        on: tt.id == pt2.ticket_type_id,
        where: tb.event_id == ^event_id,
        select: %{ticket_type: tt, purchased: pt2.count, pending: pt.count}

    multi
    |> get_batch_tree_multi(event_id)
    |> Multi.run(:available, fn _repo, %{graph: {batch_tree, root}} ->
      # Propagate the number of purchased tickets up the tree
      TreeBuilder.build(batch_tree, root)

      # Get the number of available tickets for each batch
      available = TreeBuilder.available(batch_tree, root)

      # Not garbage collected, so we need to delete it
      :digraph.delete(batch_tree)

      {:ok, available}
    end)
    |> Multi.all(:ticket_types, query)
    |> Multi.run(:ticket_types_availible, fn _repo,
                                             %{available: available, ticket_types: ticket_types} ->
      ticket_types =
        Enum.map(ticket_types, fn tt ->
          Map.put(tt, :purchased, tt.purchased || 0)
          |> Map.put(:pending, tt.pending || 0)
          |> Map.put(:available, available[tt.ticket_type.ticket_batch_id])
        end)

      {:ok, ticket_types}
    end)
  end

  defp get_batch_tree_multi(multi, event_id) do
    # Get the root batches
    root_batches_query =
      from tb in TicketBatch,
        where: tb.event_id == ^event_id,
        where: is_nil(tb.parent_batch_id)

    # Get all batches recursively
    batches_recursion_query =
      from tb in TicketBatch,
        where: tb.event_id == ^event_id,
        inner_join: ctb in "batch_tree",
        on: tb.parent_batch_id == ctb.id

    batches_query =
      root_batches_query
      |> union_all(^batches_recursion_query)

    query =
      TicketBatch
      |> where([tb], tb.event_id == ^event_id)
      |> recursive_ctes(true)
      |> with_cte("batch_tree", as: ^batches_query)
      |> join(:left, [tb], tt in assoc(tb, :ticket_types))
      |> join(:left, [tb, tt], t in assoc(tt, :tickets))
      |> group_by([tb, tt, t], tb.id)
      |> select([tb, tt, t], %{batch: tb, purchased: count(t.id)})

    Multi.all(multi, :batches, query)
    |> Multi.run(:graph, fn _repo, %{batches: batches} ->
      # We now have an array of batches with the number of tickets purchased for
      # each batch. We now need to build the tree.
      fake_root = %{batch: %TicketBatch{id: 0, name: "fake_root"}, purchased: 0}

      graph = :digraph.new()

      for %{batch: %TicketBatch{id: id}} = node <- [fake_root | batches] do
        :digraph.add_vertex(graph, id, node)
      end

      for %{batch: %TicketBatch{id: id, parent_batch_id: parent_id}} <- batches do
        :digraph.add_edge(graph, id, parent_id || fake_root.batch.id)
      end

      {:ok, {graph, fake_root.batch.id}}
    end)
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
