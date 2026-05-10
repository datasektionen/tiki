defmodule TikiWeb.StripeWebhookController do
  use TikiWeb, :controller
  require Logger

  alias Tiki.Checkouts
  alias Tiki.Stripe

  plug :verify_signature

  def create(conn, %{
        "type" => "payment_intent.succeeded",
        "data" => %{"object" => %{"metadata" => %{"tiki_order_id" => _}} = object}
      }) do
    case Checkouts.confirm_stripe_payment(Tiki.Utils.cast_to_struct(Stripe.PaymentIntent, object)) do
      :ok -> :ok
      {:error, reason} -> Logger.error("Confirming Stripe payment failed: #{inspect(reason)}")
    end

    send_resp(conn, 200, "")
  end

  def create(conn, params) do
    Logger.info("Unhandled Stripe event: #{inspect(params["type"])}")
    send_resp(conn, 200, "")
  end

  defp verify_signature(conn, []) do
    secret = Application.fetch_env!(:tiki, :stripe_webhook_secret)
    "whsec_" <> _ = secret

    with {:ok, signature} <- get_signature(conn),
         :ok <- Tiki.Stripe.WebhookSignature.verify(conn.assigns.raw_body, signature, secret) do
      conn
    else
      {:error, error} ->
        Logger.error("[StripeWebhookController] invalid signature: #{error}")

        conn
        |> send_resp(400, "invalid signature: " <> error)
        |> halt()
    end
  end

  defp get_signature(conn) do
    case get_req_header(conn, "stripe-signature") do
      [header] -> {:ok, header}
      _ -> {:error, "no signature"}
    end
  end
end
