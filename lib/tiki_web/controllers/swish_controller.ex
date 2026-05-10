defmodule TikiWeb.SwishController do
  use TikiWeb, :controller
  alias Tiki.Checkouts

  require Logger

  def callback(
        conn,
        %{"status" => status}
      ) do
    [callback_identifier] = get_req_header(conn, "callbackidentifier")

    case Checkouts.handle_swish_callback(callback_identifier, status) do
      :ok -> :ok
      {:error, reason} -> Logger.error("Handling Swish callback failed: #{inspect(reason)}")
    end

    send_resp(conn, 200, "OK")
  end
end
