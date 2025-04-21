defmodule TikiWeb.EmbeddedController do
  use TikiWeb, :controller

  def close(conn, _params) do
    conn
    |> render("close.html", layout: false)
  end
end
