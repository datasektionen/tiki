defmodule TikiWeb.AdminLive.Attendees.Index do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Orders

  def mount(%{"id" => event_id}, _sesison, socket) do
    event = Events.get_event!(event_id)
    tickets = Orders.list_tickets_for_event(event_id)

    if connected?(socket), do: Orders.subscribe(event_id, :purchases)

    {:ok,
     socket
     |> assign(event: event)
     |> stream(:tickets, tickets)}
  end

  def handle_info({:order_confirmed, order}, socket) do
    socket =
      Enum.reduce(order.tickets, socket, fn ticket, acc ->
        ticket = %{ticket | order: order}
        stream_insert(acc, :tickets, ticket, at: 0)
      end)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <h2 class="mb-2 text-xl font-bold">Sålda biljetter</h2>
    <div id="tickets" phx-update="stream" class="divide-y divide-gray-200">
      <.ticket_card :for={{id, ticket} <- @streams.tickets} ticket={ticket} id={id} />
    </div>
    """
  end

  attr :ticket, :map
  attr :rest, :global

  defp ticket_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/admin/events/#{@ticket.order.event_id}/tickets/#{@ticket}"}
      class="flex flex-col py-3 hover:bg-gray-50"
      {@rest}
    >
      <div class="flex flex-row items-center justify-between">
        <div class="text-sm font-bold">Namn Namnsson</div>
        <div class="ml-auto flex flex-row items-center justify-end rounded-sm border bg-gray-200 px-1 py-px">
          <.icon name="hero-ticket-mini" class="mr-1 inline-block h-3 w-3" />
          <span class="text-sm"><%= @ticket.ticket_type.name %></span>
        </div>
      </div>

      <div class="flex flex-row items-baseline justify-between">
        <div class="text-sm text-gray-600"><%= @ticket.order.user.email %></div>
        <div class="mt-1 text-xs text-gray-500">
          <%= Calendar.strftime(@ticket.order.updated_at, "%b %d %H:%M") %>
        </div>
      </div>
    </.link>
    """
  end
end
