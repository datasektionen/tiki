defmodule Tiki.Swish do
  def create_payment_request(ammount, message) do
    # https://developer.swish.nu/documentation/guides/create-a-payment-request#m-commerce-payment-flow

    # 1. Create a payment request
    uuid = Ecto.UUID.generate() |> String.upcase() |> String.replace("-", "")
    url = "https://mss.cpc.getswish.net/swish-cpcapi/api/v2/paymentrequests/#{uuid}"

    body =
      %{
        "callbackUrl" => "https://9bba-185-81-109-88.eu.ngrok.io/api/swish/callback",
        "payeeAlias" => "1231181189",
        "currency" => "SEK",
        "amount" => ammount,
        "message" => message
      }
      |> Jason.encode!()

    response =
      HTTPoison.put(url, body, [{"Content-Type", "application/json"}],
        ssl: [
          certfile:
            "/Users/asalamon/Documents/random/tiki/swish_certs/Swish_Merchant_TestCertificate_1234679304.pem",
          keyfile:
            "/Users/asalamon/Documents/random/tiki/swish_certs/Swish_Merchant_TestCertificate_1234679304.key",
          cacertfile: "/Users/asalamon/Documents/random/tiki/swish_certs/Swish_TLS_RootCA.pem",
          password: "swish",
          verify: :verify_peer
        ]
      )

    IO.inspect(response)
  end
end
