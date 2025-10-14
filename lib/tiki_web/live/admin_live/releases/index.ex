defmodule TikiWeb.AdminLive.Releases.Index do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Releases
  alias Tiki.Releases.Release

  alias Tiki.Localizer

  import TikiWeb.Component.Sheet

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.header>
      {gettext("Ticket releases")}
      <:subtitle>
        {gettext("Manage ticket releases for your event.")}
      </:subtitle>
      <:actions>
        <.link navigate={~p"/admin/events/#{@event}/releases/new"}>
          <.button>{gettext("New release")}</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="releases"
      rows={@streams.releases}
      row_click={
        fn {_id, release} -> JS.navigate(~p"/admin/events/#{@event}/releases/#{release.id}") end
      }
    >
      <:col :let={{_id, release}} label={gettext("Name")}>{Localizer.localize(release).name}</:col>
      <:col :let={{_id, release}} label={gettext("Release time")}>
        {time_to_string(release.starts_at, format: :short)}
      </:col>

      <:action :let={{_id, release}}>
        <.link navigate={~p"/admin/events/#{@event}/releases/#{release}"}>
          {gettext("Manage")}
        </.link>
      </:action>

      <:action :let={{_id, release}}>
        <.link navigate={~p"/admin/events/#{@event}/releases/#{release.id}/edit"}>
          {gettext("Edit")}
        </.link>
      </:action>
    </.table>

    <.sheet :if={@live_action in [:new, :edit]} class="">
      <.sheet_content
        show
        id="release-form-sheet"
        side="right"
        class="w-full"
        on_cancel={JS.navigate(~p"/admin/events/#{@event}/releases")}
      >
        <.live_component
          id="release-form-component"
          module={TikiWeb.AdminLive.Releases.FormComponent}
          release={@release}
          event={@event}
          action={@live_action}
        />
      </.sheet_content>
    </.sheet>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"event_id" => event_id}, _session, socket) do
    event = Events.get_event!(event_id, preload_ticket_types: true)

    with :ok <- Tiki.Policy.authorize(:event_view, socket.assigns.current_user, event) do
      releases = Releases.list_releases_for_event(event_id)

      {:ok,
       assign(socket, event: event)
       |> stream(:releases, releases)}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin")}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _session, socket) do
    {:noreply,
     socket
     |> assign_breadcrumbs([
       {"Dashboard", ~p"/admin"},
       {"Events", ~p"/admin/events"},
       {socket.assigns.event.name, ~p"/admin/events/#{socket.assigns.event.id}"},
       {"Releases", ~p"/admin/events/#{socket.assigns.event.id}/releases"}
     ])
     |> restrict_access(socket.assigns.live_action)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp restrict_access(socket, action)
       when action in [:new, :edit] do
    if Tiki.Policy.authorize?(:event_manage, socket.assigns.current_user, socket.assigns.event) do
      socket
    else
      put_flash(socket, :error, gettext("You are not authorized to do that."))
      |> redirect(to: ~p"/admin/events/#{socket.assigns.event.id}/releases")
    end
  end

  defp restrict_access(socket, _action), do: socket

  def apply_action(socket, :index, _params), do: assign(socket, :page_title, gettext("Releases"))

  def apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New Release"))
    |> assign(:release, %Release{event_id: socket.assigns.event.id})
  end

  def apply_action(socket, :edit, %{"release_id" => release_id}) do
    release = Releases.get_release!(release_id)

    if socket.assigns.event.id == release.event_id do
      socket
      |> assign(:page_title, gettext("Edit Release"))
      |> assign(:release, release)
    else
      socket
      |> put_flash(:error, gettext("You are not authorized to do that."))
      |> redirect(to: ~p"/admin/events/#{socket.assigns.event.id}/releases")
    end
  end

  @impl true
  def handle_info({ref, {result, from, to}}, socket) do
    Process.demonitor(ref, [:flush])

    send_update(TikiWeb.AdminLive.Releases.FormComponent,
      id: "release-form-component",
      translate_result: result,
      from: from,
      to: to
    )

    {:noreply, socket}
  end
end
