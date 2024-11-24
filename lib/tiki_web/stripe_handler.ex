defmodule TikiWeb.StripeHandler do
  @behaviour Stripe.WebhookHandler

  require Logger
  alias Tiki.Checkouts

  def handle_event(%Stripe.Event{
        type: "payment_intent.succeeded",
        data: %{object: %Stripe.PaymentIntent{} = payment_intent}
      }) do
    Checkouts.confirm_stripe_payment(payment_intent)
  end

  def handle_event(event) do
    Logger.info("Unknown Stripe Event #{inspect(event)}")
    :ok
  end
end
