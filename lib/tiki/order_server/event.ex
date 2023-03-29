defmodule Tiki.OrderServer.Event do
  defstruct event: %Tiki.Events.Event{}, ticket_types: %{}, reservations: %{}

  use GenServer, restart: :transient
  require Logger

  alias Ecto.UUID
  alias Tiki.OrderServer.Event

  @registry :event_registry
  @subscriber_registry :event_subscriber_registry

  def start_link(event_id) do
    GenServer.start_link(__MODULE__, event_id, name: {:via, Registry, {@registry, event_id}})
  end

  def buy_tickets(event_id, reservation_uuid) do
    GenServer.call(via_pid(event_id), {:buy_tickets, reservation_uuid})
  end

  def reserve_tickets(event_id, ticket_types, user_id) do
    GenServer.call(via_pid(event_id), {:reserve_tickets, ticket_types, user_id})
  end

  def increment_tickets(event_id) do
    GenServer.cast(via_pid(event_id), :increment_tickets)
  end

  ## GenServer Callbacks

  @impl true
  def init(event_id) do
    Logger.debug("Starting Event process for #{event_id}")

    event = Tiki.Events.get_event!(event_id)

    ticket_types =
      Tiki.Orders.get_purchased_ticket_types(event_id)
      |> Enum.reduce(%{}, fn ticket_type, acc ->
        Map.put(acc, ticket_type.id, %{
          ticket_type: ticket_type,
          purchased: ticket_type.purchased,
          reserved: 0
        })
      end)

    {:ok, %Event{ticket_types: ticket_types, event: event}}
  end

  @impl true
  def handle_call({:reserve_tickets, ticket_types, user_id}, _from, state) do
    ticket_types =
      Enum.reduce(ticket_types, state.ticket_types, fn tt, acc ->
        Map.update!(acc, tt.id, fn %{reserved: reserved} = ticket_type ->
          %{ticket_type | reserved: reserved - 1}
        end)
      end)

    reservation = %{user_id: user_id, ticket_types: ticket_types}
    reservation_id = UUID.generate()
    reservations = Map.put(state.reservations, reservation_id, reservation)

    Registry.dispatch(@subscriber_registry, "event:#{state.event.id}", fn entries ->
      for {pid, _} <- entries, do: send(pid, {:updated_tickets, ticket_types})
    end)

    {:reply, {:ok, reservation_id},
     %Event{ticket_types: ticket_types, reservations: reservations}}
  end

  @impl true
  def handle_call({:buy_tickets, reservation_uuid}, _from, state) do
    reservation = Map.get(state.reservations, reservation_uuid)

    {:ok, result} = Tiki.Orders.purchase_tickets(reservation.ticket_types, reservation.user_id)

    ticket_types =
      Enum.reduce(reservation.ticket_types, state.ticket_types, fn tt, acc ->
        Map.update!(acc, tt.id, fn %{purchased: purchased, reserved: reserved} = ticket_type ->
          %{ticket_type | purchased: purchased + 1, reserved: reserved - 1}
        end)
      end)

    Registry.dispatch(@subscriber_registry, "event:#{state.event.id}", fn entries ->
      for {pid, _} <- entries, do: send(pid, {:updated_tickets, ticket_types})
    end)

    {:reply, {:ok, result}, %Event{state | ticket_types: ticket_types}}
  end

  defp via_pid(event_id), do: {:via, Registry, {@registry, event_id}}
end
