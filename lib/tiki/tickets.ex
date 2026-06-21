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
  alias Tiki.Accounts.Scope
  alias Tiki.Events.Event
  alias Tiki.Releases
  alias Tiki.Orders

  alias Tiki.Policy

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
  def create_ticket_batch(%Scope{event: %Event{} = event}, attrs \\ %{}) do
    %TicketBatch{event_id: event.id}
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
  def update_ticket_batch(%Scope{event: event}, %TicketBatch{} = ticket_batch, attrs)
      when event.id == ticket_batch.event_id do
    Repo.transact(fn ->
      changeset = TicketBatch.changeset(ticket_batch, attrs)

      with {:ok, batch} <- Repo.update(changeset),
           {:ok, _} <- check_no_cycle(batch, changeset) do
        Tiki.Orders.broadcast(
          ticket_batch.event_id,
          {:tickets_updated, get_available_ticket_types(ticket_batch.event_id)}
        )

        {:ok, batch}
      end
    end)
  end

  defp check_no_cycle(%TicketBatch{parent_batch_id: nil}, _), do: {:ok, :ok}

  defp check_no_cycle(%TicketBatch{id: batch_id, parent_batch_id: parent_batch_id}, changeset) do
    base =
      from tb in TicketBatch,
        where: tb.id == ^parent_batch_id,
        select: %{id: tb.id, parent_batch_id: tb.parent_batch_id}

    recursive =
      from tb in TicketBatch,
        join: anc in "ancestors",
        on: tb.id == anc.parent_batch_id,
        select: %{id: tb.id, parent_batch_id: tb.parent_batch_id}

    query =
      from(anc in "ancestors", where: anc.id == ^batch_id, select: anc.id)
      |> recursive_ctes(true)
      |> with_cte("ancestors", as: ^union_all(base, ^recursive))

    if Repo.exists?(query) do
      {:error,
       Ecto.Changeset.add_error(changeset, :parent_batch_id, "would create a cycle")
       |> Map.put(:action, :update)}
    else
      {:ok, :ok}
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

      iex> create_ticket_type(scope, event_id, %{field: value})
      {:ok, %TicketType{}}

      iex> create_ticket_type(scope, event_id, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

      iex> create_ticket_type(bad_scope, event_id, %{field: bad_value})
      {:error, :unauthorized}

  """
  def create_ticket_type(%Scope{event: %Event{} = event} = scope, attrs \\ %{}) do
    with :ok <- Policy.authorize(:event_manage, scope.user, event),
         {:ok, ticket_type} <-
           %TicketType{}
           |> TicketType.changeset(attrs)
           |> validate_ticket_type_belongs_to_event(event.id)
           |> Repo.insert(returning: [:id]) do
      EventSchedulerWorker.schedule_ticket_job(ticket_type)

      broadcast_updated(ticket_type)
    end
  end

  @doc """
  Updates a ticket_types.

  ## Examples

      iex> update_ticket_type(event_id, ticket_types, %{field: new_value})
      {:ok, %TicketType{}}

      iex> update_ticket_type(event_id, ticket_types, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ticket_type(%Scope{event: %Event{} = event}, %TicketType{} = ticket_type, attrs) do
    with {:ok, updated_ticket_type} <-
           ticket_type
           |> TicketType.changeset(attrs)
           |> validate_ticket_type_belongs_to_event(event.id)
           |> Repo.update() do
      if timing_changed?(ticket_type, updated_ticket_type) do
        EventSchedulerWorker.schedule_ticket_job(updated_ticket_type)
      end

      broadcast_updated(updated_ticket_type)
    end
  end

  defp validate_ticket_type_belongs_to_event(changeset, event_id) do
    Ecto.Changeset.validate_change(changeset, :ticket_batch_id, fn :ticket_batch_id,
                                                                   ticket_batch_id ->
      # Query to check if the ticket_batch belongs to the given event
      query =
        from tb in Tiki.Tickets.TicketBatch,
          where: tb.id == ^ticket_batch_id and tb.event_id == ^event_id,
          select: count(tb.id)

      case Tiki.Repo.one(query) do
        1 -> []
        _ -> [ticket_batch_id: "does not belong to this event"]
      end
    end)
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

  def request_tickets(%Scope{} = scope, event_id, ticket_types) do
    with {:ok, tickets_scope} <- acquisition_scope(ticket_types) do
      case tickets_scope do
        nil ->
          wrap(
            :order,
            Orders.reserve_tickets(event_id, ticket_types, scope.user && scope.user.id)
          )

        release ->
          wrap(:signup, Releases.sign_up(scope, release.id, ticket_types))
      end
    end
  end

  defp acquisition_scope(ticket_types) do
    ids =
      ticket_types
      |> Enum.filter(fn {_id, qty} -> qty > 0 end)
      |> Enum.map(&elem(&1, 0))

    tt_rows =
      Repo.all(
        from tt in TicketType,
          where: tt.id in ^ids,
          join: tb in assoc(tt, :ticket_batch),
          select: {tt.id, tb.id, tb.event_id}
      )

    cond do
      ids == [] ->
        {:error, :empty_request}

      length(tt_rows) != length(ids) ->
        {:error, :unknown_ticket_type}

      true ->
        event_ids = tt_rows |> Enum.map(&elem(&1, 2)) |> Enum.uniq()

        case event_ids do
          [event_id] ->
            batch_parents =
              Repo.all(
                from tb in TicketBatch,
                  where: tb.event_id == ^event_id,
                  select: {tb.id, tb.parent_batch_id}
              )
              |> Map.new()

            releases_by_batch =
              Repo.all(from r in Releases.Release, where: r.event_id == ^event_id)
              |> Enum.filter(&Releases.is_active?/1)
              |> Enum.group_by(& &1.ticket_batch_id)

            active_releases =
              tt_rows
              |> Enum.map(fn {_tt_id, batch_id, _} ->
                find_governing_release(batch_id, batch_parents, releases_by_batch)
              end)
              |> Enum.uniq()

            case active_releases do
              [scope] -> {:ok, scope}
              _ -> {:error, :mixed_request}
            end

          _ ->
            {:error, :mixed_request}
        end
    end
  end

  defp find_governing_release(batch_id, batch_parents, releases_by_batch) do
    now = DateTime.utc_now()

    batch_id
    |> ancestry(batch_parents)
    |> Enum.flat_map(&Map.get(releases_by_batch, &1, []))
    |> Enum.filter(fn release ->
      DateTime.compare(Releases.window_end(release), now) == :gt
    end)
    |> Enum.min_by(&Releases.window_end/1, DateTime, fn -> nil end)
  end

  defp ancestry(nil, _parents), do: []

  defp ancestry(batch_id, parents),
    do: [batch_id | ancestry(Map.get(parents, batch_id), parents)]

  defp wrap(tag, {:ok, val}), do: {:ok, {tag, val}}
  defp wrap(_tag, error), do: error

  defp put_available_ticket_meta(ticket_types) do
    Enum.map(ticket_types, fn tt ->
      tt.ticket_type
      |> Map.put(:available, tt.available)
      |> Map.put(:purchased, tt.purchased)
      |> Map.put(:pending, tt.pending)
      |> Map.put(:active_release, tt.active_release)
    end)
  end

  defp get_available_ticket_types_multi(multi, event_id) do
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
        left_join: pt in subquery(sub_pending),
        on: tt.id == pt.ticket_type_id,
        left_join: pt2 in subquery(sub_purchased),
        on: tt.id == pt2.ticket_type_id,
        where: tb.event_id == ^event_id,
        select: %{ticket_type: tt, purchased: pt2.count, pending: pt.count}

    releases_query = from r in Releases.Release, where: r.event_id == ^event_id

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
    |> Multi.all(:releases, releases_query)
    |> Multi.all(:ticket_types, query)
    |> Multi.run(:ticket_types_available, fn _repo,
                                             %{
                                               available: available,
                                               ticket_types: ticket_types,
                                               batches: batches,
                                               releases: releases
                                             } ->
      batch_parents = Map.new(batches, fn %{batch: tb} -> {tb.id, tb.parent_batch_id} end)

      releases_by_batch =
        releases
        |> Enum.filter(&Releases.is_active?/1)
        |> Enum.group_by(& &1.ticket_batch_id)

      ticket_types =
        Enum.map(ticket_types, fn tt ->
          release =
            find_governing_release(
              tt.ticket_type.ticket_batch_id,
              batch_parents,
              releases_by_batch
            )

          Map.put(tt, :purchased, tt.purchased || 0)
          |> Map.put(:pending, tt.pending || 0)
          |> Map.put(:available, available[tt.ticket_type.ticket_batch_id])
          |> Map.put(:active_release, release)
        end)

      {:ok, ticket_types}
    end)
  end

  @doc """
  Returns an Ecto query that fetches every batch for `event_id` together with the
  number of tickets that have been issued from ticket types directly in that batch
  (not including sub-batches — `TreeBuilder.build/2` propagates counts upward).

  Result rows are `%{batch: %TicketBatch{}, purchased: non_neg_integer}`.
  """
  def batch_purchases_query(event_id) do
    root_batches =
      from tb in TicketBatch,
        where: tb.event_id == ^event_id,
        where: is_nil(tb.parent_batch_id)

    recursive_batches =
      from tb in TicketBatch,
        where: tb.event_id == ^event_id,
        inner_join: ctb in "batch_tree",
        on: tb.parent_batch_id == ctb.id

    TicketBatch
    |> where([tb], tb.event_id == ^event_id)
    |> recursive_ctes(true)
    |> with_cte("batch_tree", as: ^union_all(root_batches, ^recursive_batches))
    |> join(:left, [tb], tt in assoc(tb, :ticket_types))
    |> join(:left, [tb, tt], t in assoc(tt, :tickets))
    |> group_by([tb, _tt, _t], tb.id)
    |> select([tb, _tt, t], %{batch: tb, purchased: count(t.id)})
  end

  defp get_batch_tree_multi(multi, event_id) do
    Multi.all(multi, :batches, batch_purchases_query(event_id))
    |> Multi.run(:graph, fn _repo, %{batches: batches} ->
      {:ok, TreeBuilder.build_graph(batches)}
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
