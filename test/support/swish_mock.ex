defmodule Tiki.Support.SwishMock do
  @behaviour Tiki.Swish

  @payment_request %{
    "amount" => 50.0,
    "callbackUrl" => "https://tiki.asalamon.se/swish/callback",
    "currency" => "SEK",
    "dateCreated" => "2024-11-26T15:51:11.666Z",
    "datePaid" => "2024-11-26T15:51:27.054Z",
    "errorCode" => nil,
    "errorMessage" => nil,
    "id" => "953F901B08BCCCF696F7AF1EEBE62F36",
    "message" => nil,
    "payeeAlias" => "1233908225",
    "payeePaymentReference" => nil,
    "payerAlias" => "46762685000",
    "paymentReference" => "D8158F06D94A4369B78DDAE5A0922D63",
    "status" => "PAID"
  }

  def create_payment_request(0) do
    {:error, "Price must be greater than 0"}
  end

  def create_payment_request(_price) do
    {:ok,
     %{
       swish_id: Ecto.UUID.generate(),
       token: Ecto.UUID.generate(),
       callback_identifier: Ecto.UUID.generate()
     }}
  end

  def get_payment_request(id) do
    {:ok, Map.put(@payment_request, "id", id)}
  end

  def cancel_payment_request(id) do
    {:ok,
     Map.put(@payment_request, "id", id)
     |> Map.put("status", "CANCELLED")}
  end

  def get_svg_qr_code(_token) do
    {:ok, "<svg></svg>"}
  end

  def get_svg_qr_code!(_token) do
    "<svg></svg>"
  end
end
