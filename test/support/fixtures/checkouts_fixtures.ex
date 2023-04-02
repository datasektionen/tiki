defmodule Tiki.CheckoutsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tiki.Checkouts` context.
  """

  @doc """
  Generate a stripe_checkout.
  """
  def stripe_checkout_fixture(attrs \\ %{}) do
    {:ok, stripe_checkout} =
      attrs
      |> Enum.into(%{
        currency: "some currency",
        payment_intent_id: "some payment_intent_id",
        payment_method_id: "some payment_method_id",
        status: "some status"
      })
      |> Tiki.Checkouts.create_stripe_checkout()

    stripe_checkout
  end
end
