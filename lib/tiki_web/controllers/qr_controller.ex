defmodule TikiWeb.QrController do
  use TikiWeb, :controller

  def create(conn, %{"code" => code}) do
    qr =
      QRCodeEx.encode(code)
      |> QRCodeEx.png()

    conn
    |> put_resp_content_type("image/png")
    |> send_resp(200, qr)
  end
end
