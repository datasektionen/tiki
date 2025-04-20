defmodule TikiWeb.MetricsPlug do
  use Plug.Router

  plug :match
  plug :dispatch

  forward "/metrics", to: PromEx.Plug, prom_ex_module: Tiki.PromEx

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
