defmodule Tiki.Releases do
  @moduledoc """
  The Releases context.
  """
  use Gettext, backend: TikiWeb.Gettext
  import Ecto.Query, warn: false

  alias Tiki.OrderHandler
  alias Tiki.Orders
  alias Tiki.Orders.Order
  alias Phoenix.PubSub
  alias Tiki.Repo

  alias Tiki.Accounts
  alias Tiki.Events.Event
  alias Tiki.Releases.Release
  alias Tiki.Releases.Signup
  alias Tiki.Releases.SignupItem
  alias Tiki.Tickets.TicketBatch
  alias Tiki.Tickets.TicketType
  alias Tiki.Workers.EventSchedulerWorker

  @doc """
  Returns a list of releases.
  """
  def list_releases do
    Repo.all(Release)
  end

  @doc """
  Returns a list of releases for an event.
  """
  def list_releases_for_event(event_id) do
    Repo.all(from r in Release, where: r.event_id == ^event_id)
  end

  @doc """
  Gets a single release.
  """
  def get_release!(id) do
    query =
      from r in Release,
        where: r.id == ^id,
        preload: [:ticket_batch]

    Repo.one!(query)
  end

  @doc """
  Creates a release.
  """
  def create_release(%Tiki.Accounts.Scope{event: event}, attrs \\ %{}) do
    changeset = %Release{event_id: event.id} |> Release.changeset(attrs)

    result =
      Repo.transact(fn ->
        with {:ok, release} <- Repo.insert(changeset, returning: [:id]),
             :ok <- check_no_subtree_overlap(release) do
          {:ok, release}
        end
      end)

    case result do
      {:ok, release} ->
        EventSchedulerWorker.schedule_release_jobs(release)
        handle_release_change(release)
        {:ok, release}

      {:error, :overlap} ->
        {:error, put_overlap_error(changeset)}

      error ->
        error
    end
  end

  @doc """
  Updates a release.
  """
  def update_release(%Release{} = release, attrs) do
    changeset = release |> Release.changeset(attrs)

    result =
      Repo.transact(fn ->
        with {:ok, updated_release} <- Repo.update(changeset),
             :ok <- check_no_subtree_overlap(updated_release) do
          {:ok, updated_release}
        end
      end)

    case result do
      {:ok, updated_release} ->
        if timing_changed?(release, updated_release) do
          EventSchedulerWorker.reschedule_release_jobs(updated_release)
        end

        handle_release_change(updated_release)
        {:ok, updated_release}

      {:error, :overlap} ->
        {:error, put_overlap_error(changeset)}

      error ->
        error
    end
  end

  defp put_overlap_error(changeset),
    do:
      Ecto.Changeset.add_error(changeset, :ticket_batch_id, "overlaps with an existing release")
      |> Map.put(:action, :update)

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking release changes.
  """
  def change_release(%Release{} = release, attrs \\ %{}) do
    Release.changeset(release, attrs)
  end

  @doc """
  Returns a release sign up for a given user id for a particular release. Returns the
  sign up or nil if one does not exist.
  """
  def get_user_sign_up(user_id, release_id) do
    query =
      from s in Signup,
        where: s.user_id == ^user_id,
        where: s.release_id == ^release_id,
        join: r in assoc(s, :release),
        left_join: i in assoc(s, :items),
        left_join: tt in assoc(i, :ticket_type),
        preload: [items: {i, ticket_type: tt}, release: r]

    Repo.one(query)
  end

  @doc """
  Returns user sign ups for the given event with the given user scope.
  """
  def get_user_sign_ups(%Accounts.Scope{user: user}, event_id) do
    signup_query()
    |> where([s, r], s.user_id == ^user.id and r.event_id == ^event_id)
    |> Repo.all()
  end

  def get_user_sign_ups(_scope, _event_id), do: []

  defp signup_query(),
    do:
      from(s in Signup,
        join: r in assoc(s, :release),
        left_join: i in assoc(s, :items),
        left_join: tt in assoc(i, :ticket_type),
        preload: [items: {i, ticket_type: tt}, release: r]
      )

  @doc """
  Signs up a user for a release with a specific bundle (a map of ticket_type_id => quantity).

  Validates auth, release phase, per-ticket purchase limits, and the effective order size
  limit (release override if set, else event default) — all inside a single transaction.
  """
  def sign_up(release_id, items, user_id) do
    if is_nil(user_id) do
      {:error, :unauthenticated}
    else
      Repo.transact(fn ->
        with {:ok, release} <- fetch_open_release(release_id),
             {:ok, ticket_types} <- fetch_ticket_types_for_signup(Map.keys(items)),
             {:ok, event} <- fetch_event_for_signup(release.event_id),
             :ok <- validate_signup_limits(items, ticket_types, release, event),
             {:ok, signup} <- create_signup(release_id, user_id),
             {:ok, _} <- create_signup_items(signup.id, items) do
          signup = Repo.preload(signup, [:user, :release, items: [:ticket_type]])
          broadcast_signup_updated(signup, event.id)
          {:ok, signup}
        end
      end)
    end
  end

  @doc """
  Cancels a queued signup owned by `user_id`. Only allowed while the release is open.
  """
  def cancel_signup(%Accounts.Scope{user: user}, signup_id) do
    Repo.transact(fn ->
      query =
        from s in Signup,
          join: r in assoc(s, :release),
          where: s.user_id == ^user.id,
          where: s.id == ^signup_id,
          preload: [release: r]

      with %Signup{release: release} = signup <- Repo.one(query),
           :open <- get_phase(release),
           {:ok, signup} <- Repo.delete(signup) do
        broadcast_signup_deleted(signup, release.event_id)

        {:ok, signup}
      else
        nil -> {:error, :not_found}
        other_phase when is_atom(other_phase) -> {:error, :not_open}
        {:error, changeset} -> {:error, changeset}
      end
    end)
  end

  defp fetch_open_release(release_id) do
    case Repo.get(Release, release_id) do
      nil ->
        {:error, :not_found}

      release ->
        if get_phase(release) == :open, do: {:ok, release}, else: {:error, :not_open}
    end
  end

  defp fetch_ticket_types_for_signup(ids) do
    {:ok, Repo.all(from tt in TicketType, where: tt.id in ^ids) |> Map.new(&{&1.id, &1})}
  end

  defp fetch_event_for_signup(event_id) do
    case Repo.get(Event, event_id) do
      nil -> {:error, :not_found}
      event -> {:ok, event}
    end
  end

  defp validate_signup_limits(items, ticket_types, release, event) do
    total = Map.values(items) |> Enum.sum()
    max_order = min(release.max_tickets_per_order, event.max_order_size)

    per_ticket_ok =
      Enum.all?(items, fn {tt_id, qty} ->
        case ticket_types[tt_id] do
          nil -> false
          tt -> qty <= tt.purchase_limit
        end
      end)

    cond do
      not per_ticket_ok -> {:error, :exceeds_ticket_limit}
      total > max_order -> {:error, :exceeds_order_limit}
      true -> :ok
    end
  end

  defp create_signup(release_id, user_id) do
    %Signup{}
    |> Signup.changeset(%{user_id: user_id, release_id: release_id})
    |> Repo.insert(returning: [:id])
  end

  defp create_signup_items(signup_id, items) do
    Enum.map(items, fn {ticket_type_id, quantity} ->
      %SignupItem{signup_id: signup_id}
      |> SignupItem.changeset(%{
        ticket_type_id: ticket_type_id,
        quantity: quantity
      })
      |> Repo.insert()
    end)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, item}, {_, acc} -> {:cont, {:ok, [item | acc]}}
      {:error, err}, _acc -> {:halt, {:error, err}}
    end)
  end

  def get_release_sign_ups(release_id) do
    query =
      from s in Signup,
        where: s.release_id == ^release_id,
        join: u in assoc(s, :user),
        left_join: i in assoc(s, :items),
        left_join: tt in assoc(i, :ticket_type),
        left_join: o in assoc(s, :order),
        preload: [user: u, items: {i, [ticket_type: tt]}, order: o]

    Repo.all(query)
  end

  @doc """
  Marks a signup as see ded (guaranteed winner). Only allowed before the draw.
  Takes a spot off capacity — the draw fills `capacity - seeds` from the rest.
  """
  def seed_signup(signup_id, decided_by_id) do
    Repo.transact(fn ->
      signup = Repo.get!(Signup, signup_id)

      new_status =
        case signup.status do
          :seeded -> :queued
          s when s in [:queued, :rejected] -> :seeded
          _ -> nil
        end

      if new_status do
        now = DateTime.utc_now()

        with {:ok, updated} <-
               signup
               |> Signup.changeset(%{
                 status: new_status,
                 decided_at: now,
                 decided_by_id: decided_by_id
               })
               |> Repo.update() do
          updated = Repo.preload(updated, [:user, :release, items: [:ticket_type], order: []])
          broadcast_signup_updated(updated, updated.release.event_id)
          {:ok, updated}
        end
      else
        Repo.rollback(:invalid_status)
      end
    end)
  end

  @doc """
  Marks a signup as rejected (excluded from the draw). Only allowed before the draw.
  The rejected person sees a normal loss — indistinguishable from not being selected.
  Re-entry into this release is blocked by the unique constraint.
  """
  def reject_signup(signup_id, decided_by_id) do
    Repo.transact(fn ->
      signup = Repo.get!(Signup, signup_id)

      new_status =
        case signup.status do
          :rejected -> :queued
          s when s in [:queued, :seeded] -> :rejected
          _ -> nil
        end

      if new_status do
        now = DateTime.utc_now()

        with {:ok, updated} <-
               signup
               |> Signup.changeset(%{
                 status: new_status,
                 decided_at: now,
                 decided_by_id: decided_by_id
               })
               |> Repo.update() do
          updated = Repo.preload(updated, [:user, :release, items: [:ticket_type], order: []])
          broadcast_signup_updated(updated, signup.release_id)
          {:ok, updated}
        end
      else
        Repo.rollback(:invalid_status)
      end
    end)
  end

  @doc """
  The lifecycle phase a release is in right now.

    * `:scheduled` - announced, not yet open; its types are already locked out of FCFS
    * `:open`      - the signup window is open
    * `:drawing`   - signups have closed but the draw hasn't committed yet
    * `:purchase`  - the draw is done and winners are paying off their holds
    * `:released`  - the window has passed; unclaimed types are back to plain FCFS

  Note `:drawing` vs `:purchase` is decided by whether the draw has run (`drawn_at`),
  not by the clock, so the phase reflects reality even if the draw job is delayed.
  """
  def get_phase(%Release{} = release) do
    now = DateTime.utc_now()
    lottery_end = DateTime.add(release.opens_at, release.signup_window_minutes, :minute)
    purchase_end = DateTime.add(lottery_end, release.purchase_window_minutes, :minute)

    cond do
      DateTime.compare(now, purchase_end) != :lt -> :released
      release.drawn_at -> :purchase
      DateTime.compare(now, release.opens_at) == :lt -> :scheduled
      DateTime.compare(now, lottery_end) == :lt -> :open
      true -> :drawing
    end
  end

  @doc """
  Whether a release currently locks its ticket types out of FCFS.
  True during `:scheduled`, `:open`, and `:drawing`. False once the draw is done
  (`:purchase` and `:released`): winners already hold their spots, so remaining
  inventory is free for normal purchasing.
  """
  def is_active?(%Release{} = release) do
    get_phase(release) in [:scheduled, :open, :drawing]
  end

  def window_end(%Release{} = release) do
    DateTime.add(
      release.opens_at,
      release.signup_window_minutes + release.purchase_window_minutes,
      :minute
    )
  end

  @doc """
  Cancels still-unpaid winner orders so their seats fall back to plain FCFS.

  Run at the end of the purchase window: winners who never paid forfeit their hold, and
  whatever was never drawn was never held in the first place — both become purchasable.
  """
  def release_unclaimed(%Release{} = release) do
    unpaid_winner_orders =
      Repo.all(
        from o in Order,
          join: s in Signup,
          on: s.order_id == o.id,
          where: s.release_id == ^release.id and o.status == :pending,
          select: o.id
      )

    Enum.each(unpaid_winner_orders, &Orders.maybe_cancel_order/1)
  end

  # Ensures no existing release in the batch subtree (ancestors + self + descendants)
  # overlaps with `release`. Called inside a transaction after the row has been
  # inserted/updated, so the check runs against real DB data and the release
  # itself is excluded via `r.id != ^release.id`.
  defp check_no_subtree_overlap(%Release{ticket_batch_id: nil}), do: :ok

  defp check_no_subtree_overlap(%Release{} = release) do
    purchase_end =
      DateTime.add(
        release.opens_at,
        (release.signup_window_minutes + release.purchase_window_minutes) * 60,
        :second
      )

    # Walk ancestors (upward) and descendants (downward) in one recursive CTE.
    # Starting from the release's own batch, we traverse parent_batch_id upward
    # and sub_batches downward to collect every batch in the same subtree.
    anchor_id = release.ticket_batch_id

    anchor_up =
      from tb in TicketBatch,
        where: tb.id == ^anchor_id,
        select: %{id: tb.id, parent_batch_id: tb.parent_batch_id, dir: "up"}

    anchor_down =
      from tb in TicketBatch,
        where: tb.id == ^anchor_id,
        select: %{id: tb.id, parent_batch_id: tb.parent_batch_id, dir: "down"}

    recursion =
      from tb in TicketBatch,
        join: tree in "batch_tree",
        on:
          (tree.dir == "up" and tb.id == tree.parent_batch_id) or
            (tree.dir == "down" and tb.parent_batch_id == tree.id),
        select: %{id: tb.id, parent_batch_id: tb.parent_batch_id, dir: tree.dir}

    batch_tree =
      anchor_up
      |> union_all(^anchor_down)
      |> union_all(^recursion)

    subtree_ids_query =
      "batch_tree"
      |> recursive_ctes(true)
      |> with_cte("batch_tree", as: ^batch_tree)
      |> select([t], t.id)
      |> distinct(true)

    conflict_query =
      from r in Release,
        where: r.id != ^release.id,
        where: r.ticket_batch_id in subquery(subtree_ids_query),
        select: r,
        where: r.opens_at < ^purchase_end,
        where:
          fragment(
            "? + (? + ?) * interval '1 minute' > ?",
            r.opens_at,
            r.signup_window_minutes,
            r.purchase_window_minutes,
            ^release.opens_at
          )

    if Repo.exists?(conflict_query), do: {:error, :overlap}, else: :ok
  end

  defp timing_changed?(%Release{} = release, %Release{} = updated_release) do
    DateTime.compare(release.opens_at, updated_release.opens_at) != :eq or
      release.signup_window_minutes != updated_release.signup_window_minutes or
      release.purchase_window_minutes != updated_release.purchase_window_minutes
  end

  @doc """
  Commits the result of a draw and broadcasts all side-effects: updated signup statuses,
  updated release (now carrying `drawn_at`), and ticket availability.
  """
  def commit_draw(release_id, winner_ids, loser_ids, seed) do
    with {:ok, _} <-
           Tiki.Releases.DrawEngine.commit_draw_result(release_id, winner_ids, loser_ids, seed) do
      release = get_release!(release_id)

      all_ids = winner_ids ++ loser_ids

      signups =
        Repo.all(
          from s in Signup,
            join: u in assoc(s, :user),
            join: i in assoc(s, :items),
            join: tt in assoc(i, :ticket_type),
            where: s.id in ^all_ids,
            preload: [user: u, items: {i, ticket_type: tt}]
        )

      for signup <- signups, do: broadcast_signup_updated(signup, release.event_id)

      handle_release_change(release)

      {:ok, signups}
    end
  end

  @doc """
  Handle a release status change. Is safe to call multiple times. Reconciles the system state
  based on the state of the release.
  """
  def handle_release_change(release) do
    OrderHandler.Worker.invalidate_cache(release.event_id)

    broadcast_release_updated(release)

    Tiki.Orders.broadcast(
      release.event_id,
      {:tickets_updated, Tiki.Tickets.get_available_ticket_types(release.event_id)}
    )
  end

  defmodule Topics do
    def release(release_id), do: "release:#{release_id}"
    def signups(release_id), do: "release:#{release_id}:signups"
    def event_releases(event_id), do: "releases:event:#{event_id}"
    def user_signups(event_id, user_id), do: "releases:event:#{event_id}:user:#{user_id}:signups"
  end

  defp broadcast_signup_updated(%Signup{} = signup, event_id) do
    for topic <- [
          Topics.signups(signup.release_id),
          Topics.user_signups(event_id, signup.user_id)
        ] do
      PubSub.broadcast(Tiki.PubSub, topic, {:signup_updated, signup})
    end

    signup
  end

  defp broadcast_signup_deleted(%Signup{} = signup, event_id) do
    for topic <- [
          Topics.signups(signup.release_id),
          Topics.user_signups(event_id, signup.user_id)
        ] do
      PubSub.broadcast(Tiki.PubSub, topic, {:signup_deleted, signup})
    end

    signup
  end

  defp broadcast_release_updated(release) do
    for topic <- [
          Topics.release(release.id),
          Topics.event_releases(release.event_id)
        ] do
      PubSub.broadcast(Tiki.PubSub, topic, {:release_updated, release})
    end

    release
  end

  def subscribe(release_id, opt \\ []) do
    PubSub.subscribe(Tiki.PubSub, Topics.release(release_id))

    if Keyword.get(opt, :sign_ups, false) do
      PubSub.subscribe(Tiki.PubSub, Topics.signups(release_id))
    end
  end

  def subscribe_event(event_id, user_id) do
    PubSub.subscribe(Tiki.PubSub, Topics.event_releases(event_id))

    if user_id do
      PubSub.subscribe(Tiki.PubSub, Topics.user_signups(event_id, user_id))
    end
  end
end
