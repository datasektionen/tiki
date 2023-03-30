defmodule TikiWeb.AdminLive.Event.Purchases do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Orders

  def mount(%{"id" => event_id}, _session, socket) do
    ticket_types = Orders.get_availible_ticket_types(event_id)
    event = Events.get_event!(event_id)

    Orders.subscribe(event_id)

    {:ok, assign(socket, ticket_types: ticket_types, event: event)}
  end

  def handle_info({:order_updated, _order}, socket) do
    ticket_types = Orders.get_availible_ticket_types(socket.assigns.event.id)

    {:noreply, assign(socket, ticket_types: ticket_types)}
  end

  def render(assigns) do
    ~H"""
    Köpta biljetter:
    <div class="flex flex-col">
      <div :for={ticket_type <- @ticket_types}>
        <span>Biljettyp: <%= ticket_type.ticket_type.name %>,</span>
        <span>Reserverade: <%= ticket_type.pending %>,</span>
        <span>Köpta: <%= ticket_type.purchased %>,</span>
        <span>Tillgängliga: <%= ticket_type.available %></span>
      </div>
    </div>
    """
  end
end
