defmodule Tiki.Swish do
  @moduledoc """
  A module for integrating with the Swish API
  """

  @api_url Application.compile_env(:tiki, Tiki.Swish)[:api_url]
  @prod_api_url "https://mpc.getswish.net/qrg-swish/api"
  @alphabet ~C"ABCDEF0123456789"
  @full_alphabet ~C"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"
  @full_alph_len length(@full_alphabet)
  @alph_len length(@alphabet)

  @type id :: String.t()

  @typedoc """
  A payment request object. This object is used in all payment request
  operations.
  """
  @type payment_request :: %{
          id: id(),
          payeePaymentReference: String.t(),
          paymentReference: String.t() | nil,
          callbackUrl: String.t(),
          payerAlias: String.t(),
          payerSSN: String.t() | nil,
          ageLimit: String.t() | nil,
          # Maximum 2 decimal places
          amount: float(),
          callbackIdentifier: String.t() | nil
        }

  @type success_response :: %{
          id: id(),
          token: String.t(),
          callback_identifier: String.t()
        }

  @doc """
  Create a payment request. The ID _must_ be a 32-character string.
  The payment request object _must_ contain the following fields:

  * `amount`. The amount to be paid. This must be a positive float
      with a maximum of two decimal places.


  The rest of the fields are optional.
  """
  @spec create_payment_request(float()) ::
          {:ok, success_response()} | {:error, [map()] | String.t()}
  def create_payment_request(amount) do
    _ = :crypto.rand_seed()
    id = for _ <- 1..32, into: "", do: <<Enum.at(@alphabet, :rand.uniform(@alph_len) - 1)>>

    callback_identifier =
      for _ <- 1..36, into: "", do: <<Enum.at(@full_alphabet, :rand.uniform(@full_alph_len) - 1)>>

    payment_request =
      %{
        "amount" => amount,
        "payeeAlias" => Application.get_env(:tiki, Tiki.Swish)[:merchant_number],
        "currency" => "SEK",
        "callbackUrl" => "https://localhost:4000",
        "callbackIdentifier" => callback_identifier
      }

    res =
      Req.put(base_request(),
        url: @api_url <> "/v2/paymentrequests/#{id}",
        json: payment_request
      )

    case res do
      {:ok, %Req.Response{status: 201, headers: %{"paymentrequesttoken" => [token]}}} ->
        {:ok, %{id: id, token: token, callback_identifier: callback_identifier}}

      {:ok, %Req.Response{status: status, body: body}} when status >= 400 and status < 500 ->
        {:error, body}

      {:ok, %Req.Response{status: 500}} ->
        {:error, "Internal server error"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get a payment request by its ID. The ID _must_ be a 32-character string.
  """
  @spec get_payment_request(id()) :: {:ok, map()} | {:error, String.t()}
  def get_payment_request(id) do
    res = Req.get(base_request(), url: @api_url <> "/v1/paymentrequests/#{id}")

    case res do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: 401}} -> {:error, "Unauthorized"}
      {:ok, %Req.Response{status: 404}} -> {:error, "Not found"}
      {:ok, %Req.Response{status: 429}} -> {:error, "Too many requests"}
      {:ok, %Req.Response{status: 500}} -> {:error, "Internal server error"}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Cancels a payment request. A payment request can be cancelled at any
  time before the request has been accepted or completed - status
  “ERROR”, “PAID”, “CANCELLED”, "DECLINED" etc.
  """
  @spec cancel_payment_request(id()) ::
          {:ok, map()} | {:error, String.t() | [map()]}
  def cancel_payment_request(id) do
    # The body has to contain a list of Operation objects. There is only
    # support for one operation at the moment in the Swish API.

    operations = [%{"op" => "replace", "path" => "/status", "value" => "CANCELLED"}]

    res =
      Req.patch(base_request(),
        url: @api_url <> "/v1/paymentrequests/#{id}",
        headers: [{"Content-Type", "application/json-patch+json"}],
        json: operations
      )

    case res do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: 401}} ->
        {:error, "Unauthorized"}

      {:ok, %Req.Response{status: 404}} ->
        {:error, "Not found"}

      {:ok, %Req.Response{status: 415}} ->
        {:error, "Unsupported media type, use application/json-patch+json"}

      {:ok, %Req.Response{status: 422, body: body}} ->
        {:error, body}

      {:ok, %Req.Response{status: 429}} ->
        {:error, "Too many requests"}

      {:ok, %Req.Response{status: 500}} ->
        {:error, "Internal server error"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_svg_qr_code(token) do
    url = @prod_api_url <> "/v1/commerce"

    request =
      Req.post(url,
        headers: [{"Content-Type", "application/json"}],
        json: %{token: token, format: "svg"}
      )

    case request do
      {:ok, %Req.Response{status: 200, body: svg}} ->
        {:ok, svg}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_request() do
    config = Application.get_env(:tiki, Tiki.Swish)

    Req.new(
      headers: [
        {"Content-Type", "application/json"}
      ],
      connect_options: [
        transport_opts: [
          cacertfile: config[:cacert],
          certfile: config[:cert],
          keyfile: config[:key],
          # TODO - this is probably not the right way to do this
          # note: see https://github.com/erlang/otp/issues/8057
          verify: :verify_none
        ]
      ]
    )
  end
end
