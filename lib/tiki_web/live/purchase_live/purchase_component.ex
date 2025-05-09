defmodule TikiWeb.PurchaseLive.PurchaseComponent do
  defmodule Response do
    use Tiki.Schema
    import Ecto.Changeset
    use Gettext, backend: TikiWeb.Gettext

    embedded_schema do
      field :name, :string
      field :email, :string
      field :payment_method, :string
      field :terms_of_service, :boolean
    end

    def changeset(struct, params \\ %{}, order)

    def changeset(struct, params, %Tiki.Orders.Order{price: 0}) do
      free_changeset(struct, params)
    end

    def changeset(struct, params, %Tiki.Orders.Order{price: price})
        when price > 0 do
      struct
      |> cast(params, [:payment_method])
      |> validate_required([:payment_method])
      |> validate_inclusion(:payment_method, ~w(credit_card swish))
      |> free_changeset(params)
    end

    defp free_changeset(struct, params) do
      struct
      |> cast(params, [:name, :email, :terms_of_service])
      |> validate_required([:name, :email])
      |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
        message: gettext("must have the @ sign and no spaces")
      )
      |> validate_length(:email, max: 160)
      |> validate_acceptance(
        :terms_of_service,
        message: gettext("You must accept the terms of service.")
      )
    end
  end

  alias Tiki.PurchaseMonitor
  use TikiWeb, :live_component

  alias Tiki.Orders
  alias Tiki.Checkouts

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div>
      <.dialog
        id="purchase-modal"
        show
        on_cancel={JS.push("cancel", target: @myself) |> JS.dispatch("embedded:close")}
        safe
      >
        <div :if={@order.status == :cancelled} class="flex w-full flex-col gap-2">
          <h2 class="text-2xl font-semibold leading-none tracking-tight">{gettext("Error")}</h2>
          <p class="text-muted-foreground text-sm">
            {gettext(
              "Something went wrong. Your order was cancelled or has expired. Please try again."
            )}
          </p>
        </div>

        <div :if={@order.status in [:pending, :checkout]}>
          <div>
            <.header class="border-none">
              {gettext("Payment")}
              <:subtitle>
                {gettext(
                  "Purchase tickets for %{event}. You have %{count} minutes to complete your order.",
                  event: @event.name,
                  count: PurchaseMonitor.timeout_minutes()
                )}
              </:subtitle>
            </.header>

            <table class="w-full border-collapse border-spacing-0">
              <tbody class="text-sm">
                <tr :for={{_id, %{ticket_type: tt, count: count}} <- @order.tickets} class="border-t">
                  <th class="py-1 pr-2 text-left">{tt.name}</th>
                  <td class="whitespace-nowrap py-1 pr-2 text-right">
                    {"#{count} x #{tt.price} kr"}
                  </td>
                  <td class="whitespace-nowrap py-1 text-right">
                    {tt.price * count} kr
                  </td>
                </tr>
                <tr class="border-border border-t-2 text-sm font-semibold">
                  <th></th>
                  <td class="whitespace-nowrap py-1 pr-2 text-right uppercase">
                    {gettext("Total")}
                  </td>
                  <td class="whitespace-nowrap py-1 text-right">
                    {@order.price} kr
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div :if={@order.status == :pending}>
            <.form
              for={@form}
              phx-target={@myself}
              phx-change="validate"
              phx-submit="submit"
              class="flex w-full flex-col gap-4"
            >
              <div :if={@order.price > 0}>
                <.label for={@form[:payment_method].id}>
                  {gettext("Payment method")}
                </.label>
                <.radio_group
                  field={@form[:payment_method]}
                  class="text-bold mt-2 flex flex-row gap-10 text-sm"
                >
                  <:radio
                    :if={FunWithFlags.enabled?(:stripe_enabled)}
                    value="credit_card"
                    class="flex flex-row-reverse items-center gap-3"
                  >
                    {gettext("Credit card")}
                  </:radio>
                  <:radio
                    :if={FunWithFlags.enabled?(:swish_enabled)}
                    value="swish"
                    class="flex flex-row-reverse items-center gap-3"
                  >
                    {gettext("Swish")}
                  </:radio>

                  <:radio value="" class="hidden"></:radio>
                </.radio_group>
              </div>
              <.input
                field={@form[:name]}
                label={gettext("Name")}
                placeholder={gettext("Your name")}
                default={@current_user && @current_user.full_name}
                phx-debounce="300"
              />
              <.input
                field={@form[:email]}
                label={gettext("Email")}
                placeholder={gettext("Your email")}
                default={@current_user && @current_user.email}
                phx-debounce="blur-sm"
              />

              <.input type="checkbox" field={@form[:terms_of_service]}>
                <:checkbox_label>
                  <div>
                    {gettext("I agree to")} <.link
                      href={~p"/terms"}
                      class="text-primary underline"
                      target="_blank"
                    >{gettext("the terms of service")}</.link>.
                  </div>
                </:checkbox_label>
              </.input>

              <.button type="submit">
                {gettext("Continue")}
              </.button>
            </.form>
          </div>

          <div :if={@order.status == :checkout && @order.swish_checkout} class="flex flex-col">
            <.label>
              {gettext("Pay using Swish")}
            </.label>
            <div class="max-w-96 w-full self-center">
              {raw(Tiki.Checkouts.get_swisg_svg_qr_code!(@order.swish_checkout.token))}
            </div>

            <.link href={{:swish, "//paymentrequest?token=#{@order.swish_checkout.token}"}}>
              <.button class="w-full" variant="outline">
                {gettext("Open swish on this device")}
              </.button>
            </.link>
          </div>

          <form
            :if={@order.status == :checkout && @order.stripe_checkout}
            id="payment-form"
            phx-hook="InitCheckout"
            data-secret={@order.stripe_checkout.client_secret}
            class="flex flex-col gap-4"
          >
            <div id="link-authentication-element">
              <!--Stripe.js injects the Link Authentication Element-->
            </div>
            <div id="payment-element">
              <!--Stripe.js injects the Payment Element-->
            </div>
            <.button id="submit" phx-click={JS.show(to: "#spinner")} class="space-x-2">
              <.spinner class="size-4 hidden" id="spinner" />
              <span id="button-text">
                {gettext("Pay")} {@order.price} kr
              </span>
            </.button>
            <div id="payment-message" class="hidden"></div>
          </form>
        </div>
      </.dialog>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    order =
      set_ticket_counts(assigns.order)
      |> Map.update!(:stripe_checkout, &Checkouts.load_stripe_client_secret!/1)

    {:ok,
     assign(socket, assigns)
     |> assign(order: order)
     |> assign(:form, to_form(Response.changeset(%Response{}, %{}, order)))}
  end

  defp set_ticket_counts(%Orders.Order{} = order) do
    if Ecto.assoc_loaded?(order.tickets) do
      Map.update!(order, :tickets, fn tickets ->
        Enum.reduce(tickets, %{}, fn t, acc ->
          Map.put_new(acc, t.ticket_type_id, %{count: 0, ticket_type: t.ticket_type})
          |> update_in([t.ticket_type_id, :count], &(&1 + 1))
        end)
      end)
    else
      Map.put(order, :tickets, [])
    end
  end

  @impl Phoenix.LiveComponent
  def handle_event("validate", %{"response" => response_params}, socket) do
    changeset =
      Response.changeset(%Response{}, response_params, socket.assigns.order)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("submit", %{"response" => response_params}, socket) do
    changeset =
      Response.changeset(%Response{}, response_params, socket.assigns.order)
      |> Map.put(:action, :save)

    with {:ok, %Response{} = response} <- Ecto.Changeset.apply_action(changeset, :save),
         {:ok, order} <-
           Orders.init_checkout(socket.assigns.order, response.payment_method, %{
             email: response.email,
             name: response.name,
             locale: Gettext.get_locale(TikiWeb.Gettext)
           }) do
      {:noreply, assign(socket, order: order)}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  def handle_event("cancel", _params, socket) do
    Orders.maybe_cancel_order(socket.assigns.order.id)

    case socket.assigns.action do
      :embedded_purchase -> {:noreply, socket}
      _ -> {:noreply, socket |> push_patch(to: ~p"/events/#{socket.assigns.event}")}
    end
  end
end
