defmodule Tiki.Releases.DrawEngine do
  @moduledoc """
  Selects the winners of a lottery release and commits the result.

  Selection is a pure function of the surviving entries, the remaining inventory, and a
  seed, so a draw can be replayed from its stored seed to prove the random portion was
  clean. Seeded entries win first (taking spots off capacity); the rest are shuffled with
  the seed and filled greedily until the inventory runs out. Creating the winners' held
  orders is delegated to `Tiki.OrderHandler.Worker.reserve_release_signups/2`.

  ## Inventory model

  The inventory is a three-tuple `{batch_caps, batch_parents, tt_to_batch}`:

  - `batch_caps`   — `%{batch_id => non_neg_integer | :infinity}` — each batch's own
    remaining capacity (max_size minus tickets already issued in that subtree).
  - `batch_parents` — `%{batch_id => parent_id | nil}` — the parent of each batch.
  - `tt_to_batch`  — `%{ticket_type_id => batch_id}` — resolves a signup item to its batch.

  When checking whether a signup's bundle fits, `take/2` walks the ancestor chain for
  each item and checks every level's own remaining capacity. If all levels have room,
  each level is decremented by the item's quantity — so siblings and cousins sharing a
  parent cap are correctly constrained.
  """

  import Ecto.Query

  alias Tiki.OrderHandler
  alias Tiki.Releases.{Release, Signup}
  alias Tiki.Repo
  alias Tiki.Tickets
  alias Tiki.Tickets.{TicketType, TreeBuilder}

  require Logger

  @doc """
  Runs the draw for a release at the end of its signup window.

  Rejected entries are left untouched (they were decided before the draw); only `:queued`
  and `:seeded` entries take part. Safe to call more than once — a second run is a no-op.
  """
  def perform_draw(release_id) do
    release = Repo.get!(Release, release_id)

    if release.drawn_at do
      Logger.info("Draw for release #{release_id} skipped: already drawn")
      :ok
    else
      entries =
        Repo.all(
          from s in Signup,
            where: s.release_id == ^release.id and s.status in [:queued, :seeded],
            join: i in assoc(s, :items),
            preload: [items: i]
        )

      seed = release.seed || :erlang.phash2(make_ref())
      {winners, losers} = select_winners(entries, inventory(release.event_id), seed)
      winner_ids = Enum.map(winners, & &1.id)

      case OrderHandler.Worker.reserve_release_signups(release.event_id, winner_ids) do
        {:ok, _orders, _available} ->
          commit_draw_result(release, winners, losers, seed)

          Logger.info(
            "Draw for release #{release_id}: #{length(winners)} won, #{length(losers)} lost"
          )

          {:ok, length(winners)}

        {:error, reason} ->
          Logger.error("Draw for release #{release_id} failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp commit_draw_result(release, winners, losers, seed) do
    now = DateTime.utc_now()
    winner_ids = Enum.map(winners, & &1.id)
    loser_ids = Enum.map(losers, & &1.id)

    Repo.transact(fn ->
      Repo.update_all(
        from(s in Signup, where: s.id in ^winner_ids and s.status == :seeded),
        set: [status: :seeded, decided_at: now]
      )

      Repo.update_all(
        from(s in Signup, where: s.id in ^winner_ids and s.status == :queued),
        set: [status: :drawn, decided_at: now]
      )

      Repo.update_all(
        from(s in Signup, where: s.id in ^loser_ids),
        set: [status: :lost, decided_at: now]
      )

      release
      |> Release.changeset(%{drawn_at: now, seed: seed})
      |> Repo.update!()

      {:ok, :ok}
    end)
  end

  @doc """
  The pure selection core: given the surviving entries, the remaining inventory, and a
  seed, returns `{winners, losers}` deterministically.

  Seeded entries win first; the rest are ordered by `sha256("seed:user_id")` and granted
  spots greedily until the inventory is exhausted. Pure and DB-free, so it can be replayed
  from a stored seed to prove the random portion was clean (and exercised in isolation,
  e.g. by the fairness simulation).
  """
  def select_winners(entries, inventory, seed) do
    {seeded, queued} = Enum.split_with(entries, &(&1.status == :seeded))
    fill(seeded ++ order_by_priority(queued, seed), inventory, [], [])
  end

  defp order_by_priority(entries, seed) do
    Enum.sort_by(entries, &priority_key(&1, seed))
  end

  defp priority_key(entry, seed) do
    :crypto.hash(:sha256, "#{seed}:#{entry.user_id}")
  end

  defp fill([], _inventory, winners, losers),
    do: {Enum.reverse(winners), Enum.reverse(losers)}

  defp fill([signup | rest], inventory, winners, losers) do
    case take(signup.items, inventory) do
      {:ok, inventory} -> fill(rest, inventory, [signup | winners], losers)
      :unavailable -> fill(rest, inventory, winners, [signup | losers])
    end
  end

  # Attempts to subtract a bundle from the inventory. Walks the ancestor chain for each
  # item, checking and decrementing every batch level. Returns the updated inventory or
  # :unavailable if any level in any item's chain lacks capacity.
  defp take(items, {batch_caps, batch_parents, tt_to_batch}) do
    result =
      Enum.reduce_while(items, {:ok, batch_caps}, fn item, {:ok, caps} ->
        case Map.fetch(tt_to_batch, item.ticket_type_id) do
          {:ok, batch_id} ->
            case decrement_ancestors(caps, batch_parents, batch_id, item.quantity) do
              {:ok, new_caps} -> {:cont, {:ok, new_caps}}
              :unavailable -> {:halt, :unavailable}
            end

          :error ->
            raise "lottery: ticket_type #{inspect(item.ticket_type_id)} has no batch mapping"
        end
      end)

    case result do
      {:ok, new_caps} -> {:ok, {new_caps, batch_parents, tt_to_batch}}
      :unavailable -> :unavailable
    end
  end

  # Walks the ancestor chain starting at `batch_id`, decrementing each level by `qty`.
  # nil parent = top of chain (legitimate termination).
  defp decrement_ancestors(caps, _parents, nil, _qty), do: {:ok, caps}

  defp decrement_ancestors(caps, parents, batch_id, qty) do
    case Map.fetch(caps, batch_id) do
      :error ->
        raise "lottery: batch #{inspect(batch_id)} in parent chain but missing from caps"

      {:ok, :infinity} ->
        decrement_ancestors(caps, parents, Map.get(parents, batch_id), qty)

      {:ok, have} when have >= qty ->
        decrement_ancestors(
          Map.put(caps, batch_id, have - qty),
          parents,
          Map.get(parents, batch_id),
          qty
        )

      {:ok, _} ->
        :unavailable
    end
  end

  # Builds the inventory from the batch tree. Uses the shared query and graph builder
  # from Tickets/TreeBuilder, then extracts each batch's own remaining capacity so that
  # decrement_ancestors/4 can walk and drain the full ancestor chain on each allocation.
  defp inventory(event_id) do
    batch_rows = Repo.all(Tickets.batch_purchases_query(event_id))
    {graph, root_id} = TreeBuilder.build_graph(batch_rows)
    TreeBuilder.build(graph, root_id)

    batch_caps =
      Map.new(batch_rows, fn %{batch: tb} ->
        {_, label} = :digraph.vertex(graph, tb.id)

        remaining =
          case tb.max_size do
            nil -> :infinity
            max -> max(0, max - label.purchased)
          end

        {tb.id, remaining}
      end)

    :digraph.delete(graph)

    batch_parents = Map.new(batch_rows, fn %{batch: tb} -> {tb.id, tb.parent_batch_id} end)

    tt_to_batch =
      Repo.all(
        from tt in TicketType,
          join: tb in assoc(tt, :ticket_batch),
          where: tb.event_id == ^event_id,
          select: {tt.id, tt.ticket_batch_id}
      )
      |> Map.new()

    {batch_caps, batch_parents, tt_to_batch}
  end
end
