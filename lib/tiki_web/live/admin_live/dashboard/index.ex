defmodule TikiWeb.AdminLive.Dashboard.Index do
  use TikiWeb, :live_view

  def mount(_params, _session, socket) do
    events = Tiki.Events.list_events()

    {:ok, assign(socket, events: events)}
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-2 lg:grid-cols-3 gap-6">
      <div :for={event <- @events}>
        <.event_card event={event} />
      </div>
    </div>
    """
  end

  defp event_card(assigns) do
    ~H"""
    <.link
      class="block relative rounded-lg overflow-hidden h-48 border shadow-sm group hover:bg-gray-50"
      navigate={~p"/admin/events/#{@event}"}
    >
      <img src={@event.image_url} class="object-cover" />
      <div class="absolute bottom-0 left-0 right-0 bg-white flex flex-col items-center py-2 group-hover:bg-gray-50">
        <div class="font-bold"><%= @event.name %></div>
        <div class="text-gray-500"><%= Calendar.strftime(@event.event_date, "%Y-%m-%d") %></div>
      </div>
    </.link>
    """
  end
end
