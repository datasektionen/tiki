defmodule Tiki.Orders.Events do
  @moduledoc """
  Event definitions for order operations.

  This module defines all events that can occur in the order lifecycle. Each event
  is a struct that clearly documents what happened and when.

  ## Event Subscriptions

  Different contexts subscribe to different events:

  - LiveViews subscribe to get real-time updates for users
  - Backend systems can subscribe for async processing
  - Multiple handlers can listen to the same event

  ## Event Order

  Events are published in this order for a successful order flow:
  1. OrderCreated - immediately when tickets are reserved
  2. TicketsUpdated - after creating order (inventory changed)
  3. OrderPaid - when checkout completes
  4. TicketsUpdated - again (paid orders affect inventory differently)
  """

  # ============================================================================
  # Event Structs
  # ============================================================================

  defmodule OrderCreated do
    @moduledoc """
    Fired when a new order is created with pending status.

    ## Fields

    - `order` - The Order struct with all associated data (tickets, user, event)
    - `timestamp` - When this event occurred
    """
    defstruct [:order, :timestamp]
  end

  defmodule OrderPaid do
    @moduledoc """
    Fired when payment is successfully confirmed.

    ## Fields

    - `order` - The Order struct with status = :paid
    - `timestamp` - When payment was confirmed
    - `payment_method` - :stripe or :swish
    """
    defstruct [:order, :timestamp]
  end

  defmodule OrderCancelled do
    @moduledoc """
    Fired when an order is cancelled.

    This can happen due to:
    - User cancellation
    - Timeout (order not paid within 10 minutes)
    - System cleanup

    ## Fields

    - `order` - The Order struct with status = :cancelled
    - `timestamp` - When cancellation occurred
    - `reason` - :timeout, :user_requested, :admin, etc.
    """
    defstruct [:order, :timestamp, :reason]
  end

  defmodule TicketsUpdated do
    @moduledoc """
    Fired when ticket availability changes for an event.

    This includes pending and purchased tickets. Fired when:
    - Order created (reduces available count)
    - Order paid (moves from pending to purchased)
    - Order cancelled (increases available count)
    - Ticket types changed, eg. if a ticket type is added, removed, or its limits change

    ## Fields

    - `event_id` - The event affected
    - `ticket_types` - List of ticket types with availability metadata:
      - `ticket_type` - The TicketType struct
      - `available` - Count of unallocated tickets
      - `pending` - Count in pending orders (will become unavailable if paid)
      - `purchased` - Count in paid orders
      - `release` - Associated Release, if any
    - `timestamp` - When the change occurred
    """
    defstruct [:event_id, :ticket_types, :timestamp]
  end

  defmodule TicketCheckedIn do
    @moduledoc """
    Fired when a ticket is checked in at an event.

    ## Fields

    - `ticket` - The Ticket struct with checked_in_at timestamp
    - `event_id` - The event where check-in occurred
    - `timestamp` - When check-in happened
    """
    defstruct [:ticket, :event_id, :timestamp]
  end

  # ============================================================================
  # Public API - Helpers for creating and inspecting events
  # ============================================================================

  @doc """
  Creates an OrderCreated event.

  ## Examples

      iex> OrderCreated.create(order)
      %OrderCreated{order: order, timestamp: ...}
  """
  def order_created(order) do
    %OrderCreated{
      order: order,
      timestamp: DateTime.utc_now()
    }
  end

  @doc "Creates an OrderPaid event."
  def order_paid(order) do
    %OrderPaid{
      order: order,
      timestamp: DateTime.utc_now()
    }
  end

  @doc "Creates an OrderCancelled event."
  def order_cancelled(order, reason \\ :unknown) do
    %OrderCancelled{
      order: order,
      reason: reason,
      timestamp: DateTime.utc_now()
    }
  end

  @doc "Creates a TicketsUpdated event."
  def tickets_updated(event_id, ticket_types) do
    %TicketsUpdated{
      event_id: event_id,
      ticket_types: ticket_types,
      timestamp: DateTime.utc_now()
    }
  end

  @doc "Creates a TicketCheckedIn event."
  def ticket_checked_in(ticket, event_id) do
    %TicketCheckedIn{
      ticket: ticket,
      event_id: event_id,
      timestamp: DateTime.utc_now()
    }
  end
end
