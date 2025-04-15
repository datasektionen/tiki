defmodule Tiki.CheckoutsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tiki.Checkouts` context.
  """

  @doc """
  Generate a stripe_checkout.
  """
  def stripe_checkout_fixture(attrs \\ %{}) do
    user = Tiki.AccountsFixtures.user_fixture()
    order = Tiki.OrdersFixtures.order_fixture(%{user_id: user.id, price: 100})

    {:ok, stripe_checkout} =
      attrs
      |> Enum.into(%{
        user_id: user.id,
        order_id: order.id,
        currency: "some currency",
        payment_intent_id: "some payment_intent_id",
        payment_method_id: "some payment_method_id",
        status: "some status"
      })
      |> create_stripe_checkout()

    stripe_checkout
  end

  @doc """
  Generate a swish_checkout.
  """
  def swish_checkout_fixture(attrs \\ %{}) do
    user = Tiki.AccountsFixtures.user_fixture()
    order = Tiki.OrdersFixtures.order_fixture(%{user_id: user.id, price: 100})

    {:ok, swish_checkout} =
      attrs
      |> Enum.into(%{
        user_id: user.id,
        order_id: order.id,
        swish_id: "some swish_id",
        callback_identifier: "some callback_identifier",
        token: "some token"
      })
      |> create_swish_checkout()

    swish_checkout
  end

  alias Tiki.Checkouts.StripeCheckout
  alias Tiki.Checkouts.SwishCheckout

  def create_stripe_checkout(attrs \\ %{}) do
    %StripeCheckout{}
    |> StripeCheckout.changeset(attrs)
    |> Tiki.Repo.insert(returning: [:id])
  end

  def create_swish_checkout(attrs \\ %{}) do
    %SwishCheckout{}
    |> SwishCheckout.changeset(attrs)
    |> Tiki.Repo.insert(returning: [:id])
  end
end
