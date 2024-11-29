defmodule TikiWeb.OrderLive.Ticket do
  use TikiWeb, :live_view

  alias Tiki.Orders

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <.back navigate={~p"/orders/#{@ticket.order_id}"}>
        <%= gettext("Back to order") %>
      </.back>

      <.link navigate={~p"/tickets/#{@ticket}/form"}>
        <.button variant="secondary">
          <%= gettext("Edit details") %>
        </.button>
      </.link>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"id" => ticket_id}, _session, socket) do
    ticket = Orders.get_ticket!(ticket_id)
    {:ok, assign(socket, ticket: ticket)}
  end
end
