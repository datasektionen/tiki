defmodule Tiki.Support.StripeMock do
  defmodule PaymentIntent do
    alias Stripe.PaymentIntent

    def create(%{amount: 0}) do
      id = Ecto.UUID.generate()

      {:error, %Stripe.ApiErrors{message: "forbidden", payment_intent: "pi_#{id}"}}
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
    alias Stripe.PaymentMethod

    def retrieve("invalid") do
      id = Ecto.UUID.generate()

      {:error, %Stripe.ApiErrors{message: "forbidden", payment_intent: "pi_#{id}"}}
    end

    def retrieve(id) do
      {:ok, %PaymentMethod{id: id}}
    end
  end
end
