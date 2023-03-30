defmodule TikiWeb.AdminLive.Event.Purchases do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Orders
  alias Tiki.Presence

  def mount(%{"id" => event_id}, _session, socket) do
    ticket_types = Orders.get_availible_ticket_types(event_id)
    event = Events.get_event!(event_id)

    Orders.subscribe(event_id)

    initial_count = Presence.list("presence:event:#{event_id}") |> map_size
    TikiWeb.Endpoint.subscribe("presence:event:#{event_id}")

    {:ok, assign(socket, ticket_types: ticket_types, event: event, online_count: initial_count)}
  end

  def handle_info({:order_updated, _order}, socket) do
    ticket_types = Orders.get_availible_ticket_types(socket.assigns.event.id)

    {:noreply, assign(socket, ticket_types: ticket_types)}
  end

  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
        %{assigns: %{online_count: count}} = socket
      ) do
    online_count = count + map_size(joins) - map_size(leaves)
    {:noreply, assign(socket, :online_count, online_count)}
  end

  def render(assigns) do
    ~H"""
    Det är <%= @online_count %> personer online just nu.
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
