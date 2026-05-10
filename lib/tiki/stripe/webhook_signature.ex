defmodule Tiki.Stripe.WebhookSignature do
  @schema "v1"
  @valid_period_in_seconds 300

  def verify(payload, signature, secret) do
    with {:ok, timestamp, hash} <- parse(signature) do
      current_timestamp = System.system_time(:second)

      cond do
        timestamp + @valid_period_in_seconds < current_timestamp ->
          {:error, "signature is expired"}

        not Plug.Crypto.secure_compare(hash, hash(timestamp, payload, secret)) ->
          {:error, "signature is incorrect"}

        true ->
          :ok
      end
    end
  end

  defp parse(signature) do
    parsed =
      for pair <- String.split(signature, ","),
          destructure([key, value], String.split(pair, "=", parts: 2)),
          do: {key, value},
          into: %{}

    with %{"t" => timestamp, @schema => hash} <- parsed,
         {timestamp, ""} <- Integer.parse(timestamp) do
      {:ok, timestamp, hash}
    else
      _ -> {:error, "signature is in wrong format or missing #{@schema} schema"}
    end
  end

  defp hash(timestamp, payload, secret) do
    :crypto.mac(:hmac, :sha256, secret, ["#{timestamp}.", payload])
    |> Base.encode16(case: :lower)
  end
end
