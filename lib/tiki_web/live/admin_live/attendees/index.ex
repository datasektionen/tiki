defmodule TikiWeb.AdminLive.Attendees.Index do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Orders

  import TikiWeb.Component.Card
  import TikiWeb.Component.Badge

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

  def handle_params(_params, _url, socket) do
    {:noreply,
     assign(socket, :page_title, gettext("Attendees"))
     |> assign_breadcrumbs([
       {"Dashboard", ~p"/admin"},
       {"Events", ~p"/admin/events"},
       {socket.assigns.event.name, ~p"/admin/events/#{socket.assigns.event.id}"},
       {"Attendees", ~p"/admin/events/#{socket.assigns.event.id}/attendees"}
     ])}
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
    <div class="grid gap-4 sm:grid-cols-6">
      <.card_title class="sm:col-span-6">
        <%= gettext("Sold tickets") %>
      </.card_title>

      <div class="flex flex-row items-center gap-2 sm:col-span-6">
        <.leading_logo_input
          name="a"
          value=""
          type="text"
          placeholder={gettext("Search")}
          class="max-w-xl flex-1"
        />

        <div>
          <.simple_select id="sort" name="sort" options={[gettext("Sort by date")]} value="" />
        </div>

        <.button navigate={~p"/admin/events/{@event}/attendees/new"} class="ml-auto">
          <%= gettext("New attendee") %>
        </.button>
      </div>

      <.card class="sm:col-span-6">
        <ul id="tickets" phx-update="stream" role="list" class="divide-accent divide-y">
          <.ticket_item :for={{id, ticket} <- @streams.tickets} ticket={ticket} id={id} />
        </ul>
      </.card>
    </div>
    """
  end

  attr :ticket, :map
  attr :rest, :global

  defp ticket_item(assigns) do
    ~H"""
    <li class="relative flex items-center justify-between gap-x-6 px-2 py-4 first:rounded-t-xl last:rounded-b-xl hover:bg-accent/50 sm:px-4 lg:px-6">
      <div class="min-w-0">
        <div class="flex items-start gap-x-3">
          <.link navigate={~p"/admin/events/#{@ticket.order.event_id}/attendees/#{@ticket}"}>
            <span class="absolute inset-x-0 -top-px bottom-0"></span>
            <p
              :if={@ticket.order.user.full_name}
              class="text-foreground text-sm font-semibold leading-6"
            >
              <%= @ticket.order.user.full_name %>
            </p>
          </.link>
          <.badge variant="outline">
            <.icon name="hero-ticket-mini" class="mr-1 inline-block h-2 w-2" />
            <span class="text-xs"><%= @ticket.ticket_type.name %></span>
          </.badge>
        </div>
        <div class="text-muted-foreground mt-1 flex items-center gap-x-2 text-xs leading-5">
          <p class="truncate"><%= @ticket.order.user.email %></p>
          <svg viewBox="0 0 2 2" class="h-0.5 w-0.5 fill-current">
            <circle cx="1" cy="1" r="1" />
          </svg>
          <p class="whitespace-nowrap">
            <%= gettext("Purchased") %>
            <time datetime="2023-03-17T00:00Z">
              <%= Calendar.strftime(@ticket.order.updated_at, "%b %d %H:%M") %>
            </time>
          </p>
        </div>
      </div>
      <div class="flex flex-none items-center gap-x-4"></div>
      <svg
        class="text-muted-foreground h-5 w-5 flex-none"
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
