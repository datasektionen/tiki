defmodule TikiWeb.StripeWebhookControllerTest do
  use TikiWeb.ConnCase, async: true

  import ExUnit.CaptureLog

  alias Tiki.Stripe.WebhookSignature

  @secret "whsec_test_secret_key_for_webhook_tests"

  setup do
    Application.put_env(:tiki, :stripe_webhook_secret, @secret)
    on_exit(fn -> Application.delete_env(:tiki, :stripe_webhook_secret) end)
    :ok
  end

  defp signed_post(conn, body) do
    timestamp = System.system_time(:second)
    signature = WebhookSignature.sign(body, timestamp, @secret)

    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("stripe-signature", signature)
    |> post("/stripe/webhook", body)
  end

  describe "POST /stripe/webhook" do
    test "accepts a valid signed payload", %{conn: conn} do
      body = Jason.encode!(%{"type" => "some.unhandled_event"})
      conn = signed_post(conn, body)
      assert conn.status == 200
    end

    test "rejects a payload with an invalid signature", %{conn: conn} do
      body = Jason.encode!(%{"type" => "some.unhandled_event"})

      {conn, log} =
        with_log(fn ->
          conn
          |> put_req_header("content-type", "application/json")
          |> put_req_header(
            "stripe-signature",
            "t=#{System.system_time(:second)},v1=badsignature"
          )
          |> post("/stripe/webhook", body)
        end)

      assert conn.status == 400
      assert log =~ "invalid signature: signature is incorrect"
    end

    test "rejects a request with no signature header", %{conn: conn} do
      body = Jason.encode!(%{"type" => "some.unhandled_event"})

      {conn, log} =
        with_log(fn ->
          conn
          |> put_req_header("content-type", "application/json")
          |> post("/stripe/webhook", body)
        end)

      assert conn.status == 400
      assert log =~ "invalid signature: no signature"
    end

    test "rejects an expired signature", %{conn: conn} do
      body = Jason.encode!(%{"type" => "some.unhandled_event"})
      old_timestamp = System.system_time(:second) - 301
      signature = WebhookSignature.sign(body, old_timestamp, @secret)

      {conn, log} =
        with_log(fn ->
          conn
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", signature)
          |> post("/stripe/webhook", body)
        end)

      assert conn.status == 400
      assert log =~ "invalid signature: signature is expired"
    end
  end
end
