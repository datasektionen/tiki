defmodule TikiWeb.AdminLive.Event.Index do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Events.Event
  import TikiWeb.Component.Card

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :events, Events.list_events())}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit event"))
    |> assign(:event, Events.get_event!(id))
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
    {:noreply, stream_insert(socket, :events, event)}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    event = Events.get_event!(id)
    {:ok, _} = Events.delete_event(event)

    {:noreply, stream_delete(socket, :events, event)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="grid gap-4 sm:grid-cols-6">
      <.card_title class="sm:col-span-6">
        <%= gettext("All events") %>
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
          <select
            id="sort"
            name="sort"
            class="border-input bg-background ring-offset-background flex-0 h-10 w-full rounded-md border py-2 pr-10 pl-3 text-sm file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:ring-ring focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
          >
            <%= Phoenix.HTML.Form.options_for_select(["Sort by date"], "") %>
          </select>
        </div>

        <.button navigate={~p"/admin/events/new"} class="ml-auto">
          <%= gettext("New event") %>
        </.button>
      </div>

      <.card class="sm:col-span-6">
        <.table
          id="events"
          rows={@streams.events}
          row_click={fn {_id, event} -> JS.navigate(~p"/admin/events/#{event}") end}
        >
          <:col :let={{_id, event}} label={gettext("Name")}><%= event.name %></:col>
          <:col :let={{_id, event}} label={gettext("Location")}><%= event.location %></:col>
          <:col :let={{_id, event}} label={gettext("Date")}>
            <%= Calendar.strftime(event.event_date, "%Y-%m-%d") %>
          </:col>
        </.table>
      </.card>
    </div>
    """
  end
end
