defmodule Tiki.Tickets do
  @moduledoc """
  The Tickets context.
  """

  import Ecto.Query, warn: false
  alias Tiki.Repo
  alias Ecto.Multi

  alias Tiki.Tickets.TreeBuilder
  alias Tiki.Tickets.TicketBatch
  alias Tiki.Workers.EventSchedulerWorker

  @doc """
  Returns the list of ticket_batch.

  ## Examples

      iex> list_ticket_batch()
      [%TicketBatch{}, ...]

  """
  def list_ticket_batches do
    Repo.all(TicketBatch)
  end

  @doc """
  Gets a single ticket_batch.

  Raises `Ecto.NoResultsError` if the Ticket batch does not exist.

  ## Examples

      iex> get_ticket_batch!(123)
      %TicketBatch{}

      iex> get_ticket_batch!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ticket_batch!(id), do: Repo.get!(TicketBatch, id)

  @doc """
  Creates a ticket_batch.

  ## Examples

      iex> create_ticket_batch(%{field: value})
      {:ok, %TicketBatch{}}

      iex> create_ticket_batch(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ticket_batch(attrs \\ %{}) do
    %TicketBatch{}
    |> TicketBatch.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a ticket_batch.

  ## Examples

      iex> update_ticket_batch(ticket_batch, %{field: new_value})
      {:ok, %TicketBatch{}}

      iex> update_ticket_batch(ticket_batch, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ticket_batch(%TicketBatch{} = ticket_batch, attrs) do
    case ticket_batch
         |> TicketBatch.changeset(attrs)
         |> Repo.update() do
      {:ok, batch} ->
        Tiki.Orders.broadcast(
          ticket_batch.event_id,
          {:tickets_updated, get_available_ticket_types(ticket_batch.event_id)}
        )

        {:ok, batch}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a ticket_batch.

  ## Examples

      iex> delete_ticket_batch(ticket_batch)
      {:ok, %TicketBatch{}}

      iex> delete_ticket_batch(ticket_batch)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ticket_batch(%TicketBatch{} = ticket_batch) do
    Repo.delete(ticket_batch)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ticket_batch changes.

  ## Examples

      iex> change_ticket_batch(ticket_batch)
      %Ecto.Changeset{data: %TicketBatch{}}

  """
  def change_ticket_batch(%TicketBatch{} = ticket_batch, attrs \\ %{}) do
    TicketBatch.changeset(ticket_batch, attrs)
  end

  alias Tiki.Tickets.TicketType

  @doc """
  Returns the list of ticket_types.

  ## Examples

      iex> list_ticket_type()
      [%TicketType{}, ...]

  """
  def list_ticket_types do
    Repo.all(TicketType)
  end

  @doc """
  Gets a single ticket_types.

  Raises `Ecto.NoResultsError` if the Ticket type does not exist.

  ## Examples

      iex> get_ticket_type!(123)
      %TicketType{}

      iex> get_ticket_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ticket_type!(id) do
    query =
      from tt in TicketType,
        join: tb in assoc(tt, :ticket_batch),
        where: tt.id == ^id,
        preload: [ticket_batch: tb]

    case Repo.one(query) do
      nil -> raise Ecto.NoResultsError.exception(queryable: query)
      ticket_type -> ticket_type
    end
  end

  @doc """
  Creates a ticket_types.

  ## Examples

      iex> create_ticket_type(%{field: value})
      {:ok, %TicketType{}}

      iex> create_ticket_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ticket_type(attrs \\ %{}) do
    with {:ok, ticket_type} <-
           %TicketType{}
           |> TicketType.changeset(attrs)
           |> Repo.insert(returning: [:id]) do
      EventSchedulerWorker.schedule_ticket_job(ticket_type)

      broadcast_updated(ticket_type)
    end
  end

  @doc """
  Updates a ticket_types.

  ## Examples

      iex> update_ticket_type(ticket_types, %{field: new_value})
      {:ok, %TicketType{}}

      iex> update_ticket_type(ticket_types, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ticket_type(%TicketType{} = ticket_type, attrs) do
    with {:ok, updated_ticket_type} <-
           ticket_type
           |> TicketType.changeset(attrs)
           |> Repo.update() do
      if timing_changed?(ticket_type, updated_ticket_type) do
        EventSchedulerWorker.schedule_ticket_job(updated_ticket_type)
      end

      broadcast_updated(updated_ticket_type)
    end
  end

  @doc """
  Deletes a ticket_types.

  ## Examples

      iex> delete_ticket_type(ticket_types)
      {:ok, %TicketType{}}

      iex> delete_ticket_type(ticket_types)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ticket_type(%TicketType{} = ticket_type) do
    with {:ok, deleted_ticket_type} <- Repo.delete(ticket_type) do
      EventSchedulerWorker.cancel_ticket_job(ticket_type.id)
      broadcast_updated(deleted_ticket_type)
    end
  end

  defp broadcast_updated(%TicketType{} = ticket_type) do
    event_id_query =
      from tb in TicketBatch,
        where: tb.id == ^ticket_type.ticket_batch_id,
        select: tb.event_id

    event_id = Repo.one(event_id_query)

    Tiki.Orders.broadcast(
      event_id,
      {:tickets_updated, get_available_ticket_types(event_id)}
    )

    {:ok, ticket_type}
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ticket_types changes.

  ## Examples

      iex> change_ticket_type(ticket_types)
      %Ecto.Changeset{data: %TicketType{}}

  """
  def change_ticket_type(%TicketType{} = ticket_types, attrs \\ %{}) do
    TicketType.changeset(ticket_types, attrs)
  end

  @doc """
  Returns the available ticket types for an event. Returns a list of ticket types,
  with the number of available tickets, purchased tickets and pending tickets.

  ## Examples
      iex> get_available_ticket_types(123)
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
  def get_available_ticket_types(event_id) do
    result =
      Multi.new()
      |> get_available_ticket_types_multi(event_id)
      |> Repo.transaction()

    case result do
      {:ok, %{ticket_types_available: ticket_types}} ->
        put_available_ticket_meta(ticket_types)

      other ->
        other
    end
  end

  def get_cached_available_ticket_types(event_id) do
    Tiki.OrderHandler.Worker.get_ticket_types(event_id)
  end

  @doc """
  Puts the available, purchased and pending meta data for each ticket type on the ticket types.

  ## Examples

      iex> put_available_ticket_meta([%{ticket_type: %TicketType{}, purchased: 2, pending: 1, available: 10}, ...])
      [
        %TicketType{
          available: 10,
          purchased: 2,
          pending: 1,
          ...
        },
        ...
      ]
  """
  def put_available_ticket_meta(ticket_types) do
    Enum.map(ticket_types, fn tt ->
      tt.ticket_type
      |> Map.put(:available, tt.available)
      |> Map.put(:purchased, tt.purchased)
      |> Map.put(:pending, tt.pending)
      |> Map.put(:release, tt.release)
    end)
  end

  @doc """
  An Ecto Multi that returns the available ticket types for an event.
  The final result can be found from the `ticket_types_available` key.
  It will look like this:

  ```
  # :ticket_types_available
  %{ticket_type: %TicketType{}, purchased: 2, pending: 1, available: 10}, ...]
  """

  def get_available_ticket_types_multi(multi, event_id) do
    # Subquery for counting tickets based on status
    sub =
      from tt in TicketType,
        join: tb in assoc(tt, :ticket_batch),
        left_join: t in assoc(tt, :tickets),
        join: o in assoc(t, :order),
        where: tb.event_id == ^event_id,
        group_by: tt.id,
        select: %{ticket_type_id: tt.id, count: count(t.id)}

    sub_pending = sub |> where([tt, tb, t, o], o.status in ^["pending", "checkout"])
    sub_purchased = sub |> where([tt, tb, t, o], o.status == ^"paid")

    # Query for ticket types and their counts
    query =
      from tt in TicketType,
        join: tb in assoc(tt, :ticket_batch),
        left_join: r in assoc(tb, :release),
        left_join: pt in subquery(sub_pending),
        on: tt.id == pt.ticket_type_id,
        left_join: pt2 in subquery(sub_purchased),
        on: tt.id == pt2.ticket_type_id,
        where: tb.event_id == ^event_id,
        select: %{ticket_type: tt, purchased: pt2.count, pending: pt.count, release: r}

    multi
    |> get_batch_tree_multi(event_id)
    |> Multi.run(:available, fn _repo, %{graph: {batch_tree, root}} ->
      # Propagate the number of purchased tickets up the tree
      TreeBuilder.build(batch_tree, root)

      # Get the number of available tickets for each batch
      available = TreeBuilder.available(batch_tree, root)

      # Not garbage collected, so we need to delete it!
      :digraph.delete(batch_tree)

      {:ok, available}
    end)
    |> Multi.all(:ticket_types, query)
    |> Multi.run(:ticket_types_available, fn _repo,
                                             %{available: available, ticket_types: ticket_types} ->
      ticket_types =
        Enum.map(ticket_types, fn tt ->
          Map.put(tt, :purchased, tt.purchased || 0)
          |> Map.put(:pending, tt.pending || 0)
          |> Map.put(:available, available[tt.ticket_type.ticket_batch_id])
          |> Map.put(:release, tt.release || nil)
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

    batches_query = union_all(root_batches_query, ^batches_recursion_query)

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

  # Helper function to check if timing fields changed for ticket types
  defp timing_changed?(old_ticket_type, new_ticket_type) do
    DateTime.compare(
      old_ticket_type.release_time || ~U[1970-01-01 00:00:00Z],
      new_ticket_type.release_time || ~U[1970-01-01 00:00:00Z]
    ) != :eq
  end
end
