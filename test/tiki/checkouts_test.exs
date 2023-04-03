defmodule Tiki.CheckoutsTest do
  use Tiki.DataCase

  alias Tiki.Checkouts

  describe "stripe_checkouts" do
    alias Tiki.Checkouts.StripeCheckout

    import Tiki.CheckoutsFixtures

    @invalid_attrs %{currency: nil, payment_intent_id: nil, payment_method_id: nil, status: nil}

    test "list_stripe_checkouts/0 returns all stripe_checkouts" do
      stripe_checkout = stripe_checkout_fixture()
      assert Checkouts.list_stripe_checkouts() == [stripe_checkout]
    end

    test "get_stripe_checkout!/1 returns the stripe_checkout with given id" do
      stripe_checkout = stripe_checkout_fixture()
      assert Checkouts.get_stripe_checkout!(stripe_checkout.id) == stripe_checkout
    end

    test "create_stripe_checkout/1 with valid data creates a stripe_checkout" do
      valid_attrs = %{
        currency: "some currency",
        payment_intent_id: "some payment_intent_id",
        payment_method_id: "some payment_method_id",
        status: "some status"
      }

      assert {:ok, %StripeCheckout{} = stripe_checkout} =
               Checkouts.create_stripe_checkout(valid_attrs)

      assert stripe_checkout.currency == "some currency"
      assert stripe_checkout.payment_intent_id == "some payment_intent_id"
      assert stripe_checkout.payment_method_id == "some payment_method_id"
      assert stripe_checkout.status == "some status"
    end

    test "create_stripe_checkout/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Checkouts.create_stripe_checkout(@invalid_attrs)
    end

    test "update_stripe_checkout/2 with valid data updates the stripe_checkout" do
      stripe_checkout = stripe_checkout_fixture()

      update_attrs = %{
        currency: "some updated currency",
        payment_intent_id: "some updated payment_intent_id",
        payment_method_id: "some updated payment_method_id",
        status: "some updated status"
      }

      assert {:ok, %StripeCheckout{} = stripe_checkout} =
               Checkouts.update_stripe_checkout(stripe_checkout, update_attrs)

      assert stripe_checkout.currency == "some updated currency"
      assert stripe_checkout.payment_intent_id == "some updated payment_intent_id"
      assert stripe_checkout.payment_method_id == "some updated payment_method_id"
      assert stripe_checkout.status == "some updated status"
    end

    test "update_stripe_checkout/2 with invalid data returns error changeset" do
      stripe_checkout = stripe_checkout_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Checkouts.update_stripe_checkout(stripe_checkout, @invalid_attrs)

      assert stripe_checkout == Checkouts.get_stripe_checkout!(stripe_checkout.id)
    end

    test "delete_stripe_checkout/1 deletes the stripe_checkout" do
      stripe_checkout = stripe_checkout_fixture()
      assert {:ok, %StripeCheckout{}} = Checkouts.delete_stripe_checkout(stripe_checkout)

      assert_raise Ecto.NoResultsError, fn ->
        Checkouts.get_stripe_checkout!(stripe_checkout.id)
      end
    end

    test "change_stripe_checkout/1 returns a stripe_checkout changeset" do
      stripe_checkout = stripe_checkout_fixture()
      assert %Ecto.Changeset{} = Checkouts.change_stripe_checkout(stripe_checkout)
    end
  end
end
