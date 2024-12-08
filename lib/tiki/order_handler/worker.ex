defmodule Tiki.OrderHandler.Worker do
  @moduledoc false

  use GenServer, restart: :transient
  require Logger

  import Ecto.Query, only: [from: 2]
  alias Ecto.Multi

  alias Tiki.Repo
  alias Tiki.Tickets
  alias Tiki.Orders
  alias Tiki.OrderHandler

  @timeout :timer.hours(1)

  # Public API

  def start_link(event_id) do
    GenServer.start_link(__MODULE__, event_id, name: via_tuple(event_id))
  end

  def reserve_tickets(event_id, ticket_types) do
    case ensure_started(event_id) do
      {:ok, _pid} -> GenServer.call(via_tuple(event_id), {:reserve_tickets, ticket_types})
      {:error, reason} -> {:error, reason}
    end
  end

  def get_ticket_types(event_id) do
    case ensure_started(event_id) do
      {:ok, _pid} -> GenServer.call(via_tuple(event_id), :get_ticket_types)
      {:error, reason} -> {:error, reason}
    end
  end

  @impl GenServer
  def init(event_id) do
    Logger.debug("Order handler starting for event #{event_id}")

    Orders.subscribe(event_id)
    ticket_types = Tickets.get_available_ticket_types(event_id)
    {:ok, %{event_id: event_id, ticket_types: ticket_types}, @timeout}
  end

  @impl GenServer
  def handle_info(:timeout, %{event_id: event_id} = state) do
    Logger.debug("Order handler idle for #{@timeout}ms for event #{event_id}, stopping")

    {:stop, :normal, state}
  end

  def handle_info({:tickets_updated, ticket_types}, state) do
    {:noreply, %{state | ticket_types: ticket_types}, @timeout}
  end

  @impl GenServer
  def handle_call(:get_ticket_types, _from, %{ticket_types: ticket_types} = state) do
    {:reply, ticket_types, state, @timeout}
  end

  def handle_call({:reserve_tickets, ticket_types}, _from, %{event_id: event_id} = state) do
    result =
      Multi.new()
      |> Multi.run(:positive_tickets, fn _repo, _ ->
        case Map.values(ticket_types) |> Enum.sum() do
          0 -> {:error, "order must contain at least one ticket"}
          _ -> {:ok, :ok}
        end
      end)
      |> Multi.run(:prices, fn repo, _ ->
        tt_ids = Enum.map(ticket_types, fn {tt, _} -> tt end)

        prices =
          repo.all(
            from tt in Tickets.TicketType,
              where: tt.id in ^tt_ids,
              select: {tt.id, tt.price}
          )
          |> Enum.into(%{})

        total = Enum.reduce(prices, 0, fn {tt, price}, acc -> price * ticket_types[tt] + acc end)

        {:ok, Map.put(prices, :total, total)}
      end)
      |> Multi.insert(
        :order,
        fn %{prices: %{total: total_price}} ->
          Orders.change_order(%Orders.Order{}, %{
            event_id: event_id,
            status: :pending,
            price: total_price
          })
        end,
        returning: [:id]
      )
      |> Multi.insert_all(
        :tickets,
        Orders.Ticket,
        fn %{order: order, prices: prices} ->
          Enum.flat_map(ticket_types, fn {tt, count} ->
            for _ <- 1..count do
              %{ticket_type_id: tt, order_id: order.id, price: prices[tt]}
            end
          end)
        end,
        returning: true
      )
      |> Tickets.get_available_ticket_types_multi(event_id)
      |> Multi.run(:check_availability, fn _repo, %{ticket_types_available: available} ->
        valid_for_event? =
          Map.keys(ticket_types)
          |> Enum.all?(fn tt -> Enum.any?(available, &(&1.ticket_type.id == tt)) end)

        chosen =
          Enum.filter(available, fn tt -> Map.has_key?(ticket_types, tt.ticket_type.id) end)

        with true <- valid_for_event?,
             true <- Enum.all?(chosen, &(&1.available >= 0)) do
          {:ok, :ok}
        else
          _ -> {:error, "not enough tickets available"}
        end
      end)
      |> Multi.run(
        :preloaded_order,
        fn _repo, %{order: order, tickets: {_, tickets}, ticket_types_available: available} ->
          ticket_types =
            Enum.map(available, & &1.ticket_type)
            |> Enum.reduce(%{}, &Map.put(&2, &1.id, &1))

          tickets = Enum.map(tickets, &Map.put(&1, :ticket_type, ticket_types[&1.ticket_type_id]))
          {:ok, Map.put(order, :tickets, tickets)}
        end
      )
      |> Repo.transaction()

    case result do
      {:ok, %{preloaded_order: order, ticket_types_available: ticket_types}} ->
        {:reply, {:ok, order, ticket_types}, state, @timeout}

      {:error, status, message, _} when status in [:positive_tickets, :check_availability] ->
        {:reply, {:error, message}, state, @timeout}
    end
  end

  defp ensure_started(event_id) do
    case Registry.lookup(Tiki.OrderHandler.Registry, event_id) do
      [] -> OrderHandler.DynamicSupervisor.start_worker(event_id)
      [{_pid, _}] -> {:ok, :already_started}
    end
  end

  defp via_tuple(event_id) do
    {:via, Registry, {OrderHandler.Registry, event_id}}
  end
end
