defmodule TikiWeb.SwishController do
  use TikiWeb, :controller

  def callback(conn, params) do
    IO.inspect(params)

    conn
  end
end
