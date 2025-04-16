defmodule TikiWeb.AdminLive.Attendees.Show do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Orders

  import TikiWeb.Component.Card
  import TikiWeb.Component.Badge

  def mount(%{"id" => event_id, "ticket_id" => ticket_id}, _session, socket) do
    event = Events.get_event!(event_id)

    with :ok <- Tiki.Policy.authorize(:event_manage, socket.assigns.current_user, event),
         ticket <- Orders.get_ticket!(ticket_id),
         order <- Orders.get_order!(ticket.order_id),
         true <- order.event_id == event.id do
      {:ok,
       assign(socket, event: event, ticket: ticket, order: order)
       |> assign_async(:payment_method, fn -> get_payment_method(order) end)}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin")}
    end
  end

  def handle_params(_params, _uri, socket) do
    %{event: event, ticket: ticket} = socket.assigns

    {:noreply,
     assign_breadcrumbs(socket, [
       {"Dashboard", ~p"/admin/"},
       {"Events", ~p"/admin/events"},
       {event.name, ~p"/admin/events/#{event.id}"},
       {"Attendees", ~p"/admin/events/#{event.id}/attendees"},
       {ticket.order.user.full_name || "No Name",
        ~p"/admin/events/#{event.id}/attendees/#{ticket.id}"}
     ])}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <%!-- Ticket information --%>

      <.information_card
        :if={!@ticket.form_response}
        name={gettext("Ticket")}
        description={gettext("Information about ticket.")}
      >
        <:item name={gettext("Signed up at")}>
          {Calendar.strftime(@ticket.order.updated_at, "%x %H:%M")}
        </:item>
        <:item name={gettext("Ticket type")}>{@ticket.ticket_type.name}</:item>

        <:actions>
          <.link navigate={~p"/tickets/#{@ticket}"}>
            <.button variant="link">{gettext("View ticket")}</.button>
          </.link>
        </:actions>

        <div class="flex flex-row items-center px-4 py-5 sm:gap-4 sm:px-6">
          <.icon name="hero-exclamation-triangle" class="text-destructive" />
          <dt class="text-foreground text-sm">
            {gettext("Attendeee has not filled in the required ticket information")}
          </dt>
        </div>
      </.information_card>
      <.information_card
        :if={@ticket.form_response}
        name={gettext("Ticket")}
        description={gettext("Information about ticket.")}
      >
        <:actions>
          <.link navigate={~p"/tickets/#{@ticket}"}>
            <.button variant="link">{gettext("View ticket")}</.button>
          </.link>
        </:actions>
        <:item name={gettext("Signed up at")}>
          {Calendar.strftime(@ticket.order.updated_at, "%x %H:%M")}
        </:item>
        <:item name={gettext("Ticket type")}>{@ticket.ticket_type.name}</:item>
        <:item :for={qr <- @ticket.form_response.question_responses} name={qr.question.name}>
          {qr}
        </:item>
      </.information_card>

      <%!-- Order information --%>
      <.information_card name={gettext("Order")} description={gettext("Information about order.")}>
        <:item name={gettext("Order number")}>
          <.link navigate={~p"/admin/events/#{@event.id}/orders/#{@order.id}"}>
            <.button variant="link" class="h-auto p-0">
              {@order.id}
            </.button>
          </.link>
        </:item>
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

        <.payment_details order={@order} payment_method={@payment_method} />
      </.information_card>
    </div>
    """
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

  defp payment_details(%{order: %{stripe_checkout: stripe_checkout}} = assigns)
       when not is_nil(stripe_checkout) do
    ~H"""
    <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
      <dt class="text-muted-foreground text-sm font-medium">{gettext("Payment method")}</dt>
      <dd class="text-foreground mt-1 text-sm sm:col-span-2 sm:mt-0">
        Stripe
      </dd>
    </div>
    <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
      <dt class="text-muted-foreground text-sm font-medium">
        {gettext("Stripe payment reference")}
      </dt>

      <dd class="text-foreground mt-1 text-sm sm:col-span-2 sm:mt-0">
        {@order.stripe_checkout.payment_intent_id}
      </dd>
    </div>
    <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
      <dt class="text-muted-foreground text-sm font-medium">{gettext("Card details")}</dt>
      <.async_result :let={payment_method} assign={@payment_method}>
        <:loading>
          <span class="text-foreground text-sm">{gettext("Loading...")}</span>
        </:loading>
        <:failed :let={_failure}>
          {gettext("There was an error loading the payment method")}
        </:failed>

        <dd class="text-foreground mt-1 flex flex-row items-center gap-x-2 text-sm sm:col-span-2 sm:mt-0">
          <.payment_method_logo name={"paymentlogo-#{payment_method.card.brand}"} class="h-5" />
          <p class="sr-only">
            {payment_method.card.brand}
          </p>
          <p class="text-foreground">
            <span aria-hidden="true">••••</span> <span>{payment_method.card.last4}</span>
          </p>
        </dd>
      </.async_result>
    </div>
    """
  end

  defp payment_details(%{order: %{swish_checkout: swish_checkout}} = assigns)
       when not is_nil(swish_checkout) do
    ~H"""
    <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
      <dt class="text-muted-foreground text-sm font-medium">{gettext("Payment method")}</dt>
      <dd class="text-foreground mt-1 text-sm sm:col-span-2 sm:mt-0">
        Swish
      </dd>
    </div>
    <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
      <dt class="text-muted-foreground text-sm font-medium">
        {gettext("Swish payment reference")}
      </dt>
      <dd class="text-foreground mt-1 text-sm sm:col-span-2 sm:mt-0">
        {@order.swish_checkout.swish_id}
      </dd>
    </div>
    <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
      <dt class="text-muted-foreground text-sm font-medium">{gettext("Swish number")}</dt>
      <.async_result :let={payment_method} assign={@payment_method}>
        <:loading>
          <span class="text-foreground text-sm">{gettext("Loading...")}</span>
        </:loading>
        <:failed :let={_failure}>
          {gettext("There was an error loading the payment method")}
        </:failed>

        <dd class="text-foreground mt-1 flex flex-row items-center gap-x-2 text-sm sm:col-span-2 sm:mt-0">
          <.payment_method_logo name="paymentlogo-swish" class="h-5" />

          <p class="text-foreground">
            <span>+{payment_method["payerAlias"]}</span>
          </p>
        </dd>
      </.async_result>
    </div>
    """
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
