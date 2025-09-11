defmodule TikiWeb.EventLive.Release do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Localizer
  alias Tiki.Presence
  alias TikiWeb.PurchaseLive.TicketsComponent
  alias Tiki.Releases

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div :if={!open?(@release)}>
        {gettext("This release opens at")} {time_to_string(@release.starts_at, format: :short)} {gettext(
          "Check back later to sign up for tickets in this release."
        )}
      </div>

      <div :if={open?(@release)}>
        <div :if={!@sign_up}>
          {gettext("You have not signed up for this release yet.")}

          <.button phx-click="sign-up">
            {gettext("Sign up")}
          </.button>
        </div>
      </div>

      <.live_component
        :if={@sign_up && @sign_up.status == :accepted}
        module={TicketsComponent}
        id="tickets-component"
        current_user={@current_user}
        event={@event}
        order={nil}
        promo_codes={[]}
      />
    </div>
    """
  end

  @impl true
  def mount(%{"event_id" => event_id, "release_id" => release_id}, _session, socket) do
    event =
      Events.get_event!(event_id, preload_ticket_types: true)
      |> Tiki.Localizer.localize()

    release = Releases.get_release!(release_id)

    sign_up =
      Releases.get_user_sign_up(socket.assigns.current_user.id, release_id)

    if connected?(socket) do
      Presence.track(self(), "presence:release:#{release_id}", socket.id, %{})
      Presence.track(self(), "presence:event:#{event_id}", socket.id, %{})
    end

    {:ok, assign(socket, event: event, release: release, sign_up: sign_up)}
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

  defp open?(release) do
    DateTime.compare(DateTime.utc_now(), release.starts_at) == :gt &&
      DateTime.compare(DateTime.utc_now(), release.ends_at) == :lt
  end
end
