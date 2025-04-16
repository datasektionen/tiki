defmodule TikiWeb.AdminLive.Orders.Show do
  use TikiWeb, :live_view

  alias Tiki.Orders
  import TikiWeb.Component.Card
  import TikiWeb.Component.Badge

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-8">
      <.information_card name={gettext("Order")} description={gettext("Information about order.")}>
        <:item name={gettext("Order number")}>{@order.id}</:item>
        <:item name={gettext("Status")}>{@order.status}</:item>
        <:item name={gettext("Name")}>{@order.user.full_name}</:item>
        <:item name={gettext("Email")}>{@order.user.email}</:item>
        <:item name={gettext("Price")}>{"#{@order.price} SEK"}</:item>
        <:item name={gettext("Tickets")}>
          <span :for={tt <- @order.tickets} class="text-foreground">
            <.link navigate={~p"/admin/events/#{@event.id}/attendees/#{tt.id}"}>
              <.badge variant="outline">
                <.icon name="hero-ticket-mini" class="mr-1 inline-block h-2 w-2" />
                {tt.ticket_type.name}
              </.badge>
            </.link>
          </span>
        </:item>
      </.information_card>

      <.information_card
        :if={@order.stripe_checkout}
        name={gettext("Payment")}
        description={gettext("Information about payment.")}
      >
        <:item name={gettext("Payment type")}>Stripe</:item>
        <:item name={gettext("Payment status")}>{@order.stripe_checkout.status}</:item>
        <:item name={gettext("Stripe payment reference")}>
          {@order.stripe_checkout.payment_intent_id}
        </:item>
        <:item name={gettext("Card details")}>
          <.async_result :let={payment_method} assign={@payment_method}>
            <:loading>
              <span class="text-foreground text-sm">{gettext("Loading...")}</span>
            </:loading>
            <:failed :let={_failure}>
              {gettext("There was an error loading the payment method")}
            </:failed>

            <div class="flex flex-row items-center gap-x-1">
              <.payment_method_logo name={"paymentlogo-#{payment_method.card.brand}"} class="h-5" />
              <p class="sr-only">
                {payment_method.card.brand}
              </p>
              <p class="text-foreground">
                <span aria-hidden="true">••••</span> <span>{payment_method.card.last4}</span>
              </p>
            </div>
          </.async_result>
        </:item>
      </.information_card>

      <.information_card
        :if={@order.swish_checkout}
        name={gettext("Payment")}
        description={gettext("Information about payment.")}
      >
        <:item name={gettext("Payment type")}>Swish</:item>
        <:item name={gettext("Payment status")}>{@order.swish_checkout.status}</:item>
        <:item name={gettext("Swish payment reference")}>
          {@order.swish_checkout.swish_id}
        </:item>
        <:item name={gettext("Swish number")}>
          <.async_result :let={payment_method} assign={@payment_method}>
            <:loading>
              <span class="text-foreground text-sm">{gettext("Loading...")}</span>
            </:loading>
            <:failed :let={_failure}>
              {gettext("There was an error loading the payment method")}
            </:failed>

            <div class="flex flex-row items-center gap-x-1">
              <.payment_method_logo name="paymentlogo-swish" class="h-5" />

              <p class="text-foreground">
                <span>+{payment_method["payerAlias"]}</span>
              </p>
            </div>
          </.async_result>
        </:item>
      </.information_card>

      <.card>
        <.card_header class="flex flex-row">
          <div class="space-y-1.5">
            <.card_title>{gettext("Events and logs")}</.card_title>
            <.card_description>
              {gettext("These are all of the order change events that have happened to this order.")}
            </.card_description>
          </div>
        </.card_header>

        <div class="divide-accent border-accent divide-y border-t">
          <div class="grid grid-cols-1 xl:max-h-128 xl:grid-cols-8">
            <div class="max-h-128 col-span-3 overflow-y-auto p-4 xl:max-h-[inherit]">
              <ul role="list" class="space-y-4">
                <li :for={{entry, i} <- Enum.with_index(@order_log)} class="relative flex gap-x-4">
                  <div
                    :if={i != length(@order_log) - 1}
                    class="absolute top-0 -bottom-3 left-0 flex w-6 justify-center"
                  >
                    <div class="bg-accent w-px"></div>
                  </div>
                  <div class="size-6 bg-background relative flex flex-none items-center justify-center">
                    <div class="size-1.5 bg-accent ring-accent-foreground rounded-full ring-1"></div>
                  </div>
                  <div
                    class={[
                      "ring-accent flex-auto cursor-pointer rounded-md p-3 ring-1 ring-inset",
                      @selected_order_log.id == entry.id && "ring-foreground shadow-sm"
                    ]}
                    phx-click={JS.push("select_order_log", value: %{id: entry.id})}
                  >
                    <p class="text-sm/6 text-foreground">
                      {entry.event_type}
                    </p>
                    <div class="flex justify-between gap-x-4">
                      <time
                        datetime={entry.inserted_at}
                        class="text-xs/5 text-muted-foreground flex-none py-0.5"
                      >
                        {time_to_string(entry.inserted_at, format: :short)}
                      </time>
                    </div>
                  </div>
                </li>
              </ul>
            </div>
            <div class="max-h-128 border-accent col-span-5 flex flex-col overflow-auto border-t p-4 xl:max-h-[inherit] xl:border-t-0 xl:border-l">
              <pre class="font-mono whitespace-pre text-sm"><code>{Jason.encode_to_iodata!(@selected_order_log.metadata) |> Jason.Formatter.pretty_print()}</code></pre>
            </div>
          </div>
        </div>
      </.card>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"id" => event_id, "order_id" => order_id}, _session, socket) do
    order = Orders.get_order!(order_id)
    event = Tiki.Events.get_event!(event_id)
    order_log = Orders.get_order_log!(order_id)

    with :ok <- Tiki.Policy.authorize(:event_manage, socket.assigns.current_user, event) do
      {:ok,
       assign(socket,
         order: order,
         event: event,
         order_log: order_log,
         selected_order_log: List.first(order_log)
       )
       |> assign(page_title: gettext("Order"))
       |> assign_breadcrumbs([
         {"Dashboard", ~p"/admin"},
         {"Events", ~p"/admin/events"},
         {event.name, ~p"/admin/events/#{event.id}"},
         {"Order", ~p"/admin/events/#{event.id}/orders/#{order.id}"}
       ])
       |> assign_async(:payment_method, fn -> get_payment_method(order) end)}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin")}
    end
  end

  attr :name, :string
  attr :description, :string

  slot :item, required: true do
    attr :name, :string, required: true
  end

  slot :actions

  defp information_card(assigns) do
    ~H"""
    <.card>
      <.card_header class="flex flex-row">
        <div class="space-y-1.5">
          <.card_title>{@name}</.card_title>
          <.card_description>{@description}</.card_description>
        </div>

        <div class="ml-auto flex-none">{render_slot(@actions)}</div>
      </.card_header>

      <div class="divide-accent border-accent divide-y border-t">
        <dl class="divide-accent divide-y">
          <div :for={item <- @item} class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
            <dt class="text-muted-foreground text-sm font-medium">{item.name}</dt>
            <dd class="text-foreground mt-1 text-sm sm:col-span-2 sm:mt-0">
              {render_slot(item)}
            </dd>
          </div>
        </dl>
        {render_slot(@inner_block)}
      </div>
    </.card>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("select_order_log", %{"id" => id}, socket) do
    {:noreply,
     assign(socket, selected_order_log: Enum.find(socket.assigns.order_log, &(&1.id == id)))}
  end

  defp get_payment_method(order) do
    payment_method =
      cond do
        order.stripe_checkout ->
          Tiki.Checkouts.retrieve_stripe_payment_method(order.stripe_checkout.payment_method_id)

        order.swish_checkout ->
          Tiki.Checkouts.get_swish_payment_request(order.swish_checkout.swish_id)
      end

    case payment_method do
      {:ok, payment_method} -> {:ok, %{payment_method: payment_method}}
      {:error, error} -> {:error, error}
    end
  end
end
