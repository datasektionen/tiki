defmodule TikiWeb.OrderLive.Show do
  use TikiWeb, :live_view

  alias Tiki.Orders

  import TikiWeb.Component.Card
  import TikiWeb.Component.Skeleton

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="space-y-2 px-4 sm:flex sm:items-baseline sm:justify-between sm:space-y-0 sm:px-0">
      <div class="flex sm:items-baseline sm:space-x-4">
        <h1 class="text-foreground text-xl font-bold tracking-tight sm:text-2xl">
          {gettext("Thank you for your order!")}
        </h1>
        <!-- TODO: Receipt link -->
        <.link
          href="#"
          class="text-secondary-foreground hidden text-sm font-medium hover:text-secondary-foreground/80 sm:block"
        >
          {gettext("View receipt")} <span aria-hidden="true"> &rarr;</span>
        </.link>
      </div>
      <p class="text-muted-foreground text-sm">
        <!-- TODO: Proper time  -->
        Order placed
        <time datetime={@order.updated_at}>
          {Tiki.Cldr.DateTime.to_string!(@order.updated_at, format: :short)}
        </time>
      </p>
      <!-- TODO: Receipt link -->
      <.link href="#" class="text-sm font-medium sm:hidden">
        {gettext("View receipt")} <span aria-hidden="true"> &rarr;</span>
      </.link>
    </div>

    <div class="mt-6">
      <h2 class="sr-only">{gettext("Tickets")}</h2>

      <div class="space-y-4 md:space-y-8">
        <.card :for={ticket <- @order.tickets}>
          <div class="px-4 py-6 sm:px-6 lg:grid lg:grid-cols-12 lg:gap-x-8 lg:p-8">
            <div class="flex lg:col-span-7">
              <div class="size-24">
                <.svg_qr data={ticket.id} />
              </div>
              <div class="ml-6">
                <.link navigate={~p"/tickets/#{ticket}"}>
                  <h3 class="text-foreground text-base font-medium">
                    {ticket.ticket_type.name}
                  </h3>
                </.link>
                <p class="text-foreground mt-2 text-sm font-medium">
                  {ticket.ticket_type.price} SEK
                </p>
                <p class="text-muted-foreground mt-3 text-sm">
                  {ticket.ticket_type.description}
                </p>
              </div>
            </div>
            <div :if={ticket.form_response} class="mt-6 lg:col-span-5 lg:mt-0">
              <dl class="grid grid-cols-2 gap-x-6 text-sm">
                <div>
                  <dt class="text-foreground font-medium">
                    {gettext("Name")}
                  </dt>
                  <dd class="text-muted-foreground mt-3">
                    <span class="block">
                      {find_in_response(ticket.form_response, "namn")}
                    </span>
                  </dd>
                </div>
                <div>
                  <dt class="text-foreground font-medium">
                    {gettext("Contact information")}
                  </dt>
                  <dd class="text-muted-foreground mt-3 space-y-3">
                    <p>
                      {find_in_response(ticket.form_response, "email")}
                    </p>
                  </dd>
                </div>
              </dl>
            </div>
          </div>

          <div
            :if={!ticket.form_response}
            class="border-border flex flex-row items-center justify-between border-t px-4 py-6 sm:px-6 lg:gap-x-8 lg:p-8"
          >
            <p class="text-sm font-medium">
              {gettext("You need to fill in attendance information for this ticket")}
            </p>

            <.link navigate={~p"/tickets/#{ticket.id}/form"}>
              <.button variant="secondary">
                {gettext("Fill in")}
              </.button>
            </.link>
          </div>
        </.card>

        <.card>
          <h2 class="sr-only">
            {gettext("Billing summary")}
          </h2>

          <div class="px-4 py-6 sm:rounded-lg sm:px-6 lg:grid lg:grid-cols-12 lg:gap-x-8 lg:px-8 lg:py-8">
            <dl class="grid grid-cols-2 gap-6 text-sm sm:grid-cols-2 md:gap-x-8 lg:col-span-7">
              <div>
                <dt class="text-foreground font-medium">
                  {gettext("Order information")}
                </dt>
                <dd class="text-muted-foreground mt-3">
                  <span class="block">
                    {@order.user.full_name}
                  </span>
                  <span class="block">
                    {@order.user.email}
                  </span>
                </dd>
              </div>
              <div>
                <dt class="text-foreground font-medium">
                  {gettext("Payment information")}
                </dt>

                <div class="mt-4">
                  <.async_result :let={payment_method} assign={@payment_method}>
                    <:loading>
                      <.skeleton class="h-10 w-full" />
                    </:loading>
                    <:failed :let={_failure}>
                      {gettext("There was an error loading the payment method")}
                    </:failed>
                    <.payment_method payment_method={payment_method} />
                  </.async_result>
                </div>
              </div>
            </dl>

            <dl class="divide-border mt-8 divide-y text-sm lg:col-span-5 lg:mt-0">
              <div class="flex items-center justify-between pb-4">
                <dt class="text-muted-foreground">
                  {gettext("Subtotal")}
                </dt>
                <dd class="text-foreground font-medium">
                  {@order.price} SEK
                </dd>
              </div>
              <div class="flex items-center justify-between py-4">
                <dt class="text-muted-foreground">
                  {gettext("VAT")}
                </dt>
                <dd class="text-foreground font-medium">
                  0 SEK
                </dd>
              </div>
              <div class="flex items-center justify-between pt-4">
                <dt class="text-foreground font-medium">{gettext("Order total")}</dt>
                <dd class="text-accent-foreground font-medium">
                  {@order.price} SEK
                </dd>
              </div>
            </dl>
          </div>
        </.card>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    # TODO: fix this preloading nonsense
    order =
      Orders.get_order!(id)
      |> Tiki.Repo.preload(tickets: [form_response: [question_responses: [:question]]])

    {:ok,
     assign(socket, order: order)
     |> assign_async(:payment_method, fn ->
       payment_method =
         cond do
           order.stripe_checkout ->
             Tiki.Checkouts.retrieve_stripe_payment_method(
               order.stripe_checkout.payment_method_id
             )

           order.swish_checkout ->
             Tiki.Checkouts.get_swish_payment_request(order.swish_checkout.swish_id)
         end

       case payment_method do
         {:ok, payment_method} -> {:ok, %{payment_method: payment_method}}
         {:error, error} -> {:error, error}
       end
     end)}
  end

  defp find_in_response(response, question) do
    response.question_responses
    |> Enum.find(%{}, fn qr -> String.downcase(qr.question.name) == question end)
    |> Map.get(:answer, "")
  end

  defp payment_method(
         %{payment_method: %Stripe.PaymentMethod{card: _card}} =
           assigns
       ) do
    ~H"""
    <dd class="mt-4 flex flex-wrap">
      <.payment_method_logo name={"paymentlogo-#{@payment_method.card.brand}"} class="h-5" />
      <p class="sr-only">
        {@payment_method.card.brand}
      </p>
      <div class="ml-4">
        <p class="text-foreground">
          <span aria-hidden="true">••••</span> <span>{@payment_method.card.last4}</span>
        </p>
        <p class="text-muted-foreground">
          {gettext("Expires")}
          <span>
            {@payment_method.card.exp_month}/{rem(@payment_method.card.exp_year, 100)}
          </span>
        </p>
      </div>
    </dd>
    """
  end

  defp payment_method(
         %{payment_method: %{"payerAlias" => _payer_alias}} =
           assigns
       ) do
    ~H"""
    <dd class="flex flex-wrap">
      <.payment_method_logo name="paymentlogo-swish" class="h-5" />
      <p class="sr-only">Swish</p>
      <div class="ml-4">
        <p class="text-foreground">
          <span>+{@payment_method["payerAlias"]}</span>
        </p>
      </div>
    </dd>
    """
  end
end
