defmodule Tiki.Support.SwishMock do
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
end
