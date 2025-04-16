defmodule Tiki.OrderHandler.Worker do
  @moduledoc false

  use GenServer, restart: :transient
  require Logger

  import Ecto.Query, only: [from: 2]
  alias ElixirLS.LanguageServer.Providers.Completion.Reducers.Struct
  alias Stripe.Climate.Order
  alias Ecto.Multi

  alias Tiki.Repo
  alias Tiki.Tickets
  alias Tiki.Orders
  alias Tiki.Events
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

  def invalidate_cache(event_id) do
    if started?(event_id) do
      GenServer.cast(via_tuple(event_id), :invalidate_cache)
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
  def handle_cast(:invalidate_cache, state) do
    {:noreply, %{state | ticket_types: nil}, @timeout}
  end

  @impl GenServer
  def handle_call(:get_ticket_types, _from, %{ticket_types: nil} = state) do
    ticket_types = Tickets.get_available_ticket_types(state.event_id)
    {:reply, ticket_types, %{state | ticket_types: ticket_types}, @timeout}
  end

  def handle_call(:get_ticket_types, _from, %{ticket_types: ticket_types} = state) do
    {:reply, ticket_types, state, @timeout}
  end

  def handle_call({:reserve_tickets, ticket_types}, _from, %{event_id: event_id} = state) do
    result =
      Multi.new()
      |> Multi.run(:requested_types, fn repo, _ ->
        tt_ids = Enum.map(ticket_types, fn {tt, _} -> tt end)

        tts =
          repo.all(
            from tt in Tickets.TicketType,
              where: tt.id in ^tt_ids,
              select: {tt.id, tt}
          )
          |> Enum.into(%{})

        {:ok, tts}
      end)
      |> Multi.run(:positive_tickets, fn _repo, _ ->
        case Map.values(ticket_types) |> Enum.sum() do
          0 -> {:error, "order must contain at least one ticket"}
          _ -> {:ok, :ok}
        end
      end)
      |> Multi.run(:event, fn repo, _ ->
        {:ok, repo.one(from e in Events.Event, where: e.id == ^event_id)}
      end)
      |> Multi.run(:all_purchasable, fn _repo, %{requested_types: tts} ->
        case Enum.all?(tts, &purchaseable?/1) do
          true -> {:ok, :ok}
          false -> {:error, "not all ticket types are purchasable"}
        end
      end)
      |> Multi.run(:ticket_limits, fn _repo, %{requested_types: tts, event: event} ->
        total_requested = Map.values(ticket_types) |> Enum.sum()

        each_under_limit =
          Enum.all?(ticket_types, fn {tt_id, count} ->
            tts[tt_id] && tts[tt_id].purchase_limit >= count
          end)

        if total_requested <= event.max_order_size && each_under_limit do
          {:ok, :ok}
        else
          {:error, "too many tickets requested"}
        end
      end)
      |> Multi.run(:total_price, fn _repo, %{requested_types: tts} ->
        total =
          Enum.reduce(tts, 0, fn {tt_id, %{price: price}}, acc ->
            price * ticket_types[tt_id] + acc
          end)

        {:ok, total}
      end)
      |> Multi.insert(
        :order,
        fn %{total_price: total_price} ->
          Orders.Order.changeset(%Orders.Order{}, %{
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
        fn %{order: order, requested_types: tts} ->
          Enum.flat_map(ticket_types, fn {tt, count} ->
            for _ <- 1..count do
              %{ticket_type_id: tt, order_id: order.id, price: tts[tt].price}
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
      |> Multi.run(:audit, fn _repo, %{preloaded_order: order} ->
        Orders.AuditLog.log(order.id, "order.created", order)
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{preloaded_order: order, ticket_types_available: ticket_types}} ->
        {:reply, {:ok, order, ticket_types}, state, @timeout}

      {:error, status, message, _}
      when status in [:positive_tickets, :ticket_limits, :check_availability, :all_purchasable] ->
        {:reply, {:error, message}, state, @timeout}
    end
  end

  defp purchaseable?({_, tt}) do
    now = DateTime.utc_now()

    cond do
      !tt.purchasable -> false
      tt.expire_time && DateTime.compare(now, tt.expire_time) == :gt -> false
      tt.release_time && DateTime.compare(now, tt.release_time) == :lt -> false
      true -> true
    end
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
