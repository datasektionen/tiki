defmodule Tiki.OrderHandler.Worker do
  @moduledoc """
  Per-event worker for handling ticket reservations.

  Note that this is private API and should not be used directly. Use `Tiki.Orders` instead.

  This GenServer manages ticket reservations for a single event. It coordinates:

  1. **Ticket Reservation** - Validates all requirements and creates orders
  2. **Cache Management** - Caches ticket availability to avoid repeated queries
  3. **PubSub Subscriptions** - Listens for inventory changes and cache invalidation

  ## Reservation Process

  When a user reserves tickets:

  1. Public API (`reserve_tickets/3`) ensures worker is started
  2. GenServer validates all requirements via ReservationValidator
  3. Executes database transaction
  4. Returns order with full preloaded data

  ## Cache Behavior

  - Caches ticket availability per event
  - Invalidates on broadcast from other workers
  - Falls back to database if cache is nil
  - Auto-expires after 1 hour of inactivity

  See `Tiki.Orders.PubSub` for event format documentation.
  """

  use GenServer, restart: :transient
  require Logger

  import Ecto.Query, warn: false
  alias Ecto.Multi

  alias Tiki.Repo
  alias Tiki.Tickets
  alias Tiki.Orders
  alias Tiki.OrderHandler
  alias Tiki.OrderHandler.ReservationValidator

  @timeout :timer.hours(1)

  # Public API

  def start_link(event_id) do
    GenServer.start_link(__MODULE__, event_id, name: via_tuple(event_id))
  end

  def reserve_tickets(event_id, ticket_types, user_id) do
    case ensure_started(event_id) do
      {:ok, _pid} ->
        GenServer.call(via_tuple(event_id), {:reserve_tickets, ticket_types, user_id})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_ticket_types(event_id) do
    case ensure_started(event_id) do
      {:ok, _pid} -> GenServer.call(via_tuple(event_id), :get_ticket_types)
      {:error, reason} -> {:error, reason}
    end
  end

  def invalidate_cache(event_id) do
    if started?(event_id) do
      GenServer.cast(via_tuple(event_id), :invalidate_cache)
    end
  end

  @impl GenServer
  def init(event_id) do
    Logger.debug("Order handler starting for event #{event_id}")

    # Subscribe to inventory changes (from other operations on this event)
    Tiki.Orders.PubSub.subscribe_to_event(event_id)

    ticket_types = Tickets.get_available_ticket_types(event_id)

    {:ok, %{event_id: event_id, ticket_types: ticket_types}, @timeout}
  end

  @impl GenServer
  def handle_info(:timeout, %{event_id: event_id} = state) do
    Logger.debug("Order handler idle for #{@timeout}ms for event #{event_id}, stopping")
    {:stop, :normal, state}
  end

  # Handle ticket inventory updates (from other workers or PubSub)
  def handle_info(%Tiki.Orders.Events.TicketsUpdated{} = event, state) do
    {:noreply, %{state | ticket_types: event.ticket_types}, @timeout}
  end

  @impl GenServer
  def handle_cast(:invalidate_cache, state) do
    {:noreply, %{state | ticket_types: nil}, @timeout}
  end

  @impl GenServer
  def handle_call(:get_ticket_types, _from, %{ticket_types: nil} = state) do
    # Here we have no cached data, so we find from the database
    ticket_types = Tickets.get_available_ticket_types(state.event_id)
    {:reply, ticket_types, %{state | ticket_types: ticket_types}, @timeout}
  end

  def handle_call(:get_ticket_types, _from, %{ticket_types: ticket_types} = state) do
    {:reply, ticket_types, state, @timeout}
  end

  def handle_call(
        {:reserve_tickets, requested_tickets, user_id},
        _from,
        %{event_id: event_id} = state
      ) do
    case reserve_tickets_transaction(event_id, requested_tickets, user_id) do
      {:ok, order, available_types, _} ->
        {:reply, {:ok, order, available_types}, state, @timeout}

      {:error, reason} ->
        {:reply, {:error, reason}, state, @timeout}
    end
  end

  # ============================================================================
  # Reservation Transaction
  # ============================================================================

  @doc false
  defp reserve_tickets_transaction(event_id, requested_tickets, user_id) do
    # Step 1: Validate all requirements upfront
    case ReservationValidator.validate_all(event_id, requested_tickets, user_id) do
      {:error, reason} ->
        {:error, reason}

      {:ok, %{ticket_types_map: tts, event: event, available_types: available}} ->
        # Step 2: Execute transaction (we know everything is valid)
        case execute_reservation_transaction(event_id, requested_tickets, tts) do
          {:ok, order} ->
            {:ok, Map.put(order, :event, event), available, event}

          {:error, reason} ->
            {:error, "failed to create order: #{inspect(reason)}"}
        end
    end
  end

  @doc false
  defp execute_reservation_transaction(event_id, requested_tickets, ticket_types_map) do
    result =
      Multi.new()
      |> Multi.insert(
        :order,
        create_order_changeset(event_id, requested_tickets, ticket_types_map),
        returning: [:id]
      )
      |> Multi.insert_all(
        :tickets,
        Orders.Ticket,
        fn %{order: order} ->
          create_tickets_batch(order.id, requested_tickets, ticket_types_map)
        end,
        returning: true
      )
      |> Multi.run(:audit, fn _repo, %{order: order} ->
        Orders.AuditLog.log(order.id, "order.created", order)
      end)
      # Check: verify inventory after inserts
      # Catches rare case where validator was stale, will probably never happen/be an issue
      |> Tickets.get_available_ticket_types_multi(event_id)
      |> Multi.run(:verify_inventory, fn _repo, %{ticket_types_available: available} ->
        case verify_no_overbooking(available, requested_tickets) do
          true ->
            {:ok, :verified}

          false ->
            # Transaction will rollback, no order created
            Logger.warning(
              "Inventory constraint check failed for event #{event_id} - " <>
                "validator may have been stale. Rolling back order."
            )

            {:error, "not enough tickets available (constraint check)"}
        end
      end)
      |> Multi.run(:preloaded_order, fn _repo,
                                        %{
                                          order: order,
                                          tickets: {_, bought_tickets},
                                          ticket_types_available: available
                                        } ->
        preload_order_with_tickets(order, bought_tickets, available)
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{preloaded_order: order}} ->
        {:ok, order}

      {:error, :verify_inventory, _reason, _} ->
        {:error, "not enough tickets available"}

      {:error, _step, reason, _} ->
        {:error, reason}
    end
  end

  defp verify_no_overbooking(available_types, requested_tickets) do
    Enum.all?(requested_tickets, fn {tt_id, count} ->
      available_for_type =
        Enum.find(available_types, fn a ->
          a.ticket_type.id == tt_id
        end)

      # Must have at least count available (non-negative)
      available_for_type && available_for_type.available >= count
    end)
  end

  defp create_order_changeset(event_id, requested_tickets, ticket_types_map) do
    total_price =
      Enum.reduce(requested_tickets, 0, fn {tt_id, count}, acc ->
        ticket_types_map[tt_id].price * count + acc
      end)

    Orders.Order.changeset(%Orders.Order{}, %{
      event_id: event_id,
      status: :pending,
      price: total_price
    })
  end

  defp create_tickets_batch(order_id, requested_tickets, ticket_types_map) do
    Enum.flat_map(requested_tickets, fn {tt_id, count} ->
      price = ticket_types_map[tt_id].price

      for _ <- 1..count do
        %{
          ticket_type_id: tt_id,
          order_id: order_id,
          price: price
        }
      end
    end)
  end

  defp preload_order_with_tickets(order, bought_tickets, available) do
    ticket_types =
      Enum.map(available, & &1.ticket_type)
      |> Enum.reduce(%{}, &Map.put(&2, &1.id, &1))

    tickets =
      Enum.map(bought_tickets, &Map.put(&1, :ticket_type, ticket_types[&1.ticket_type_id]))

    {:ok, Map.put(order, :tickets, tickets)}
  end

  defp ensure_started(event_id) do
    if started?(event_id) do
      {:ok, :already_started}
    else
      OrderHandler.DynamicSupervisor.start_worker(event_id)
    end
  end

  defp started?(event_id) do
    case Registry.lookup(Tiki.OrderHandler.Registry, event_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  defp via_tuple(event_id) do
    {:via, Registry, {OrderHandler.Registry, event_id}}
  end
end
