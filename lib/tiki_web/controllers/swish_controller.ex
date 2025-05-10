defmodule TikiWeb.SwishController do
  use TikiWeb, :controller
  alias Tiki.Checkouts

  require Logger

  def callback(
        conn,
        %{"id" => id, "status" => status} = params
      ) do
    [callback_identifier] = get_req_header(conn, "callbackidentifier")

    # TODO: Handle the case where status is "CANCELLED" or "ERROR" separately

    case Checkouts.confirm_swish_payment(id, callback_identifier, status) do
      :ok ->
        send_resp(conn, 200, "OK")

      {:error, reason} ->
        Logger.error("Confirming Swish payment failed: #{reason}, params: #{inspect(params)}")

        # We received the callback, and did our best to process it, no need to return an error.
        # If we dont't return 200, the callback will be retried 5 times.
        send_resp(conn, 200, "OK")
    end
  end

  def refund(
        conn,
        %{"id" => id, "status" => status}
      ) do
    [callback_identifier] = get_req_header(conn, "callbackidentifier")

    case Checkouts.update_swish_refund(id, callback_identifier, status) do
      :ok ->
        send_resp(conn, 200, "OK")

      {:error, reason} ->
        Logger.error("Updating Swish refund failed: #{reason}")
        send_resp(conn, 200, "OK")
    end
  end
end
