defmodule Tiki.Orders.PubSub do
  @moduledoc """
  PubSub interface for order operations.

  This module provides a clean, discoverable API for publishing and subscribing
  to order events. All events are published via Phoenix.PubSub and work
  transparently across multiple application instances.

  ## Topic Design

  Topics are designed for fine-grained subscriptions:

  - `order:<order_id>` - All events for a specific order (created, paid, cancelled)
  - `event:<event_id>` - All ticket availability changes for an event
  - `event:<event_id>:tickets` - Check-in updates for an event (real-time ticket scanning)
  - `event:<event_id>:purchases` - Order creation/payment for event dashboard
  """

  require Logger
  alias Tiki.Orders.Events
  alias Phoenix.PubSub

  @pubsub Tiki.PubSub

  # ============================================================================
  # Broadcast Functions - Publishing Events
  # ============================================================================

  @doc """
  Broadcasts an OrderCreated event.
  """
  def broadcast_order_created(order) do
    event = Events.order_created(order)
    PubSub.broadcast(@pubsub, order_topic(order.id), event)

    # Also broadcast to event listeners (shows in event purchase feed)
    broadcast_tickets_updated(order.event_id, get_available_types(order.event_id))

    :ok
  end

  @doc """
  Broadcasts an OrderPaid event.
  """
  def broadcast_order_paid(order) do
    event = Events.order_paid(order)
    PubSub.broadcast(@pubsub, order_topic(order.id), event)
    PubSub.broadcast(@pubsub, purchases_topic(order.event_id), event)

    # Also broadcast inventory update (paid orders affect availability)
    broadcast_tickets_updated(order.event_id, get_available_types(order.event_id))

    :ok
  end

  @doc """
  Broadcasts an OrderCancelled event.
  """
  def broadcast_order_cancelled(order, reason \\ :unknown) do
    event = Events.order_cancelled(order, reason)
    PubSub.broadcast(@pubsub, order_topic(order.id), event)

    # Also broadcast inventory update (released tickets)
    broadcast_tickets_updated(order.event_id, get_available_types(order.event_id))

    :ok
  end

  @doc """
  Broadcasts ticket availability changes.

  Called whenever inventory for an event changes (order created, paid, cancelled).
  """
  def broadcast_tickets_updated(event_id, ticket_types) do
    event = Events.tickets_updated(event_id, ticket_types)
    PubSub.broadcast(@pubsub, event_topic(event_id), event)
    :ok
  end

  @doc """
  Broadcasts a ticket check-in event.
  """
  def broadcast_ticket_checked_in(ticket, event_id) do
    event = Events.ticket_checked_in(ticket, event_id)
    PubSub.broadcast(@pubsub, event_tickets_topic(event_id), event)
    :ok
  end

  # ============================================================================
  # Subscribe Functions - Listening to Events
  # ============================================================================

  @doc """
  Subscribes to all events for a specific order.

  Use in detail views where you want to see order status changes.

  ## Events Received

  - `Orders.Events.OrderCreated`
  - `Orders.Events.OrderPaid`
  - `Orders.Events.OrderCancelled`
  """
  def subscribe_to_order(order_id) do
    PubSub.subscribe(@pubsub, order_topic(order_id))
  end

  @doc """
  Subscribes to ticket availability and order status changes for an event.

  ## Events Received

  - `Orders.Events.OrderCreated`
  - `Orders.Events.OrderPaid`
  - `Orders.Events.OrderCancelled`
  - `Orders.Events.TicketsUpdated` - Inventory changed
  """
  def subscribe_to_event(event_id) do
    PubSub.subscribe(@pubsub, event_topic(event_id))
  end

  @doc """
  Subscribes to ticket check-in events for an event.

  ## Events Received

  - `Orders.Events.TicketCheckedIn` - Ticket scanned at entry
  """
  def subscribe_to_ticket_checkins(event_id) do
    PubSub.subscribe(@pubsub, event_tickets_topic(event_id))
  end

  @doc """
  Subscribes to order purchases.

  ## Events Received

  - `Orders.Events.OrderPaid`
  """
  def subscribe_to_purchases(event_id) do
    PubSub.subscribe(@pubsub, purchases_topic(event_id))
  end

  @doc """
  Unsubscribes from an event's updates.
  """
  def unsubscribe_from_event(event_id) do
    PubSub.unsubscribe(@pubsub, event_topic(event_id))
  end

  # ============================================================================
  # Deprecated Functions - Migration Path
  # ============================================================================

  @doc false
  def subscribe(event_id, :purchases) do
    Logger.warning(
      "Orders.subscribe(event_id, :purchases) is deprecated, use Orders.PubSub.subscribe_to_event_purchases/1"
    )

    subscribe_to_event(event_id)
  end

  @doc false
  def subscribe(event_id, :tickets) do
    Logger.warning(
      "Orders.subscribe(event_id, :tickets) is deprecated, use Orders.PubSub.subscribe_to_ticket_checkins/1"
    )

    subscribe_to_ticket_checkins(event_id)
  end

  @doc false
  def subscribe(event_id) do
    Logger.warning(
      "Orders.subscribe(event_id) is deprecated, use Orders.PubSub.subscribe_to_event_tickets/1"
    )

    subscribe_to_event(event_id)
  end

  @doc false
  def unsubscribe(event_id) do
    Logger.warning(
      "Orders.unsubscribe(event_id) is deprecated, use Orders.PubSub.unsubscribe_from_event/1"
    )

    unsubscribe_from_event(event_id)
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp order_topic(order_id), do: "order:#{order_id}"
  defp event_topic(event_id), do: "event:#{event_id}"
  defp purchases_topic(event_id), do: "event:#{event_id}:purchases"
  defp event_tickets_topic(event_id), do: "event:#{event_id}:tickets"

  # Helper to fetch ticket availability - call to Tickets context
  defp get_available_types(event_id) do
    Tiki.Tickets.get_available_ticket_types(event_id)
  rescue
    e ->
      Logger.error("Failed to get available types: #{inspect(e)}")
      []
  end
end
