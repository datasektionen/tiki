defmodule Tiki.Workers.EventSchedulerWorker do
  @moduledoc """
  Oban worker for handling release status, and ticket release times.

  This worker broadcasts when a release opens or closes, and schedules
  the next status change job for the same release.

  It also broadcasts when a "normal" ticket release time happens.
  """
  use Oban.Worker, queue: :event_schedule, max_attempts: 3
  import Ecto.Query, warn: false

  alias Tiki.Releases
  alias Tiki.Releases.DrawEngine
  alias Tiki.Tickets
  alias Tiki.Repo

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"release_id" => release_id, "action" => action}}) do
    case Repo.get(Releases.Release, release_id) do
      nil ->
        Logger.warning("Release not found: #{release_id}")
        :ok

      release ->
        handle_transition(release, action)
        Releases.handle_release_change(release)
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"ticket_type_id" => ticket_type_id}}) do
    case Repo.get(Tickets.TicketType, ticket_type_id) do
      nil ->
        Logger.warning("Ticket type not found: #{ticket_type_id}")
        :ok

      ticket_type ->
        ticket_type = Repo.preload(ticket_type, :ticket_batch)
        event_id = ticket_type.ticket_batch.event_id

        Logger.info("Broadcasting ticket released: #{ticket_type_id} for event: #{event_id}")

        Tiki.Orders.broadcast(
          event_id,
          {:tickets_updated, Tiki.Tickets.get_available_ticket_types(event_id)}
        )
    end
  end

  @doc """
  Schedules status change jobs for a release (both open and close events).
  Call this when a release is created or updated.
  """
  def schedule_release_jobs(%Releases.Release{} = release) do
    lottery_end = DateTime.add(release.opens_at, release.signup_window_minutes, :minute)
    purchase_end = DateTime.add(lottery_end, release.purchase_window_minutes, :minute)

    schedule_transition(release, "open", release.opens_at)
    schedule_transition(release, "draw", lottery_end)
    schedule_transition(release, "release", purchase_end)

    :ok
  end

  # A release moves through three scheduled transitions: it opens for signups, the draw
  # runs at the end of the signup window, and unclaimed tickets fall back to FCFS at the
  # end of the purchase window.
  defp handle_transition(release, "open") do
    Logger.info("Release opened: #{release.id}")
  end

  defp handle_transition(release, "draw") do
    Logger.info("Running draw for release: #{release.id}")
    DrawEngine.perform_draw(release.id)
  end

  defp handle_transition(release, "release") do
    Logger.info("Releasing unclaimed tickets for release: #{release.id}")
    Releases.release_unclaimed(release)
  end

  defp schedule_transition(release, action, at) do
    if DateTime.compare(at, DateTime.utc_now()) == :gt do
      %{release_id: release.id, action: action}
      |> new(scheduled_at: at)
      |> Oban.insert()
    end
  end

  @doc """
  Reschedules jobs for a release. Cancels existing jobs and creates new ones.
  Use this when release timing is updated.
  """
  def reschedule_release_jobs(%Releases.Release{} = release) do
    cancel_release_jobs(release.id)
    schedule_release_jobs(release)
  end

  defp cancel_release_jobs(release_id) do
    from(j in Oban.Job,
      where: j.worker == "Tiki.Workers.EventSchedulerWorker",
      where: j.state in ["available", "scheduled"],
      where: fragment("?->>'release_id' = ?", j.args, ^to_string(release_id))
    )
    |> Oban.cancel_all_jobs()
  end

  @doc """
  Schedules a ticket job.
  """
  def schedule_ticket_job(%Tickets.TicketType{} = ticket_type) do
    now = DateTime.utc_now()

    # Add some delay to make sure that release job is run first if they are scheduled at the same time
    if ticket_type.release_time != nil && DateTime.compare(ticket_type.release_time, now) == :gt do
      %{ticket_type_id: ticket_type.id}
      |> new(scheduled_at: ticket_type.release_time)
      |> Oban.insert()
    end

    :ok
  end

  @doc """
  Reschedules a ticket job. Cancels existing job and creates new one.
  Use this when ticket timing is updated.
  """
  def reschedule_ticket_job(%Tickets.TicketType{} = ticket_type) do
    cancel_ticket_job(ticket_type.id)
    schedule_ticket_job(ticket_type)
  end

  @doc """
  Cancels ticket jobs for a ticket type.
  """
  def cancel_ticket_job(ticket_type_id) do
    from(j in Oban.Job,
      where: j.worker == "Tiki.Workers.EventSchedulerWorker",
      where: j.state in ["available", "scheduled"],
      where: fragment("?->>'ticket_type_id' = ?", j.args, ^to_string(ticket_type_id))
    )
    |> Oban.cancel_all_jobs()
  end
end
