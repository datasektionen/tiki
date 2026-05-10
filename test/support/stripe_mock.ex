defmodule Tiki.Support.StripeMock do
  alias Tiki.Stripe

  defmodule PaymentIntent do
    alias Tiki.Stripe.PaymentIntent

    def create(%{amount: 0}) do
      {:error, %{"error" => %{"message" => "Amount must be greater than 0"}}}
    end

    def create(%{amount: amount}) do
      id = Ecto.UUID.generate()
      client_secret = Ecto.UUID.generate()
      {:ok, %PaymentIntent{id: "pi_#{id}", client_secret: client_secret, amount: amount}}
    end

    def retrieve(id) do
      client_secret = Ecto.UUID.generate()
      {:ok, %PaymentIntent{id: id, client_secret: client_secret}}
    end
  end

  defmodule PaymentMethod do
    alias Tiki.Stripe.PaymentMethod

    def retrieve("invalid") do
      {:error, %{"error" => %{"message" => "No such payment method"}}}
    end

    def retrieve(id) do
      {:ok, %PaymentMethod{id: id, card: %Stripe.Card{brand: "Visa", last4: "1234"}}}
    end
  end
end
