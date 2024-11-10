defmodule TikiWeb.EmbeddedLive.Event do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Checkouts
  alias TikiWeb.EventLive.PurchaseComponent
  alias Tiki.Presence

  def mount(%{"id" => event_id}, _session, socket) do
    event = Events.get_event!(event_id)

    if connected?(socket) do
      TikiWeb.Endpoint.subscribe("presence:event:#{event_id}")
      Presence.track(self(), "presence:event:#{event_id}", socket.id, %{})
    end

    {:ok, assign(socket, event: event)}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, socket}
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
      {:error, _error} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:tickets_updated, _ticket_types} = msg, socket) do
    send_update(PurchaseComponent, id: socket.assigns.event.id, action: msg)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div :if={@live_action == :purchase}>
      <.live_component
        module={PurchaseComponent}
        id={@event.id}
        title={@event.name}
        action={@live_action}
        event={@event}
        navigate={~p"/embed/close"}
      />
    </div>
    """
  end
end
