defmodule TikiWeb.EventLive.PurchaseComponent do
  use TikiWeb, :live_component

  alias Tiki.Orders
  alias Tiki.Tickets
  alias Tiki.Events

  def update(assigns, socket) do
    ticket_types = Events.get_ticket_types(assigns.event.id) |> Enum.map(&Map.put(&1, :count, 0))

    {:ok, socket |> assign(ticket_types: ticket_types, state: :tickets) |> assign(assigns)}
  end

  def handle_event("inc", %{"id" => id}, socket) do
    ticket_types =
      Enum.map(socket.assigns.ticket_types, fn ticket_type ->
        if ticket_type.id == id do
          Map.put(ticket_type, :count, ticket_type.count + 1)
        else
          ticket_type
        end
      end)

    {:noreply, socket |> assign(ticket_types: ticket_types)}
  end

  def handle_event("dec", %{"id" => id}, socket) do
    ticket_types =
      Enum.map(socket.assigns.ticket_types, fn ticket_type ->
        if ticket_type.id == id do
          Map.put(ticket_type, :count, ticket_type.count - 1)
        else
          ticket_type
        end
      end)

    {:noreply, socket |> assign(ticket_types: ticket_types)}
  end

  def handle_event("submit", _params, socket) do
    to_purchase = Enum.filter(socket.assigns.ticket_types, &(&1.count > 0))

    price = Enum.reduce(to_purchase, 0, fn ticket, sum -> sum + ticket.count * ticket.price end)

    {:noreply, assign(socket, state: :purchase, to_purchase: to_purchase, total_price: price)}
  end

  def handle_event("pay", _params, socket) do
    flattned =
      Enum.flat_map(socket.assigns.to_purchase, fn ticket_type ->
        Enum.map(1..ticket_type.count, fn _ -> ticket_type end)
      end)

    {:ok, _} = Orders.purchase_tickets(flattned, socket.assigns.current_user)

    {:noreply, assign(socket, state: :purchased)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div :if={@state == :purchased}>
        <.header>
          Färdigt
          <:subtitle>Ditt köp är färdigt, du kan se ditt kvitto nedan.</:subtitle>
        </.header>

        <div class="pt-4">
          <.ticket_summary tickets={@to_purchase} total_price={@total_price} />
        </div>
      </div>
      <div :if={@state == :purchase}>
        <.header>
          Betalning
          <:subtitle>Du har 7 minuter på dig att genomföra ditt köp.</:subtitle>
        </.header>

        <div class="pt-4">
          <.ticket_summary tickets={@to_purchase} total_price={@total_price} />
        </div>

        <div>
          Typ betalning ie stripe här!
        </div>

        <div class="flex flex-row justify-end">
          <.button phx-click="pay" phx-target={@myself}>
            Betala <%= @total_price %> kr
          </.button>
        </div>
      </div>
      <div :if={@state == :tickets}>
        <.header>
          <%= @title %>
          <:subtitle>Köp biljetter till eventet här.</:subtitle>
        </.header>

        <div class="flex flex-col gap-3 pt-4">
          <div
            :for={ticket_type <- @ticket_types}
            class="flex flex-row justify-between py-4 px-4 bg-gray-100 rounded-xl"
          >
            <div class="flex flex-col">
              <h3 class="font-bold text-xl pb-1"><%= ticket_type.name %></h3>
              <div class="text-gray-600"><%= ticket_type.price %> kr</div>
            </div>

            <div class="flex flex-row items-center gap-2">
              <div
                class="bg-white rounded-full w-8 h-8 text-2xl shadow-md flex justify-center items-center hover:bg-gray-100 hover:cursor-pointer"
                phx-click={JS.push("dec", value: %{id: ticket_type.id})}
                phx-target={@myself}
              >
                <.icon name="hero-minus-mini" />
              </div>

              <div class="bg-gray-200 h-10 w-8 rounded-lg flex justify-center items-center">
                <%= ticket_type.count %>
              </div>

              <div
                class="bg-white rounded-full w-8 h-8 text-2xl shadow-md flex justify-center items-center hover:bg-gray-100 hover:cursor-pointer"
                phx-click={JS.push("inc", value: %{id: ticket_type.id})}
                phx-target={@myself}
              >
                <.icon name="hero-plus-mini" />
              </div>
            </div>
          </div>
        </div>

        <div class="flex flex-row justify-end pt-4">
          <.button phx-click="submit" phx-target={@myself}>
            <span>Fortsätt</span>
          </.button>
        </div>
      </div>
    </div>
    """
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
