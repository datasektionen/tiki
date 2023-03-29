defmodule Tiki.Orders do
  @moduledoc """
  The Orders context.
  """

  import Ecto.Query, warn: false
  alias Tiki.Tickets.TicketBatch
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
  def get_order!(id), do: Repo.get!(Order, id)

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
  def get_ticket!(id), do: Repo.get!(Ticket, id)

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

  def purchase_tickets(ticket_types, user_id) do
    Repo.transaction(fn ->
      order =
        %Order{user_id: user_id}
        |> Repo.insert!()

      tickets =
        Enum.map(ticket_types, fn tt ->
          %Ticket{ticket_type_id: tt.id, order_id: order.id}
        end)

      Enum.each(tickets, fn t -> Repo.insert!(t) end)
    end)
  end

  @doc """
  Reserves tickets for an event. Returns the order.

  ## Examples
      iex> reserve_tickets(123, [%TicketType{}, ...], 456)
      %Order{}
  """
  def reserve_tickets(event_id, ticket_types, user_id) do
    purchased_tickets = get_purchased_batches(event_id)

    create_order = fn repo, _ ->
      %Order{user_id: user_id, event_id: event_id, status: :reserved}
      |> Repo.insert()
    end

    verify_order = fn repo, order ->
      nil
    end

    Repo.transaction(fn ->
      order =
        %Order{user_id: user_id, event_id: event_id, status: :reserved}
        |> Repo.insert!()

      tickets =
        Enum.map(ticket_types, fn tt ->
          %Ticket{ticket_type_id: tt.id, order_id: order.id}
        end)

      Enum.each(tickets, fn t -> Repo.insert!(t) end)

      order
    end)
  end

  defmodule TreeBuilder do
    def build(graph, vertex) do
      children =
        for child <- :digraph.in_neighbours(graph, vertex) do
          build(graph, child)
        end

      {^vertex, label} = :digraph.vertex(graph, vertex)

      sum_purchased = Enum.reduce(children, 0, fn child, acc -> acc + child.purchased end)

      Map.put(label, :children, children)
      |> Map.put(:purchased, sum_purchased + label.purchased)
    end
  end

  @doc """
  Returns a tree of ticket batches for an event, where
  each batch has an id, min, max, and the number of tickets
  purchased for that batch. Note that the top level batch
  is a virtual batch that represents the entire event.

  ## Examples
      iex> get_purchased_batches(123)
      %{batch: %TicketBatch{}, purchased: 2, min: 1, max: 10, children: [...]}
  """
  def get_purchased_batches(event_id) do
    root_batches_query =
      from tb in TicketBatch,
        where: tb.event_id == ^event_id,
        where: is_nil(tb.parent_batch_id)

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

    results = Repo.all(query)

    # We now have an array of batches with the number of tickets purchased for each batch. We now need to build the tree.
    fake_root = %{batch: %TicketBatch{id: 0}, purchased: 0}

    graph = :digraph.new()

    for %{batch: %TicketBatch{id: id}} = node <- [fake_root | results] do
      :digraph.add_vertex(graph, id, node)
    end

    for %{batch: %TicketBatch{id: id, parent_batch_id: parent_id}} <- results do
      :digraph.add_edge(graph, id, parent_id || fake_root.batch.id)
    end

    tree = TreeBuilder.build(graph, fake_root.batch.id)
  end

  @doc """
  Returns the list of purchased ticket types for an event, along
  with the number of tickets purchased for each type. Useful when
  initializing the order GenServers.
  ## Examples
      iex> get_purchased_ticket_types(123)
      [%{ticket_type: %TicketType{}, purchased: 2}, ...]
  """
  def get_purchased_ticket_types(event_id) do
    query =
      from t in Ticket,
        right_join: tt in assoc(t, :ticket_type),
        right_join: tb in assoc(tt, :ticket_batch),
        where: tb.event_id == ^event_id,
        select: %{ticket_type: tt, purchased: count(t.id)},
        group_by: tt.id

    Repo.all(query)
  end
end
