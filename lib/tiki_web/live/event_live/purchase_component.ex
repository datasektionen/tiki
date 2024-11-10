defmodule TikiWeb.EventLive.PurchaseComponent do
  use TikiWeb, :live_component

  alias Tiki.Checkouts
  alias TikiWeb.EventLive.PurchaseMonitor
  alias Tiki.Orders
  alias Tiki.Accounts
  alias Tiki.Accounts.User

  def update(%{action: {:stripe_intent, intent}}, socket) do
    {:ok, assign(socket, intent: intent)}
  end

  def update(%{action: {:timeout, _}}, socket) do
    case socket.assigns.state do
      :purchase ->
        {:ok, assign(socket, state: :timeout)}

      _ ->
        {:ok, socket}
    end
  end

  def update(%{action: {:tickets_updated, ticket_types}}, socket) do
    {:ok, assign_ticket_types(socket, ticket_types)}
  end

  def update(assigns, socket) do
    ticket_types =
      if connected?(socket) do
        Orders.subscribe(assigns.event.id)
        Orders.get_availible_ticket_types(assigns.event.id)
      else
        []
      end

    {:ok,
     socket
     |> assign(
       state: :tickets,
       promo_code: "",
       error: nil,
       order: nil,
       intent: nil
     )
     |> assign(assigns)
     |> assign_ticket_types(ticket_types)}
  end

  defp assign_ticket_types(socket, ticket_types, promo_code \\ "") do
    ticket_types =
      Enum.filter(ticket_types, fn ticket_type ->
        ticket_type.promo_code == nil || ticket_type.promo_code == promo_code
      end)

    counts =
      Enum.reduce(ticket_types, %{}, fn ticket_type, acc ->
        prev_count =
          case Map.get(socket.assigns, :counts, %{}) do
            counts when is_map(counts) ->
              Map.get(counts, ticket_type.id, 0)

            _ ->
              0
          end

        Map.put(acc, ticket_type.id, prev_count)
      end)

    assign(socket, ticket_types: ticket_types, counts: counts)
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

    case socket.assigns do
      %{patch: url} when not is_nil(url) -> {:noreply, push_patch(socket, to: url)}
      %{navigate: url} when not is_nil(url) -> {:noreply, push_navigate(socket, to: url)}
      _ -> {:noreply, assign(socket, state: :cancelled)}
    end
  end

  def handle_event("submit", _params, socket) do
    to_purchase =
      Enum.map(socket.assigns.ticket_types, fn ticket_type ->
        Map.put(ticket_type, :count, socket.assigns.counts[ticket_type.id])
      end)
      |> Enum.filter(fn ticket -> ticket.count > 0 end)

    %{event: %{id: event_id}} = socket.assigns

    user_id =
      case socket.assigns do
        %{current_user: %User{id: user_id}} -> user_id
        _ -> nil
      end

    price = Enum.reduce(to_purchase, 0, fn ticket, sum -> sum + ticket.count * ticket.price end)

    with {:ok, order} <- Orders.reserve_tickets(event_id, to_purchase, user_id) do
      PurchaseMonitor.monitor(self(), %{id: socket.assigns.id, order: order})
      send(self(), {:create_stripe_payment_intent, order.id, user_id, price})

      {:noreply,
       assign(socket,
         state: :purchase,
         order: order,
         to_purchase: to_purchase,
         total_price: price
       )}
    else
      {:error, reason} ->
        {:noreply, assign(socket, error: reason)}
    end
  end

  def handle_event("update_promo", %{"code" => code}, socket) do
    {:noreply, assign(socket, promo_code: code)}
  end

  def handle_event("activate_promo", %{"code" => code}, socket) do
    ticket_types = Orders.get_availible_ticket_types(socket.assigns.event.id)

    {:noreply, assign(socket, promo_code: "") |> assign_ticket_types(ticket_types, code)}
  end

  def handle_event(
        "payment-sucess",
        %{"id" => id},
        %{assigns: %{current_user: %User{id: user_id}}} = socket
      ) do
    with {:ok, order, _} <- Checkouts.confirm_stripe_payment(id),
         {:ok, _} <- Orders.confirm_order(order, user_id) do
      {:noreply, assign(socket, state: :purchased)}
    else
      _ ->
        # TODO: Handle error
        {:noreply, socket}
    end
  end

  def handle_event("payment-sucess", %{"id" => id}, socket) do
    # The user is not logged in, so we need to create a new user and assign the order to that user
    with {:ok, order, email} <- Checkouts.confirm_stripe_payment(id),
         {:ok, user} <- Accounts.upsert_user_email(email),
         {:ok, _} <- Orders.confirm_order(order, user.id) do
      {:noreply, assign(socket, state: :purchased)}
    else
      _ ->
        # TODO: Handle error
        {:noreply, socket}
    end
  end

  defp ticket_summary(assigns) do
    ~H"""
    <table class="w-full border-collapse border-spacing-0">
      <tbody class="text-sm">
        <tr :for={ticket <- @tickets} class="border-t">
          <th class="py-1 pr-2 text-left"><%= ticket.name %></th>
          <td class="whitespace-nowrap py-1 pr-2 text-right">
            <%= "#{ticket.count} x #{ticket.price} kr" %>
          </td>
          <td class="whitespace-nowrap py-1 text-right"><%= ticket.price * ticket.count %> kr</td>
        </tr>
        <tr class="border-t-2 border-gray-300">
          <th></th>
          <td class="whitespace-nowrap py-1 pr-2 text-right">TOTALT</td>
          <td class="whitespace-nowrap py-1 text-right">
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

  alias Tiki.Orders

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def monitor(pid, meta) do
    GenServer.call(__MODULE__, {:monitor, pid, meta})
  end

  def init(_) do
    {:ok, %{views: %{}}}
  end

  def handle_call({:monitor, pid, meta}, _, %{views: views} = state) do
    Process.monitor(pid)
    Process.send_after(self(), {:timeout, pid, meta}, 60_000)
    {:reply, :ok, %{state | views: Map.put(views, pid, meta)}}
  end

  def handle_info({:timeout, view_pid, meta}, state) do
    case maybe_cancel_reservation(meta) do
      :cancelled -> send(view_pid, {:timeout, meta})
      :not_cancelled -> nil
    end

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, view_pid, _reason}, state) do
    {meta, new_views} = Map.pop(state.views, view_pid)
    maybe_cancel_reservation(meta)
    {:noreply, %{state | views: new_views}}
  end

  defp maybe_cancel_reservation(%{order: order}) do
    case Orders.maybe_cancel_reservation(order) do
      {:ok, _} -> :cancelled
      {:error, _} -> :not_cancelled
    end
  end
end
