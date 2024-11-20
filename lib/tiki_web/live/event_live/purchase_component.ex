defmodule TikiWeb.EventLive.PurchaseComponent do
  use TikiWeb, :live_component

  alias Tiki.Checkouts
  alias TikiWeb.EventLive.PurchaseMonitor
  alias Tiki.Orders

  def update(%{action: {:stripe_intent, intent}}, socket) do
    {:ok, assign(socket, intent: intent)}
  end

  def update(%{action: {:swish_token, token}}, socket) do
    {:ok, svg} = Tiki.Swish.get_svg_qr_code(token)
    {:ok, assign(socket, swish_qr_code: svg)}
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
       intent: nil,
       swish_qr_code: nil
     )
     |> assign(assigns)}
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

    {:noreply, socket |> push_patch(to: ~p"/events/#{socket.assigns.event.id}")}
  end

  def handle_event("submit", _params, socket) do
    to_purchase =
      Enum.map(socket.assigns.ticket_types, fn ticket_type ->
        Map.put(ticket_type, :count, socket.assigns.counts[ticket_type.id])
      end)
      |> Enum.filter(fn ticket -> ticket.count > 0 end)

    %{current_user: %{id: user_id}, event: %{id: event_id}} = socket.assigns

    price = Enum.reduce(to_purchase, 0, fn ticket, sum -> sum + ticket.count * ticket.price end)

    with {:ok, order} <- Orders.reserve_tickets(event_id, to_purchase, user_id) do
      PurchaseMonitor.monitor(self(), %{id: socket.assigns.id, order: order})
      # send(self(), {:create_stripe_payment_intent, order.id, user_id, price})
      send(self(), {:create_swish_payment_request, order.id, user_id, price})

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

  def handle_event("pay", _params, socket) do
    {:ok, _} = Orders.confirm_order(socket.assigns.order)

    {:noreply, assign(socket, state: :purchased)}
  end

  def handle_event("update_promo", %{"code" => code}, socket) do
    {:noreply, assign(socket, promo_code: code)}
  end

  def handle_event("activate_promo", %{"code" => code}, socket) do
    ticket_types = Orders.get_availible_ticket_types(socket.assigns.event.id)

    {:noreply, assign(socket, promo_code: "") |> assign_ticket_types(ticket_types, code)}
  end

  def handle_event("payment-sucess", %{"id" => id}, socket) do
    with {:ok, order} <- Checkouts.confirm_stripe_payment(id),
         {:ok, _} <- Orders.confirm_order(order) do
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
        <tr class="border-accent border-t-2">
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
