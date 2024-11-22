defmodule TikiWeb.SwishController do
  use TikiWeb, :controller
  alias Tiki.Checkouts

  import Logger

  def callback(
        conn,
        %{"status" => status} = params
      ) do
    [callback_identifier] = get_req_header(conn, "callbackidentifier")

    case Checkouts.confirm_swish_payment(callback_identifier, status) do
      :ok ->
        send_resp(conn, 200, "OK")

      {:error, reason} ->
        Logger.error("Confirming Swish payment failed: #{reason}")
        send_resp(conn, 500, "Internal server error")
    end
  end
end
