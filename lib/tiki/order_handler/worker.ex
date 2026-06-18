defmodule Tiki.OrderHandler.Worker do
  @moduledoc false

  use GenServer, restart: :transient
  require Logger

  import Ecto.Query, warn: false
  alias Tiki.Releases

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

  def handle_call({:reserve_tickets, requested, user_id}, _from, %{event_id: event_id} = state) do
    result =
      Repo.transact(fn ->
        with {:ok, _} <- acquire_reservation_lock(event_id),
             {:ok, _} <- validate_positive_ticket_count(requested),
             {:ok, ticket_types} <- fetch_ticket_types(requested),
             {:ok, event} <- fetch_event(event_id),
             {:ok, _} <- validate_all_purchasable(ticket_types),
             {:ok, _} <- validate_release_access(ticket_types, user_id),
             {:ok, _} <- validate_ticket_limits(ticket_types, requested, event),
             {:ok, total_price} <- calculate_total_price(ticket_types, requested),
             {:ok, order} <- insert_order(event_id, total_price),
             {:ok, tickets} <- insert_tickets(order, ticket_types, requested),
             available <- Tickets.get_available_ticket_types(event_id),
             {:ok, _} <- validate_availability(requested, available),
             {:ok, _} <- log_order_created(order, tickets, available) do
          {:ok, {order, tickets, available, event}}
        end
      end)

    case result do
      {:ok, {order, tickets, available, event}} ->
        ticket_type_map = Map.new(available, &{&1.id, &1})

        tickets =
          Enum.map(tickets, &Map.put(&1, :ticket_type, ticket_type_map[&1.ticket_type_id]))

        order = order |> Map.put(:tickets, tickets) |> Map.put(:event, event)
        {:reply, {:ok, order, available}, state, @timeout}

      {:error, reason} ->
        {:reply, {:error, reason}, state, @timeout}
    end
  end

  # Serialize all reservations for this event. Since _only_ reservations increase
  # the active ticket count (cancels and payments only maintain/decrease it), this lock
  # guarantees capacity invariant (pending + paid <= capacity) holds for all ticket
  # types of the event.
  defp acquire_reservation_lock(event_id) do
    <<lock_key::signed-64, _::binary>> =
      :crypto.hash(:md5, "event_reservation_lock:#{event_id}")

    case Ecto.Adapters.SQL.query(Repo, "SELECT pg_advisory_xact_lock($1)", [lock_key]) do
      {:ok, _} -> {:ok, :locked}
      error -> error
    end
  end

  defp validate_positive_ticket_count(ticket_types) do
    case Map.values(ticket_types) |> Enum.sum() do
      0 -> {:error, "order must contain at least one ticket"}
      _ -> {:ok, :ok}
    end
  end

  defp fetch_ticket_types(ticket_types) do
    tt_ids = Map.keys(ticket_types)

    tts =
      Repo.all(
        from tt in Tickets.TicketType,
          where: tt.id in ^tt_ids,
          select: {tt.id, tt}
      )
      |> Map.new()

    {:ok, tts}
  end

  defp fetch_event(event_id) do
    case Repo.one(from e in Events.Event, where: e.id == ^event_id) do
      nil -> {:error, "event not found"}
      event -> {:ok, event}
    end
  end

  defp validate_all_purchasable(tts) do
    if Enum.all?(tts, &purchaseable?/1) do
      {:ok, :ok}
    else
      {:error, "not all ticket types are purchasable"}
    end
  end

  defp validate_release_access(requested_ticket_types, user_id) do
    releases_query =
      from(r in Releases.Release,
        join: tb in assoc(r, :ticket_batch),
        join: tt in assoc(tb, :ticket_types),
        where: tt.id in ^Map.keys(requested_ticket_types)
      )

    releases_query =
      if user_id do
        join(releases_query, :left, [r, ...], rs in Releases.Signup,
          on: rs.release_id == r.id and rs.user_id == ^user_id
        )
        |> preload([..., rs], signups: rs)
      else
        join(releases_query, :left, [r, ...], rs in Releases.Signup,
          on: rs.release_id == r.id and is_nil(rs.user_id)
        )
        |> preload([..., rs], signups: rs)
      end

    all_valid =
      Repo.all(releases_query)
      |> Enum.filter(&Releases.is_active?/1)
      |> Enum.all?(fn release ->
        Enum.any?(release.release_signups, &(&1.status == :accepted))
      end)

    if all_valid do
      {:ok, :ok}
    else
      {:error, "tickets are part of an active release, which you are not accepted to"}
    end
  end

  defp validate_ticket_limits(requested_ticket_types, requested, event) do
    total_requested = Map.values(requested) |> Enum.sum()

    each_under_limit =
      Enum.all?(requested, fn {tt_id, count} ->
        requested_ticket_types[tt_id] && requested_ticket_types[tt_id].purchase_limit >= count
      end)

    if total_requested <= event.max_order_size && each_under_limit do
      {:ok, :ok}
    else
      {:error, "too many tickets requested"}
    end
  end

  defp calculate_total_price(requested_ticket_types, requested) do
    total =
      Enum.reduce(requested_ticket_types, 0, fn {tt_id, %{price: price}}, acc ->
        price * requested[tt_id] + acc
      end)

    {:ok, total}
  end

  defp insert_order(event_id, total_price) do
    %Orders.Order{}
    |> Orders.Order.changeset(%{event_id: event_id, status: :pending, price: total_price})
    |> Repo.insert(returning: [:id])
  end

  defp insert_tickets(order, requested_ticket_types, requested) do
    ticket_rows =
      Enum.flat_map(requested, fn {tt_id, count} ->
        for _ <- 1..count do
          %{ticket_type_id: tt_id, order_id: order.id, price: requested_ticket_types[tt_id].price}
        end
      end)

    case Repo.insert_all(Orders.Ticket, ticket_rows, returning: true) do
      {_, tickets} -> {:ok, tickets}
    end
  end

  defp validate_availability(requested, available) do
    valid_for_event? =
      Map.keys(requested)
      |> Enum.all?(fn tt -> Enum.any?(available, &(&1.id == tt)) end)

    chosen = Enum.filter(available, &Map.has_key?(requested, &1.id))

    if valid_for_event? && Enum.all?(chosen, &(&1.available >= 0)) do
      {:ok, :ok}
    else
      {:error, "not enough tickets available"}
    end
  end

  defp log_order_created(order, tickets, available) do
    ticket_type_map = Map.new(available, &{&1.id, &1})

    preloaded_tickets =
      Enum.map(tickets, &Map.put(&1, :ticket_type, ticket_type_map[&1.ticket_type_id]))

    preloaded_order = Map.put(order, :tickets, preloaded_tickets)
    Orders.AuditLog.log(order.id, "order.created", preloaded_order)
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
      case OrderHandler.DynamicSupervisor.start_worker(event_id) do
        {:ok, pid} -> {:ok, pid}
        # Another concurrent caller started the worker between our check - proceed
        {:error, {:already_started, _pid}} -> {:ok, :already_started}
        {:error, reason} -> {:error, reason}
      end
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
