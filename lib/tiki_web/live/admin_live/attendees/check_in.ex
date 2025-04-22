defmodule TikiWeb.AdminLive.Attendees.CheckIn do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Orders
  alias Tiki.Tickets

  import TikiWeb.Component.Card
  import TikiWeb.Component.Badge
  import TikiWeb.Component.Input
  import TikiWeb.Component.Tabs

  def mount(%{"id" => event_id}, _session, socket) do
    event = Events.get_event!(event_id)
    tickets = Orders.list_tickets_for_event(event_id)

    ticket_types =
      Tickets.get_cached_available_ticket_types(event_id) |> Enum.map(&{&1.name, &1.id})

    if connected?(socket) do
      Orders.subscribe(event_id, :tickets)
    end

    {:ok,
     socket
     |> assign(event: event)
     |> assign(page_title: gettext("Check-in"))
     |> assign(query: nil, filtered_ticket_type: nil)
     |> stream(:tickets, tickets)
     |> assign(:ticket_types, ticket_types)
     |> assign(:empty?, Enum.empty?(tickets))
     |> assign_breadcrumbs([
       {"Dashboard", ~p"/admin/"},
       {"Events", ~p"/admin/events"},
       {event.name, ~p"/admin/events/#{event.id}"},
       {"Check-in", ~p"/admin/events/#{event.id}/check-in"}
     ])}
  end

  def handle_event("filter", %{"query" => query, "filter" => filter}, socket) do
    tickets =
      Orders.list_tickets_for_event(socket.assigns.event.id,
        query: query,
        ticket_type: filter
      )

    {:noreply,
     assign(socket, query: query, filtered_ticket_type: filter)
     |> stream(:tickets, tickets, reset: true)
     |> assign(:empty?, Enum.empty?(tickets))}
  end

  def handle_event("check_in", %{"ticket_id" => ticket_id, "check_out" => false}, socket),
    do: toggle_check_in(socket, ticket_id, check_out: false)

  def handle_event("check_in", %{"ticket_id" => ticket_id}, socket),
    do: toggle_check_in(socket, ticket_id)

  defp toggle_check_in(socket, ticket_id, opts \\ []) do
    case Orders.toggle_check_in(ticket_id, opts) do
      {:ok, ticket} ->
        {:noreply,
         stream_insert(socket, :tickets, ticket)
         |> then(fn socket ->
           if Keyword.get(opts, :check_out, true),
             do: socket,
             else: put_flash(socket, :info, gettext("Checked in: %{name}", name: ticket.name))
         end)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <.card_title class="sm:col-span-6">
        {gettext("Check-in")}
      </.card_title>
      <p class="text-muted-foreground text-sm">
        {gettext(
          "Manage check-in for your event. You can either use the table to manually check in users, or scan the qr-code on their ticket. To scan, you need to allow the website to use your camera."
        )}
      </p>

      <.tabs :let={builder} default="table" id="tab" class="mt-4">
        <.tabs_list class="grid max-w-xl grid-cols-2">
          <.tabs_trigger builder={builder} value="table">{gettext("Table")}</.tabs_trigger>
          <.tabs_trigger builder={builder} value="scanner">{gettext("Scanner")}</.tabs_trigger>
        </.tabs_list>

        <.tabs_content value="table" class="mt-4">
          <div class="grid gap-4 sm:grid-cols-6">
            <.form
              for={%{}}
              phx-change="filter"
              class="flex flex-row items-center gap-2 sm:col-span-6"
            >
              <.leading_logo_input
                name="query"
                value={@query}
                type="text"
                phx-debounce="300"
                placeholder={gettext("Search")}
                class="max-w-xl flex-1"
              />

              <div class="ml-auto">
                <.simple_select
                  id="filter"
                  name="filter"
                  options={@ticket_types}
                  prompt={gettext("Ticket type")}
                  value={@filtered_ticket_type}
                />
              </div>
            </.form>

            <.card class=" sm:col-span-6">
              <li
                :if={@empty?}
                class="inline-flex cursor-pointer items-center justify-between gap-x-2 p-4 first:rounded-t-xl last:rounded-b-xl sm:px-4 lg:px-6"
              >
                <.icon name="hero-ticket-mini" class="size-4" />
                <span class="text-sm">
                  {gettext("No tickets")}
                </span>
              </li>
              <ul id="tickets" role="list" phx-update="stream" class="divide-accent divide-y">
                <.ticket_item :for={{id, ticket} <- @streams.tickets} ticket={ticket} id={id} />
              </ul>
            </.card>
          </div>
        </.tabs_content>
        <.tabs_content value="scanner" class="mt-4">
          <.button
            id="start_scan"
            phx-click={JS.dispatch("start_scan", to: "#video") |> JS.hide(to: "#start_scan")}
          >
            {gettext("Start Scan")}
          </.button>
          <video id="video" phx-hook="Scanner" class="h-full w-full rounded-xl"></video>
        </.tabs_content>
      </.tabs>
    </div>
    """
  end

  def handle_info({:ticket_updated, ticket}, socket) do
    {:noreply, stream_insert(socket, :tickets, ticket)}
  end

  attr :ticket, :map
  attr :id, :integer
  attr :rest, :global

  defp ticket_item(assigns) do
    ~H"""
    <li
      id={@id}
      class={[
        "relative flex cursor-pointer items-center justify-between gap-x-6 p-4 first:rounded-t-xl last:rounded-b-xl hover:bg-accent/50 sm:px-4 lg:px-6",
        @ticket.checked_in_at && "bg-success-background hover:bg-success-background/50"
      ]}
      phx-click={JS.push("check_in", value: %{ticket_id: @ticket.id})}
    >
      <div class="min-w-0">
        <div class="flex items-start gap-x-3">
          <p :if={@ticket.name} class="text-foreground text-sm font-semibold leading-6">
            {@ticket.name}
          </p>
          <.badge variant="outline">
            <.icon name="hero-ticket-mini" class="text-muted-foreground mr-1 inline-block h-2 w-2" />
            <span class="text-muted-foreground text-xs font-normal">{@ticket.ticket_type.name}</span>
          </.badge>
        </div>
      </div>
      <div>
        <.input type="checkbox" name="ticket_id" value={@ticket.id} checked={@ticket.checked_in_at} />
      </div>
    </li>
    """
  end
end
