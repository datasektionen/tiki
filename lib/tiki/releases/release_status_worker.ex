defmodule Tiki.Releases.ReleaseStatusWorker do
  @moduledoc """
  Oban worker for handling release status changes.

  This worker broadcasts when a release opens or closes, and schedules
  the next status change job for the same release.

  TODO: Do somehting similar for "normal" ticket release times.
  """
  use Oban.Worker, queue: :release_status, max_attempts: 3
  import Ecto.Query, warn: false

  alias Tiki.Releases
  alias Tiki.Repo

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"release_id" => release_id}}) do
    case Repo.get(Releases.Release, release_id) do
      nil ->
        Logger.warning("Release not found: #{release_id}")
        :ok

      release ->
        Logger.info("Broadcasting release status change: #{release_id}")
        Releases.broadcast_release_change(release)
    end
  end

  @doc """
  Schedules status change jobs for a release (both open and close events).
  Call this when a release is created or updated.
  """
  def schedule_release_jobs(%Releases.Release{} = release) do
    now = DateTime.utc_now()

    # Schedule open event
    if DateTime.compare(release.starts_at, now) == :gt do
      %{release_id: release.id}
      |> new(scheduled_at: release.starts_at)
      |> Oban.insert()
    end

    # Schedule close event
    if DateTime.compare(release.ends_at, now) == :gt do
      %{release_id: release.id}
      |> new(scheduled_at: release.ends_at)
      |> Oban.insert()
    end

    :ok
  end

  @doc """
  Cancels all scheduled jobs for a release.
  Useful when a release is deleted or its timing is changed.
  """
  def cancel_release_jobs(release_id) do
    from(j in Oban.Job,
      where: j.worker == "Tiki.Releases.ReleaseStatusWorker",
      where: j.state in ["available", "scheduled"],
      where: fragment("?->>'release_id' = ?", j.args, ^to_string(release_id))
    )
    |> Oban.cancel_all_jobs()
  end

  @doc """
  Reschedules jobs for a release. Cancels existing jobs and creates new ones.
  Use this when release timing is updated.
  """
  def reschedule_release_jobs(%Releases.Release{} = release) do
    cancel_release_jobs(release.id)
    schedule_release_jobs(release)
  end
end
