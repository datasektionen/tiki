defmodule TikiWeb.AdminLive.Event.Index do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Events.Event
  import TikiWeb.Component.Card
  alias Tiki.Localizer

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{current_user: user, current_team: team} = socket.assigns

    with :ok <- Tiki.Policy.authorize(:event_view, user, team) do
      events =
        Tiki.Events.list_team_events(socket.assigns.current_team.id)
        |> Localizer.localize()

      {:ok, stream(socket, :events, events)}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin")}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"event_id" => event_id}) do
    socket
    |> assign(:page_title, gettext("Edit event"))
    |> assign(:event, Events.get_event!(event_id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New event"))
    |> assign(:event, %Event{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Events")
    |> assign_breadcrumbs([
      {"Dashboard", ~p"/admin"},
      {"Events", ~p"/admin/events"}
    ])
    |> assign(:event, nil)
  end

  @impl true
  def handle_info({TikiWeb.AdminLive.Event.FormComponent, {:saved, event}}, socket) do
    {:noreply, stream_insert(socket, :events, event |> Localizer.localize())}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="grid gap-4 sm:grid-cols-6">
      <.card_title class="sm:col-span-6">
        {gettext("All events")}
      </.card_title>

      <div class="flex flex-row items-center gap-2 sm:col-span-6">
        <.leading_logo_input
          name="a"
          value=""
          type="text"
          placeholder={gettext("Search events")}
          class="max-w-xl flex-1"
        />

        <div>
          <.simple_select id="sort" name="sort" options={[gettext("Sort by date")]} value="" />
        </div>

        <.button navigate={~p"/admin/events/new"} class="ml-auto">
          {gettext("New event")}
        </.button>
      </div>

      <.card class="sm:col-span-6">
        <.table
          id="events"
          rows={@streams.events}
          row_click={fn {_id, event} -> JS.navigate(~p"/admin/events/#{event}") end}
        >
          <:col :let={{_id, event}} label={gettext("Name")}>{event.name}</:col>
          <:col :let={{_id, event}} label={gettext("Location")}>{event.location}</:col>
          <:col :let={{_id, event}} label={gettext("Date")}>
            {Calendar.strftime(event.start_time, "%Y-%m-%d")}
          </:col>
        </.table>
      </.card>
    </div>
    """
  end
end
