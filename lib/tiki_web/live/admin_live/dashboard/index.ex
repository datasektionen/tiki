defmodule TikiWeb.AdminLive.Dashboard.Index do
  use TikiWeb, :live_view

  def mount(_params, _session, socket) do
    events = Tiki.Events.list_events()

    {:ok, assign(socket, events: events)}
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Dashboard")
    |> assign(:breadcrumbs, [
      {"Dashboard", ~p"/admin"}
    ])
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-6 lg:grid-cols-3">
      <div :for={event <- @events}>
        <.event_card event={event} />
      </div>
    </div>
    """
  end

  defp event_card(assigns) do
    ~H"""
    <.link
      class="group relative block h-48 overflow-hidden rounded-lg border shadow-sm hover:bg-gray-50"
      navigate={~p"/admin/events/#{@event}"}
    >
      <img src={@event.image_url} class="object-cover" />
      <div class="absolute right-0 bottom-0 left-0 flex flex-col items-center bg-white py-2 group-hover:bg-gray-50">
        <div class="font-bold"><%= @event.name %></div>
        <div class="text-gray-500"><%= Calendar.strftime(@event.event_date, "%Y-%m-%d") %></div>
      </div>
    </.link>
    """
  end
end
