defmodule TikiWeb.EventLive.Index do
  use TikiWeb, :live_view

  alias Tiki.Events

  def mount(_params, _session, socket) do
    events = Events.list_events()

    {:ok, assign(socket, events: events)}
  end

  def render(assigns) do
    ~H"""
    <div class="mb-4 text-lg font-bold">Listar alla events</div>

    <div class="grid gap-4 md:grid-cols-2">
      <.link
        :for={event <- @events}
        navigate={~p"/events/#{event}"}
        class="shadow-xs flex flex-col gap-1 rounded-lg border px-4 py-4 hover:bg-accent/50"
      >
        <div class="text-lg font-bold"><%= event.name %></div>
        <div class="text-muted-foreground text-sm">
          <%= Calendar.strftime(event.event_date, "%y-%m-%d %H:%M") %>
        </div>
      </.link>
    </div>
    """
  end
end
