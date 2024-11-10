defmodule TikiWeb.AdminLive.Event.Show do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Orders
  alias Tiki.Presence

  import TikiWeb.Component.Card

  @impl Phoenix.LiveView
  def mount(%{"id" => event_id}, _session, socket) do
    initial_count = Presence.list("presence:event:#{event_id}") |> map_size
    TikiWeb.Endpoint.subscribe("presence:event:#{event_id}")

    if connected?(socket), do: Orders.subscribe(event_id, :purchases)

    {:ok, assign(socket, online_count: initial_count)}
  end

  @impl Phoenix.LiveView
  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
        %{assigns: %{online_count: count}} = socket
      ) do
    online_count = count + map_size(joins) - map_size(leaves)
    {:noreply, assign(socket, :online_count, online_count)}
  end

  def handle_info({:order_confirmed, order}, socket) do
    tickets_in_order = Enum.map(order.tickets, fn ticket -> Map.put(ticket, :order, order) end)

    {:noreply, stream(socket, :recent_tickets, tickets_in_order, at: 0, limit: 10)}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => event_id} = params, _, socket) do
    event = Events.get_event!(event_id, preload_ticket_types: true)
    recent_tickets = Orders.list_tickets_for_event(event.id, limit: 10)

    {:noreply,
     socket
     |> assign(:event, event)
     |> apply_action(socket.assigns.live_action, params)
     |> stream(:recent_tickets, recent_tickets)}
  end

  def apply_action(socket, :show, _params) do
    assign(socket, :page_title, socket.assigns.event.name)
    |> assign_breadcrumbs([
      {"Dashboard", ~p"/admin"},
      {"Events", ~p"/admin/events"},
      {socket.assigns.event.name, ~p"/admin/events/#{socket.assigns.event.id}"}
    ])
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.header>
      <%= @event.name %>
      <:subtitle>
        <span>
          <%= Tiki.Cldr.DateTime.to_string!(@event.event_date, format: :yMMMEd) |> String.capitalize() %>
        </span>·
        <span>
          <%= @event.location %>
        </span>
      </:subtitle>
      <:actions>
        <.button navigate={~p"/admin/events/#{@event}/edit"} class="hidden lg:inline-block">
          <%= gettext("Edit event") %>
        </.button>
        <.button navigate={~p"/events/#{@event}"}>
          <%= gettext("View event page") %>
        </.button>
      </:actions>
    </.header>
    <div class="flex flex-col gap-8 py-8">
      <div class="grid gap-8 lg:grid-cols-3">
        <.card>
          <.card_header class="flex flex-row items-center justify-between space-y-0 pb-2">
            <.card_title class="text-sm font-medium">
              <%= gettext("Tickets sold") %>
            </.card_title>
            <.icon name="hero-ticket" class="text-muted-foreground h-4 w-4" />
          </.card_header>
          <.card_content>
            <div class="text-2xl font-bold">N/A</div>
          </.card_content>
        </.card>
        <.card>
          <.card_header class="flex flex-row items-center justify-between space-y-0 pb-2">
            <.card_title class="text-sm font-medium">
              <%= gettext("Total sales") %>
            </.card_title>
            <.icon name="hero-ticket" class="text-muted-foreground h-4 w-4" />
          </.card_header>
          <.card_content>
            <div class="text-2xl font-bold">N/A</div>
          </.card_content>
        </.card>
        <.card>
          <.card_header class="flex flex-row items-center justify-between space-y-0 pb-2">
            <.card_title class="text-sm font-medium">
              <%= gettext("Current visitors") %>
            </.card_title>
            <.icon name="hero-user-group" class="text-muted-foreground h-4 w-4" />
          </.card_header>
          <.card_content>
            <div class="text-2xl font-bold">
              <%= @online_count %>
            </div>
          </.card_content>
        </.card>
      </div>
      <div class="grid gap-4 xl:grid-cols-7">
        <.card class="xl:col-span-7">
          <.card_header>
            <.card_title>
              <%= gettext("Recent orders") %>
            </.card_title>
          </.card_header>
          <.card_content>
            <.table
              id="recent_orders"
              rows={@streams.recent_tickets}
              row_click={
                fn {_id, ticket} ->
                  JS.navigate(~p"/admin/events/#{@event}/attendees/#{ticket}")
                end
              }
            >
              <:col :let={{_id, ticket}} label={gettext("Name")}>
                <%= ticket.order.user.full_name %>
              </:col>
              <:col :let={{_id, ticket}} label={gettext("Date")}>
                <%= Calendar.strftime(ticket.inserted_at, "%Y-%m-%d") %>
              </:col>
            </.table>
          </.card_content>
        </.card>
      </div>
    </div>
    """
  end
end
