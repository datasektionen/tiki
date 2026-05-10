defmodule TikiWeb.StripeWebhookController do
  use TikiWeb, :controller
  require Logger

  alias Tiki.Checkouts

  plug :verify_signature

  def create(conn, %{
        "type" => "payment_intent.succeeded",
        "data" => %{"object" => %{"metadata" => %{"tiki_order_id" => _}} = object}
      }) do
    Checkouts.confirm_stripe_payment(Tiki.Utils.cast_to_struct(Stripe.PaymentIntent, object))

    send_resp(conn, 200, "")
  end

  def create(conn, params) do
    Logger.info("Unhandled Stripe event: #{inspect(params["type"])}")
    send_resp(conn, 200, "")
  end

  defp verify_signature(conn, _opts) do
    secret = Application.fetch_env!(:tiki, :stripe_webhook_secret)

    with [signature] <- get_req_header(conn, "stripe-signature"),
         raw_body <- conn.assigns[:raw_body] |> Enum.reverse() |> IO.iodata_to_binary(),
         :ok <- Tiki.Stripe.WebhookSignature.verify(raw_body, signature, secret) do
      conn
    else
      {:error, message} ->
        Logger.error("[StripeWebhookController] invalid signature: #{message}")
        conn |> send_resp(400, "invalid signature") |> halt()

      _ ->
        conn |> send_resp(400, "missing signature") |> halt()
    end
  end
end
