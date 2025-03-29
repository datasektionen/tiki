defmodule TikiWeb.AdminLive.Attendees.CheckIn do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Orders

  import TikiWeb.Component.Card
  import TikiWeb.Component.Badge
  import TikiWeb.Component.Input
  import TikiWeb.Component.Tabs

  def mount(%{"id" => event_id}, _session, socket) do
    event = Events.get_event!(event_id)
    tickets = Orders.list_tickets_for_event(event_id)

    if connected?(socket) do
      Orders.subscribe(event_id, :tickets)
      Orders.subscribe(event_id, :purchases)
    end

    {:ok,
     socket
     |> assign(event: event)
     |> assign(page_title: gettext("Check-in"))
     |> stream(:tickets, tickets)
     |> assign_breadcrumbs([
       {"Dashboard", ~p"/admin/"},
       {"Events", ~p"/admin/events"},
       {event.name, ~p"/admin/events/#{event.id}"},
       {"Check-in", ~p"/admin/events/#{event.id}/check-in"}
     ])}
  end

  def handle_event("check_in", %{"ticket_id" => ticket_id}, socket) do
    case Orders.toggle_check_in(ticket_id) do
      {:ok, ticket} ->
        {:noreply, stream_insert(socket, :tickets, ticket)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Something went wrong")}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <.card_title class="sm:col-span-6">
        {gettext("Check-in")}
      </.card_title>

      <.tabs :let={builder} default="table" id="tab">
        <.tabs_list class="w-xl grid grid-cols-2">
          <.tabs_trigger builder={builder} value="table">{gettext("Table")}</.tabs_trigger>
          <.tabs_trigger builder={builder} value="scanner">{gettext("Scanner")}</.tabs_trigger>
        </.tabs_list>

        <.tabs_content value="table">
          <div class="grid gap-4 sm:grid-cols-6">
            <div class="flex flex-row items-center gap-2 sm:col-span-6">
              <.leading_logo_input
                name="a"
                value=""
                type="text"
                placeholder={gettext("Search")}
                class="max-w-xl flex-1"
              />

              <div class="ml-auto">
                <.simple_select id="sort" name="sort" options={[gettext("TODO: Filter")]} value="" />
              </div>
            </div>

            <.card class="sm:col-span-6">
              <ul id="tickets" phx-update="stream" role="list" class="divide-accent divide-y">
                <.ticket_item :for={{id, ticket} <- @streams.tickets} ticket={ticket} id={id} />
              </ul>
            </.card>
          </div>
        </.tabs_content>
        <.tabs_content value="scanner">
          <.button
            id="start_scan"
            phx-click={JS.dispatch("start_scan", to: "#video") |> JS.hide(to: "#start_scan")}
          >
            Start Scan
          </.button>
          <video id="video" phx-hook="Scanner" class="h-full w-full"></video>
        </.tabs_content>
      </.tabs>
    </div>
    """
  end

  def handle_info({:ticket_updated, ticket}, socket) do
    {:noreply, stream_insert(socket, :tickets, ticket)}
  end

  def handle_info({:order_confirmed, order}, socket) do
    socket =
      Enum.reduce(order.tickets, socket, fn ticket, acc ->
        ticket = %{ticket | order: order}
        stream_insert(acc, :tickets, ticket, at: 0)
      end)

    {:noreply, socket}
  end

  attr :ticket, :map
  attr :id, :integer
  attr :rest, :global

  defp ticket_item(assigns) do
    ~H"""
    <li
      id={@id}
      class={[
        "relative flex items-center justify-between gap-x-6 px-2 py-4 first:rounded-t-xl last:rounded-b-xl hover:bg-accent/50 sm:px-4 lg:px-6",
        @ticket.checked_in_at && "bg-success-background"
      ]}
    >
      <div class="min-w-0">
        <div class="flex items-start gap-x-3">
          <span class=" inset-x-0 -top-px bottom-0"></span>
          <p
            :if={@ticket.order.user.full_name}
            class="text-foreground text-sm font-semibold leading-6"
          >
            {@ticket.order.user.full_name}
          </p>
          <.badge variant="outline">
            <.icon name="hero-ticket-mini" class="text-muted-foreground mr-1 inline-block h-2 w-2" />
            <span class="text-muted-foreground text-xs font-normal">{@ticket.ticket_type.name}</span>
          </.badge>
        </div>
      </div>
      <div phx-click={JS.push("check_in", value: %{ticket_id: @ticket.id})}>
        <.input type="checkbox" name="ticket_id" value={@ticket.id} checked={@ticket.checked_in_at} />
      </div>
    </li>
    """
  end
end
