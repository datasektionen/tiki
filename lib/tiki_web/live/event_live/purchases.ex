defmodule TikiWeb.AdminLive.Event.Purchases do
  use TikiWeb, :live_view

  alias Tiki.Orders
  @subscriber_registry :event_subscriber_registry

  def mount(%{"id" => event_id}, _session, socket) do
    purchased_tickets = Orders.get_purchased_ticket_types(event_id)

    {:ok, assign(socket, purchased_tickets: purchased_tickets)}
  end

  def handle_info({:updated_tickets, purchased}, socket) do
    {:noreply, assign(socket, purchased_tickets: purchased)}
  end

  def render(assigns) do
    ~H"""
    Köpta biljetter:
    <div :for={ticket_type <- @purchased_tickets}>
      <div><%= ticket_type.ticket_type.name %></div>
      <div><%= ticket_type.purchased %></div>
    </div>
    """
  end
end
