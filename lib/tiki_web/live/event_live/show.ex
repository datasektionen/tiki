defmodule TikiWeb.EventLive.Show do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Presence

  def mount(%{"id" => event_id}, _session, socket) do
    ticket_types = Events.get_ticket_types(event_id)
    event = Events.get_event!(event_id)

    initial_count = Presence.list("presence:event:#{event_id}") |> map_size
    TikiWeb.Endpoint.subscribe("presence:event:#{event_id}")

    Presence.track(
      self(),
      "presence:event:#{event_id}",
      socket.id,
      %{}
    )

    {:ok, assign(socket, ticket_types: ticket_types, event: event, online_count: initial_count)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def apply_action(socket, :purchase, params) do
    socket
    |> assign(:page_title, "Köp biljett")
  end

  def apply_action(socket, :index, params) do
    socket
    |> assign(:page_title, socket.assigns.event.name)
  end

  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
        %{assigns: %{online_count: count}} = socket
      ) do
    online_count = count + map_size(joins) - map_size(leaves)
    {:noreply, assign(socket, :online_count, online_count)}
  end
end
