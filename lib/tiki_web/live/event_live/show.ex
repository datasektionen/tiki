defmodule TikiWeb.EventLive.Show do
  use TikiWeb, :live_view

  alias Tiki.Checkouts
  alias TikiWeb.EventLive.PurchaseComponent
  alias Tiki.Events
  alias Tiki.Presence

  @impl true
  def mount(%{"id" => event_id}, _session, socket) do
    ticket_types = Events.get_ticket_types(event_id)
    event = Events.get_event!(event_id)

    initial_count = Presence.list("presence:event:#{event_id}") |> map_size

    if connected?(socket) do
      TikiWeb.Endpoint.subscribe("presence:event:#{event_id}")
      Presence.track(self(), "presence:event:#{event_id}", socket.id, %{})
    end

    {:ok, assign(socket, ticket_types: ticket_types, event: event, online_count: initial_count)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def apply_action(socket, :purchase, _params) do
    socket
    |> assign(:page_title, "Köp biljett")
  end

  def apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, socket.assigns.event.name)
  end

  @impl true
  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
        %{assigns: %{online_count: count}} = socket
      ) do
    online_count = count + map_size(joins) - map_size(leaves)
    {:noreply, assign(socket, :online_count, online_count)}
  end

  @impl true
  def handle_info({:timeout, %{id: id} = meta}, socket) do
    send_update(PurchaseComponent, id: id, action: {:timeout, meta})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:tickets_updated, _ticket_types} = msg, socket) do
    send_update(PurchaseComponent, id: socket.assigns.event.id, action: msg)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:create_stripe_payment_intent, order_id, user_id, price}, socket) do
    with {:ok, intent} <- Checkouts.create_stripe_payment_intent(order_id, user_id, price) do
      send_update(PurchaseComponent,
        id: socket.assigns.event.id,
        action: {:stripe_intent, intent}
      )

      {:noreply, socket}
    else
      {:error, error} ->
        {:noreply, socket}
    end
  end

  defp month_name(month) do
    {"januari", "februari", "mars", "april", "maj", "juni", "juli", "augusti", "september",
     "oktober", "november", "december"}
    |> elem(month - 1)
  end
end
