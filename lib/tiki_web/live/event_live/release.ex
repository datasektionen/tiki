defmodule TikiWeb.EventLive.Release do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Localizer
  alias Tiki.Presence
  alias TikiWeb.PurchaseLive.TicketsComponent
  alias Tiki.Releases
  alias Tiki.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="mb-2 text-2xl font-bold leading-9">
        {gettext("Release")}: {Localizer.localize(@release).name}
      </h1>

      <div class="text-muted-foreground flex flex-col gap-1">
        <div class="inline-flex items-center gap-2">
          <.icon name="hero-clock" />
          {gettext("Release")}: {time_to_string(@release.starts_at, format: :short)}
        </div>
        <div class="inline-flex items-center gap-2">
          <.icon name="hero-globe-europe-africa" />
          {gettext("There are currently %{count} others online", count: max(@online_count - 1, 0))}
        </div>
      </div>

      <div class="mt-4 flex flex-col gap-4">
        <div :if={!open?(@release)}>
          {gettext("This release opens at")} {time_to_string(@release.starts_at, format: :short)} {gettext(
            "Check back later to sign up for tickets in this release."
          )}
        </div>
        <div :if={open?(@release)} class="flex flex-col gap-4">
          <div class="rounded-md bg-blue-50 p-4 dark:bg-blue-500/10 dark:bg-blue-500/10 dark:outline-blue-500/20 dark:outline">
            <div class="flex">
              <.icon name="hero-exclamation-circle" class="shrink-0 text-blue-400" />
              <div class="ml-3 flex-1 md:flex md:justify-between">
                <p class="text-sm text-blue-700 dark:text-blue-300">
                  {gettext(
                    "This is a ticket release for %{event_name}.
            In case there are less tickets available than the number of people signing up, the tickets will be allocated in randomly.
            Please note that by signing up for this release, there is no guarantee that you will get a ticket. After tickets are allocated
            by the event organizers, you will have 10 minutes to complete your ticket purchase. There is no need to refresh this page.",
                    event_name: Localizer.localize(@event).name
                  )}
                </p>
              </div>
            </div>
          </div>

          <div :if={!@sign_up}>
            <div class="bg-white shadow-sm dark:bg-gray-800/50 dark:-outline-offset-1 dark:outline-white/10 dark:shadow-none dark:outline sm:rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-base font-semibold text-gray-900 dark:text-white">
                  {gettext("You have not signed up for this release yet")}
                </h3>
                <div class="mt-2 sm:flex sm:items-start sm:justify-between">
                  <div class="max-w-xl text-sm text-gray-500 dark:text-gray-400">
                    <p>
                      {gettext("Sign up for this release for a chance to get tickets.")}
                    </p>
                  </div>
                  <div class="mt-5 sm:mt-0 sm:ml-6 sm:flex sm:shrink-0 sm:items-center">
                    <.button phx-click="sign-up">
                      {gettext("Sign up")}
                    </.button>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div :if={@sign_up && @sign_up.status == :pending}>
            {gettext(
              "You are in the waiting list for this release. Please be patient and wait for the event organizers to confirm your sign up. Be ready to confirm your purchase if the event organizers confirm your sign up."
            )}
          </div>

          <div :if={@sign_up && @sign_up.status == :rejected} class="flex flex-col gap-4">
            {gettext(
              "Unfourtunately, you have not been accepted for this release. There were more people signing up for this event than the number of spots available. Feel free to check the event page later if there may still be open spots
              available, otherwise we hope to see you at a future event."
            )}
          </div>

          <div :if={@sign_up && @sign_up.status == :accepted} class="flex flex-col gap-4">
            {gettext(
              "Congratulations! You have been accepted for this release. Please confirm your purchase to get your tickets. You have a limited time to complete your purchase."
            )}

            <.live_component
              module={TicketsComponent}
              id="tickets-component"
              current_user={@current_user}
              release={@release}
              event={@event}
              order={nil}
              promo_codes={[]}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"event_id" => event_id, "release_id" => release_id}, _session, socket) do
    case socket.assigns.current_user do
      nil ->
        {:ok,
         socket
         |> put_flash(
           :error,
           gettext("You must be logged in with a KTH account to sign up for a release.")
         )
         |> push_navigate(
           to: ~p"/users/log_in?return_to=#{~p"/events/#{event_id}/releases/#{release_id}"}"
         )}

      %{kth_id: nil} ->
        {:ok,
         socket
         |> put_flash(
           :error,
           gettext("You must have a KTH account linked to sign up for a release.")
         )
         |> push_navigate(to: ~p"/account/settings/")}

      _ ->
        event =
          Events.get_event!(event_id, preload_ticket_types: true)
          |> Tiki.Localizer.localize()

        release = Releases.get_release!(release_id)

        sign_up =
          Releases.get_user_sign_up(socket.assigns.current_user.id, release_id)

        initial_count = Presence.list("presence:event:#{event_id}") |> map_size

        if connected?(socket) do
          Presence.track(self(), "presence:release:#{release_id}", socket.id, %{})
          Presence.track(self(), "presence:event:#{event_id}", socket.id, %{})
          TikiWeb.Endpoint.subscribe("presence:event:#{event_id}")

          Orders.subscribe(event.id)
          Releases.subscribe(release_id)
        end

        {:ok,
         assign(socket,
           event: event,
           sign_up: sign_up,
           online_count: initial_count
         )
         |> assign_release(release)}
    end
  end

  @impl true
  def handle_event("sign-up", _, socket) do
    case Releases.sign_up_user(socket.assigns.current_user.id, socket.assigns.release.id) do
      {:ok, sign_up} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("You have signed up for this release."))
         |> assign(sign_up: sign_up)}
    end
  end

  @impl Phoenix.LiveView
  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
        %{assigns: %{online_count: count}} = socket
      ) do
    online_count = count + map_size(joins) - map_size(leaves)
    {:noreply, assign(socket, :online_count, online_count)}
  end

  @impl true
  def handle_info({:release_changed, release}, socket) do
    {:noreply, assign_release(socket, release)}
  end

  @impl true
  def handle_info({:signups_updated, sign_ups}, socket) do
    sign_up =
      Enum.find(
        sign_ups,
        socket.assigns[:sign_up],
        fn sign_up -> sign_up.user_id == socket.assigns.current_user.id end
      )

    {:noreply, assign(socket, sign_up: sign_up)}
  end

  @impl true
  def handle_info({:tickets_updated, _} = msg, socket) do
    send_update(TicketsComponent, id: "tickets-component", action: msg)
    {:noreply, socket}
  end

  defp open?(release) do
    DateTime.compare(DateTime.utc_now(), release.starts_at) == :gt &&
      DateTime.compare(DateTime.utc_now(), release.ends_at) == :lt
  end

  defp assign_release(socket, release) do
    assign(socket,
      release: release,
      page_title: Localizer.localize(release).name,
      release_status: if(Releases.is_active?(release), do: :opened, else: :closed)
    )
  end
end
