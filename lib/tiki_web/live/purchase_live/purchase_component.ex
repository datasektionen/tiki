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

    def changeset(struct, params \\ %{}) do
      struct
      |> cast(params, [:name, :email, :payment_method, :terms_of_service])
      |> validate_required([:name, :email, :payment_method])
      |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
        message: gettext("must have the @ sign and no spaces")
      )
      |> validate_length(:email, max: 160)
      |> validate_inclusion(:payment_method, ~w(credit_card swish))
      |> validate_acceptance(
        :terms_of_service,
        message: gettext("You must accept the terms of service.")
      )
    end
  end

  use TikiWeb, :live_component

  alias Tiki.Orders
  alias Tiki.Checkouts
  alias Tiki.Accounts

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div>
      <.dialog id="purchase-modal" show on_cancel={JS.push("cancel", target: @myself)} safe>
        <div :if={@order.status == :cancelled}>
          {gettext("Ya messed up, order is cancelled")}
        </div>

        <div :if={@order.status == :pending}>
          <div>
            <.header class="border-none">
              {gettext("Payment")}
              <:subtitle>
                {gettext(
                  "Purchase tickets for %{event}. You have %{count} minutes to complete your order.",
                  event: @event.name,
                  count: 2
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
                <tr class="border-border border-t-2">
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

          <div :if={!(@order.swish_checkout || @order.stripe_checkout)}>
            <.form
              for={@form}
              phx-target={@myself}
              phx-change="validate"
              phx-submit="submit"
              class="flex w-full flex-col gap-4"
            >
              <div>
                <.label for={@form[:payment_method].id}>
                  {gettext("Payment method")}
                </.label>
                <.radio_group
                  field={@form[:payment_method]}
                  class="text-bold mt-2 flex flex-row gap-10 text-sm"
                >
                  <:radio value="credit_card" class="flex flex-row-reverse items-center gap-3">
                    {gettext("Credit card")}
                  </:radio>
                  <:radio value="swish" class="flex flex-row-reverse items-center gap-3">
                    {gettext("Swish")}
                  </:radio>

                  <:radio value="" class="hidden"></:radio>
                </.radio_group>
              </div>
              <.input
                field={@form[:name]}
                label={gettext("Name")}
                placeholder={gettext("Your name")}
                phx-debounce="300"
              />
              <.input
                field={@form[:email]}
                label={gettext("Email")}
                placeholder={gettext("Your email")}
                phx-debounce="blur-sm"
              />

              <.input
                type="checkbox"
                field={@form[:terms_of_service]}
                label={
                  gettext(
                    "I have read the terms and conditions and agree to the sale of my personal information to the highest bidder."
                  )
                }
              />

              <.button type="submit">
                {gettext("Continue")}
              </.button>
            </.form>
          </div>

          <div :if={@order.swish_checkout} class="flex flex-col">
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
            :if={@order.stripe_checkout}
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
     |> assign(:form, to_form(Response.changeset(%Response{})))}
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
      Response.changeset(%Response{}, response_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl Phoenix.LiveComponent
  def handle_event("submit", %{"response" => response_params}, socket) do
    changeset =
      Response.changeset(%Response{}, response_params)
      |> Map.put(:action, :save)

    with {:ok, %Response{} = response} <- Ecto.Changeset.apply_action(changeset, :save),
         {:ok, user} <- Accounts.upsert_user_email(response.email, response.name),
         {:ok, order} <- Orders.update_order(socket.assigns.order, %{user_id: user.id}),
         {:ok, checkout} = init_checkout(order, response.payment_method) do
      order =
        case checkout do
          %Checkouts.SwishCheckout{} = checkout -> Map.put(order, :swish_checkout, checkout)
          %Checkouts.StripeCheckout{} -> Map.put(order, :stripe_checkout, checkout)
        end

      {:noreply, assign(socket, order: order)}
    else
      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("cancel", _params, socket) do
    Orders.maybe_cancel_order(socket.assigns.order.id)
    {:noreply, socket |> push_patch(to: ~p"/events/#{socket.assigns.event}")}
  end

  defp init_checkout(order, "credit_card"), do: Checkouts.create_stripe_payment_intent(order)
  defp init_checkout(order, "swish"), do: Checkouts.create_swish_payment_request(order)
end
