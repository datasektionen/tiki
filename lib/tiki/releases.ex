defmodule Tiki.Releases do
  @moduledoc """
  The Releases context.
  """
  use Gettext, backend: TikiWeb.Gettext
  import Ecto.Query, warn: false

  alias Tiki.OrderHandler
  alias Phoenix.PubSub
  alias Tiki.Repo

  alias Tiki.Releases.Release
  alias Tiki.Releases.Signup
  alias Tiki.Workers.EventSchedulerWorker

  @doc """
  Returns the list of releases.

  ## Examples

      iex> list_releases()
      [%Release{}, ...]

  """
  def list_releases do
    Repo.all(Release)
  end

  @doc """
  Gets a single release.

  Raises `Ecto.NoResultsError` if the Release does not exist.

  ## Examples

      iex> get_release!(123)
      %Release{}

      iex> get_release!(456)
      ** (Ecto.NoResultsError)

  """
  def get_release!(id) do
    query =
      from r in Release,
        where: r.id == ^id,
        join: b in assoc(r, :ticket_batch),
        preload: [ticket_batch: b]

    Repo.one!(query)
  end

  @doc """
  Creates a release.

  ## Examples

      iex> create_release(%{field: value})
      {:ok, %Release{}}

      iex> create_release(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_release(attrs \\ %{}) do
    with {:ok, release} <-
           %Release{}
           |> Release.changeset(attrs)
           |> Repo.insert(returning: [:id]) do
      EventSchedulerWorker.schedule_release_jobs(release)

      broadcast_release_change(release)
      {:ok, release}
    end
  end

  @doc """
  Updates a release.

  ## Examples

      iex> update_release(release, %{field: new_value})
      {:ok, %Release{}}

      iex> update_release(release, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_release(%Release{} = release, attrs) do
    with {:ok, updated_release} <-
           release
           |> Release.changeset(attrs)
           |> Repo.update() do
      if timing_changed?(release, updated_release) do
        EventSchedulerWorker.reschedule_release_jobs(updated_release)
      end

      broadcast_release_change(updated_release)

      {:ok, updated_release}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking release changes.

  ## Examples

      iex> change_release(release)
      %Ecto.Changeset{data: %Release{}}

  """
  def change_release(%Release{} = release, attrs \\ %{}) do
    Release.changeset(release, attrs)
  end

  @doc """
  Returns a release sign up for a given user id for a particular release. Returns the
  sign up or nil if one does not exist.
  """

  def get_user_sign_up(user_id, release_id) do
    Repo.get_by(Signup, user_id: user_id, release_id: release_id)
  end

  def sign_up_user(user_id, release_id) do
    Repo.transaction(fn ->
      last_signup =
        Repo.one(
          from s in Signup,
            where: s.release_id == ^release_id,
            order_by: [desc: s.position],
            limit: 1
        )

      position = if last_signup, do: last_signup.position + 1, else: 1

      signup =
        %Signup{}
        |> Signup.changeset(%{
          user_id: user_id,
          release_id: release_id,
          status: :pending,
          position: position,
          signed_up_at: DateTime.utc_now()
        })
        |> Repo.insert!()
        |> Repo.preload(:user)

      broadcast_signup(signup, release_id)
    end)
  end

  def get_release_sign_ups(release_id) do
    query =
      from s in Signup,
        where: s.release_id == ^release_id,
        left_join: u in assoc(s, :user),
        order_by: s.position,
        preload: [user: u]

    Repo.all(query)
  end

  def shuffle_sign_ups(release_id) do
    sub_query =
      from s in Signup,
        where: s.release_id == ^release_id,
        select: %{id: s.id, position: fragment("ROW_NUMBER() OVER (ORDER BY RANDOM())")}

    query =
      from s in Signup,
        join: ss in subquery(sub_query),
        on: s.id == ss.id,
        update: [set: [position: ss.position]]

    Repo.transaction(fn ->
      accepted =
        Repo.one(
          from s in Signup, where: s.release_id == ^release_id and s.status == :accepted, limit: 1
        )

      if is_nil(accepted) do
        Repo.query!("SET CONSTRAINTS release_signups_release_id_position_unique DEFERRED")

        Repo.update_all(query, [])

        get_release_sign_ups(release_id)
        |> broadcast_signups(release_id)
      else
        Repo.rollback(gettext("Release is already allocated."))
      end
    end)
  end

  def update_sort_order(release_id, from, to) do
    Repo.transaction(fn ->
      accepted =
        Repo.one(
          from s in Signup, where: s.release_id == ^release_id and s.status == :accepted, limit: 1
        )

      if is_nil(accepted) do
        Repo.query!("SET CONSTRAINTS release_signups_release_id_position_unique DEFERRED")

        moved =
          Repo.one!(from(s in Signup, where: s.release_id == ^release_id and s.position == ^from))

        if from < to do
          from(s in Signup,
            where: s.release_id == ^release_id and s.position > ^from and s.position <= ^to,
            update: [inc: [position: -1]]
          )
          |> Repo.update_all([])
        else
          from(s in Signup,
            where: s.release_id == ^release_id and s.position >= ^to and s.position < ^from,
            update: [inc: [position: 1]]
          )
          |> Repo.update_all([])
        end

        moved
        |> Signup.changeset(%{position: to})
        |> Repo.update!()

        get_release_sign_ups(release_id)
        |> broadcast_signups(release_id)
      else
        Repo.rollback(gettext("Release is already allocated."))
      end
    end)
  end

  def allocate_sign_ups(release_id) do
    Repo.transaction(fn ->
      accepted =
        Repo.one(
          from s in Signup, where: s.release_id == ^release_id and s.status == :accepted, limit: 1
        )

      if is_nil(accepted) do
        release =
          Repo.one!(
            from r in Release,
              where: r.id == ^release_id,
              join: b in assoc(r, :ticket_batch),
              preload: [ticket_batch: b]
          )

        allocated =
          from s in Signup,
            where: s.release_id == ^release_id,
            where: s.position <= ^release.ticket_batch.max_size,
            update: [set: [status: :accepted]]

        non_allocated =
          from s in Signup,
            where: s.release_id == ^release_id,
            where: s.position > ^release.ticket_batch.max_size,
            update: [set: [status: :rejected]]

        Repo.update_all(allocated, [])
        Repo.update_all(non_allocated, [])

        get_release_sign_ups(release_id)
        |> broadcast_signups(release_id)
        |> broadcast_allocations(release_id)
      else
        Repo.rollback(gettext("Release is already allocated."))
      end
    end)
  end

  def is_active?(%Release{} = release) do
    DateTime.compare(DateTime.utc_now(), release.ends_at) == :lt &&
      DateTime.compare(DateTime.utc_now(), release.starts_at) == :gt
  end

  defp timing_changed?(%Release{} = release, %Release{} = updated_release) do
    DateTime.compare(release.starts_at, updated_release.starts_at) != :eq or
      DateTime.compare(release.ends_at, updated_release.ends_at) != :eq
  end

  defp broadcast_signups(sign_ups, release_id) do
    PubSub.broadcast(
      Tiki.PubSub,
      "release:#{release_id}:signups",
      {:signups_updated, sign_ups}
    )

    sign_ups
  end

  defp broadcast_signup(sign_up, release_id) do
    PubSub.broadcast(
      Tiki.PubSub,
      "release:#{release_id}:signups",
      {:signup_added, sign_up}
    )

    sign_up
  end

  defp broadcast_allocations(sign_ups, release_id) do
    PubSub.broadcast(
      Tiki.PubSub,
      "release:#{release_id}:allocations",
      {:signups_updated, sign_ups}
    )

    sign_ups
  end

  @doc """
  Broadcasts a release status change event (opened/closed).
  """
  def broadcast_release_change(release) do
    invalidate_order_worker_cache(release)

    PubSub.broadcast(Tiki.PubSub, "release:#{release.id}", {:release_changed, release})

    # Broadcast to all releases for event
    releases = Repo.all(from r in Release, where: r.event_id == ^release.event_id)
    PubSub.broadcast(Tiki.PubSub, "releases:#{release.event_id}", {:releases_updated, releases})

    # Broadcast ticket types for event
    Tiki.Orders.broadcast(
      release.event_id,
      {:tickets_updated, Tiki.Tickets.get_available_ticket_types(release.event_id)}
    )
  end

  defp invalidate_order_worker_cache(release) do
    # We need to invalidate order worker cache, because there might be a change
    # in if the there is an active release for the event.
    OrderHandler.Worker.invalidate_cache(release.event_id)
  end

  def subscribe(release_id, opt \\ []) do
    sign_ups = Keyword.get(opt, :sign_ups, false)

    # Subscribe to release updates
    PubSub.subscribe(Tiki.PubSub, "release:#{release_id}")
    PubSub.subscribe(Tiki.PubSub, "release:#{release_id}:allocations")

    if sign_ups do
      PubSub.subscribe(Tiki.PubSub, "release:#{release_id}:signups")
    end
  end

  def subscribe_to_event(event_id) do
    PubSub.subscribe(Tiki.PubSub, "releases:#{event_id}")
  end
end
