defmodule TikiWeb.AdminLive.Event.PurchaseSummary do
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

  def handle_info({:tickets_updated, ticket_types}, socket) do
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
    <div class="mb-4">
      <h1 class="font-bold text-xl mb-1">Livestatus för <%= @event.name %></h1>
      <div class="text-gray-600">
        Det är <%= @online_count %> personer online just nu på biljettsidan.
      </div>
    </div>

    <h2 class="font-bold text-lg mb-3">Biljettyper</h2>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div
        :for={ticket_type <- @ticket_types}
        class="border rounded-xl shadow-sm p-4 hover:bg-gray-50"
      >
        <div class="font-bold text-lg"><%= ticket_type.name %></div>
        <div><span class="font-bold"><%= ticket_type.available %> </span>tillgängliga</div>
        <div><span class="font-bold"><%= ticket_type.purchased %> </span>köpta</div>
        <div><span class="font-bold"><%= ticket_type.pending %> </span>reserverade</div>
      </div>
    </div>
    """
  end
end
