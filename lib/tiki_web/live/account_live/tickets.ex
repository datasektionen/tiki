defmodule TikiWeb.AccountLive.Tickets do
  use TikiWeb, :live_view

  alias Tiki.Orders
  import TikiWeb.Component.Card

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.header>
      {gettext("Your tickets")}
    </.header>
    <div :if={@orders == []} class="mt-4">
      <.card class="grid grid-cols-1 overflow-hidden md:grid-cols-2 lg:grid-cols-3">
        <div class="flex flex-col justify-end gap-4 p-8">
          <.icon name="hero-rocket-launch" class="text-muted-foreground size-6" />
          <h3 class="text-foreground mt-2 text-lg font-semibold">
            {gettext("No tickets ordered yet")}
            <p class="mt-1 text-sm font-normal">
              {gettext("The time is ripe to go to some fun and exciting events!")}
            </p>
          </h3>

          <.button navigate={~p"/events"}>
            <span>{gettext("Start browsing events")}</span>
          </.button>
        </div>

        <img
          src="/images/kamera.jpg"
          alt=""
          class="hidden h-64 w-full object-cover md:block lg:col-span-2"
        />
      </.card>
    </div>

    <div :if={@orders != []} class="mt-4 grid gap-x-4 gap-y-6 sm:grid-cols-2 lg:grid-cols-3">
      <%= for order <- @orders do %>
        <.link
          :for={ticket <- order.tickets}
          navigate={~p"/tickets/#{ticket}"}
          class="flex flex-row items-center gap-3"
        >
          <img
            src={image_url(order.event.image_url, width: 200, height: 200)}
            alt={order.event.name}
            class="h-16 w-16 rounded-lg object-cover"
          />
          <%!-- <.svg_qr data={ticket.id} class="size-18 rounded-lg object-cover" /> --%>
          <div class="flex flex-col gap-1">
            <span class="font-medium">{order.event.name}</span>
            <span class="text-muted-foreground text-sm">
              {ticket.ticket_type.name}
            </span>
            <span class="text-muted-foreground text-sm">
              {time_to_string(order.event.event_date)}
            </span>
          </div>
        </.link>
      <% end %>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    orders = Orders.list_orders_for_user(socket.assigns.current_user.id, status: [:paid])

    {:ok, assign(socket, orders: orders)}
  end
end
