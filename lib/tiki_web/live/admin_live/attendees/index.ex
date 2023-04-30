defmodule TikiWeb.AdminLive.Attendees.Index do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Orders

  def mount(%{"id" => event_id}, _sesison, socket) do
    event = Events.get_event!(event_id)
    tickets = Orders.list_tickets_for_event(event_id)
    num_tickets = Enum.count(tickets)

    if connected?(socket), do: Orders.subscribe(event_id, :purchases)

    {:ok,
     socket
     |> assign(event: event)
     |> assign(num_tickets: num_tickets)
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
    <div class="border-b pb-4">
      <h2 class="mb-1 text-xl font-bold">Sålda biljetter</h2>
      <div class="text-sm text-gray-600">Totalt <%= @num_tickets %> biljetter</div>
    </div>
    <ul id="tickets" phx-update="stream" role="list" class="divide-y divide-gray-100">
      <.ticket_card :for={{id, ticket} <- @streams.tickets} ticket={ticket} id={id} />
    </ul>
    """
  end

  attr :ticket, :map
  attr :rest, :global

  defp ticket_card(assigns) do
    ~H"""
    <li class="relative flex items-center justify-between gap-x-6 px-2 py-5 hover:bg-gray-50 sm:px-4 lg:px-6">
      <div class="min-w-0">
        <div class="flex items-start gap-x-3">
          <.link navigate={~p"/admin/events/#{@ticket.order.event_id}/tickets/#{@ticket}"}>
            <span class="absolute inset-x-0 -top-px bottom-0"></span>
            <p class="text-sm font-semibold leading-6 text-gray-900">Namn Namnsson</p>
          </.link>
          <p class="ring-green-600/20 mt-0.5 inline-flex items-center gap-0.5 whitespace-nowrap rounded-md bg-gray-50 px-1.5 py-0.5 text-xs font-medium text-gray-600 ring-1 ring-inset">
            <.icon name="hero-ticket-mini" class="mr-1 inline-block h-2 w-2" />
            <span class="text-xs"><%= @ticket.ticket_type.name %></span>
          </p>
        </div>
        <div class="mt-1 flex items-center gap-x-2 text-xs leading-5 text-gray-500">
          <p class="truncate"><%= @ticket.order.user.email %></p>
          <svg viewBox="0 0 2 2" class="h-0.5 w-0.5 fill-current">
            <circle cx="1" cy="1" r="1" />
          </svg>
          <p class="whitespace-nowrap">
            Kötes
            <time datetime="2023-03-17T00:00Z">
              <%= Calendar.strftime(@ticket.order.updated_at, "%b %d %H:%M") %>
            </time>
          </p>
        </div>
      </div>
      <div class="flex flex-none items-center gap-x-4"></div>
      <svg
        class="h-5 w-5 flex-none text-gray-400"
        viewBox="0 0 20 20"
        fill="currentColor"
        aria-hidden="true"
      >
        <path
          fill-rule="evenodd"
          d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z"
          clip-rule="evenodd"
        />
      </svg>
    </li>
    """
  end
end
