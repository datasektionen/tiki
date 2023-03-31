defmodule TikiWeb.EventLive.PurchaseComponent do
  use TikiWeb, :live_component

  alias Phoenix.PubSub
  alias Tiki.Orders
  alias Tiki.Events

  def update(%{action: {:timeout}}, socket) do
    case socket.assigns.state do
      :purchase -> {:ok, assign(socket, state: :timeout)}
      _ -> {:ok, socket}
    end
  end

  def update(%{action: {:tickets_updated, ticket_types}}, socket) do
    {:ok, assign(socket, ticket_types: ticket_types)}
  end

  def update(assigns, socket) do
    ticket_types = Orders.get_availible_ticket_types(assigns.event.id)

    counts =
      Enum.reduce(ticket_types, %{}, fn ticket_type, acc ->
        Map.put(acc, ticket_type.id, 0)
      end)

    Orders.subscribe(assigns.event.id)

    {:ok,
     socket
     |> assign(ticket_types: ticket_types, counts: counts, state: :tickets, error: nil)
     |> assign(assigns)}
  end

  def handle_event("inc", %{"id" => id}, socket) do
    counts = Map.update(socket.assigns.counts, id, 0, &(&1 + 1))

    {:noreply, assign(socket, counts: counts)}
  end

  def handle_event("dec", %{"id" => id}, socket) do
    counts = Map.update(socket.assigns.counts, id, 0, &(&1 - 1))

    {:noreply, assign(socket, counts: counts)}
  end

  def handle_event("cancel", _params, socket) do
    if socket.assigns.state == :purchase do
      Orders.maybe_cancel_reservation(socket.assigns.order)
    end

    {:noreply, socket |> push_patch(to: ~p"/events/#{socket.assigns.event.id}")}
  end

  def handle_event("submit", _params, socket) do
    to_purchase =
      Enum.map(socket.assigns.ticket_types, fn ticket_type ->
        Map.put(ticket_type, :count, socket.assigns.counts[ticket_type.id])
      end)
      |> Enum.filter(fn ticket -> ticket.count > 0 end)

    case Orders.reserve_tickets(
           socket.assigns.event.id,
           to_purchase,
           socket.assigns.current_user.id
         ) do
      {:ok, order} ->
        TikiWeb.EventLive.PurchaseMonitor.monitor(self(), __MODULE__, %{
          id: socket.assigns.id,
          order: order
        })

        price =
          Enum.reduce(to_purchase, 0, fn ticket, sum -> sum + ticket.count * ticket.price end)

        {:noreply,
         assign(socket,
           state: :purchase,
           order: order,
           to_purchase: to_purchase,
           total_price: price
         )}

      {:error, reason} ->
        {:noreply, assign(socket, error: reason)}
    end
  end

  def handle_event("pay", _params, socket) do
    {:ok, _} = Orders.confirm_order(socket.assigns.order)

    {:noreply, assign(socket, state: :purchased)}
  end

  def unmount({:shutdown, :closed}, %{order: order}) do
    Orders.maybe_cancel_reservation(order)
  end

  defp ticket_summary(assigns) do
    ~H"""
    <table class="w-full border-collapse border-spacing-0 ">
      <tbody class="text-sm">
        <tr :for={ticket <- @tickets} class=" border-t">
          <th class="text-left pr-2 py-1"><%= ticket.name %></th>
          <td class="text-right whitespace-nowrap pr-2 py-1">
            <%= "#{ticket.count} x #{ticket.price} kr" %>
          </td>
          <td class="text-right whitespace-nowrap py-1"><%= ticket.price * ticket.count %> kr</td>
        </tr>
        <tr class="border-t-2 border-gray-300">
          <th></th>
          <td class="text-right whitespace-nowrap pr-2 py-1">TOTALT</td>
          <td class="text-right whitespace-nowrap py-1">
            <%= @total_price %> kr
          </td>
        </tr>
      </tbody>
    </table>
    """
  end
end

defmodule TikiWeb.EventLive.PurchaseMonitor do
  use GenServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def monitor(pid, view_module, meta) do
    GenServer.call(__MODULE__, {:monitor, pid, view_module, meta})
  end

  def init(_) do
    {:ok, %{views: %{}}}
  end

  def handle_call({:monitor, pid, view_module, meta}, _, %{views: views} = state) do
    Process.monitor(pid)
    Process.send_after(self(), {:timeout, pid}, 30_000)
    {:reply, :ok, %{state | views: Map.put(views, pid, {view_module, meta})}}
  end

  def handle_info({:timeout, view_pid}, state) do
    case Map.pop(state.views, view_pid) do
      {{module, meta}, new_views} ->
        send(view_pid, {:timeout, %{id: meta.id}})
        module.unmount({:shutdown, :closed}, meta)
        {:noreply, %{state | views: new_views}}

      {nil, _} ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, view_pid, reason}, state) do
    {{module, meta}, new_views} = Map.pop(state.views, view_pid)
    module.unmount(reason, meta)
    {:noreply, %{state | views: new_views}}
  end
end
