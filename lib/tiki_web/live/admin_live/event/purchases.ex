defmodule TikiWeb.AdminLive.Event.Purchases do
  alias Tiki.Orders
  use TikiWeb, :live_view

  def mount(%{"id" => event_id}, _sesison, socket) do
    orders = Tiki.Orders.list_orders_for_event(event_id)
    num_orders = length(orders)
    num_tickets = Enum.map(orders, fn order -> length(order.tickets) end) |> Enum.sum()

    Orders.subscribe(event_id, :purchases)

    {:ok,
     assign(socket, num_orders: num_orders, num_tickets: num_tickets) |> stream(:orders, orders)}
  end

  def handle_info({:order_confirmed, order}, socket) do
    {:noreply,
     stream_insert(socket, :orders, order, at: 0)
     |> assign(
       num_orders: socket.assigns.num_orders + 1,
       num_tickets: socket.assigns.num_tickets + length(order.tickets)
     )}
  end

  def render(assigns) do
    ~H"""
    <h2 class="font-bold text-xl mb-2">Beställningar</h2>
    <div class="text-gray-600">
      Totalt <%= @num_orders %> beställningar med <%= @num_tickets %> biljetter
    </div>
    <.table id="orders" rows={@streams.orders}>
      <:col :let={{_id, order}} label="Tid"><%= order.updated_at %></:col>
      <:col :let={{_id, order}} label="Email"><%= order.user.email %></:col>
      <:col :let={{_id, order}} label="Antal biljetter"><%= length(order.tickets) %></:col>
      <:col :let={{_id, order}} label="Pris"><%= calculate_price(order) %> kr</:col>
    </.table>
    """
  end

  defp calculate_price(order) do
    Enum.map(order.tickets, fn ticket -> ticket.ticket_type.price end) |> Enum.sum()
  end
end
