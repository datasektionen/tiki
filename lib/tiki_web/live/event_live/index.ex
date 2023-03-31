defmodule TikiWeb.EventLive.Index do
  use TikiWeb, :live_view

  alias Tiki.Events

  def mount(_params, _session, socket) do
    events = Events.list_events()

    {:ok, assign(socket, events: events)}
  end

  def render(assigns) do
    ~H"""
    <div class="font-bold text-lg mb-4">Listar alla events</div>

    <div class="grid md:grid-cols-2 gap-4">
      <.link
        :for={event <- @events}
        navigate={~p"/events/#{event}"}
        class="rounded-lg px-4 py-4 border shadow-sm hover:bg-gray-50 flex flex-col gap-1"
      >
        <div class="font-bold text-lg"><%= event.name %></div>
        <div class="text-sm text-gray-500">
          <%= Calendar.strftime(event.event_date, "%y-%m-%d %H:%M") %>
        </div>
      </.link>
    </div>
    """
  end
end
