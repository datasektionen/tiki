defmodule Tiki.CheckoutsTest do
  use Tiki.DataCase

  alias Tiki.Checkouts
  alias Tiki.Orders

  describe "stripe_checkouts" do
    import Tiki.CheckoutsFixtures

    test "create_stripe_payment_intent/1 with a order creates a stripe payment intent" do
      order = Tiki.OrdersFixtures.order_fixture()

      assert {:ok, %Checkouts.StripeCheckout{} = checkout} =
               Checkouts.create_stripe_payment_intent(order)

      assert not is_nil(checkout.client_secret)

      assert Map.drop(checkout, [:client_secret]) ==
               Tiki.Repo.get!(Checkouts.StripeCheckout, checkout.id)
    end

    test "create_stripe_payment_intent/1 with an stripe API error returns an error" do
      order = Tiki.OrdersFixtures.order_fixture(%{price: 0})

      assert {:error, %Stripe.ApiErrors{}} = Checkouts.create_stripe_payment_intent(order)
    end

    test "confirm_stripe_payment/1 works with a valid stripe payment" do
      order = Tiki.OrdersFixtures.order_fixture(%{status: :checkout})

      Orders.subscribe_to_order(order.id)

      assert {:ok, %Checkouts.StripeCheckout{} = checkout} =
               Checkouts.create_stripe_payment_intent(order)

      payment_intent = %Stripe.PaymentIntent{id: checkout.payment_intent_id, status: "succeeded"}

      assert :ok = Checkouts.confirm_stripe_payment(payment_intent)

      assert_received {:paid, paid_order}

      paid_order =
        Tiki.Repo.preload(paid_order, [:stripe_checkout, :swish_checkout, :tickets, :user, :event])

      assert order.id == paid_order.id
      assert paid_order.status == :paid
      assert Orders.get_order!(order.id) == paid_order
    end

    test "confirm_stripe_payment/1 does nothing if the payment is already confirmed" do
      order = Tiki.OrdersFixtures.order_fixture(%{status: :checkout})

      Orders.subscribe_to_order(order.id)

      assert {:ok, %Checkouts.StripeCheckout{} = checkout} =
               Checkouts.create_stripe_payment_intent(order)

      payment_intent = %Stripe.PaymentIntent{id: checkout.payment_intent_id, status: "succeeded"}

      assert :ok = Checkouts.confirm_stripe_payment(payment_intent)

      assert_received {:paid, paid_order}

      paid_order =
        Tiki.Repo.preload(paid_order, [:stripe_checkout, :swish_checkout, :tickets, :user, :event])

      assert Orders.get_order!(order.id) == paid_order

      assert :ok = Checkouts.confirm_stripe_payment(payment_intent)
      assert Orders.get_order!(order.id) == paid_order
    end

    test "confirm_stripe_payment/1 returns an error on invalid payment" do
      order = Tiki.OrdersFixtures.order_fixture()

      assert {:ok, %Checkouts.StripeCheckout{} = checkout} =
               Checkouts.create_stripe_payment_intent(order)

      payment_intent = %Stripe.PaymentIntent{id: checkout.payment_intent_id, status: "failed"}

      assert {:error, :invalid_status} = Checkouts.confirm_stripe_payment(payment_intent)
    end

    test "retrieve_stripe_payment_method/1 retrieves a stripe payment method" do
      id = Ecto.UUID.generate()

      {:ok, %Stripe.PaymentMethod{id: ^id}} =
        Checkouts.retrieve_stripe_payment_method(id)
    end

    test "load_stripe_client_secret!/1 loads a stripe client secret for a payment intent" do
      id = Ecto.UUID.generate()
      stripe_checkout = stripe_checkout_fixture(%{payment_intent_id: id})

      assert %Checkouts.StripeCheckout{payment_intent_id: ^id} =
               checkout = Checkouts.load_stripe_client_secret!(stripe_checkout)

      assert not is_nil(checkout.client_secret)
    end

    test "load_stripe_client_secret!/1 returns an unchanged %Ecto.Association.NotLoaded{}" do
      non_loaded = %Ecto.Association.NotLoaded{}

      assert non_loaded == Checkouts.load_stripe_client_secret!(non_loaded)
    end

    test "load_stripe_client_secret!/1 returns nothing on nil" do
      assert is_nil(Checkouts.load_stripe_client_secret!(nil))
    end

    test "create_swish_payment_request/1 with a valid order creates a Swish checkout" do
      order = Tiki.OrdersFixtures.order_fixture()

      assert {:ok, %Checkouts.SwishCheckout{} = checkout} =
               Checkouts.create_swish_payment_request(order)

      assert checkout.user_id == order.user_id
      assert checkout.order_id == order.id
      assert is_binary(checkout.swish_id)
      assert is_binary(checkout.callback_identifier)
      assert is_binary(checkout.token)
    end

    test "create_swish_payment_request/1 with invalid order returns an error" do
      order = Tiki.OrdersFixtures.order_fixture(price: 0)

      assert {:error, _} = Checkouts.create_swish_payment_request(order)
    end

    test "confirm_swish_payment/2 works with valid swish callback data" do
      order = Tiki.OrdersFixtures.order_fixture(%{status: :checkout})

      Orders.subscribe_to_order(order.id)

      assert {:ok, %Checkouts.SwishCheckout{} = checkout} =
               Checkouts.create_swish_payment_request(order)

      assert :ok = Checkouts.confirm_swish_payment(checkout.callback_identifier, "PAID")

      assert_received {:paid, paid_order}

      paid_order =
        Tiki.Repo.preload(paid_order, [:stripe_checkout, :swish_checkout, :tickets, :user, :event])

      assert order.id == paid_order.id
      assert paid_order.status == :paid
      assert Orders.get_order!(order.id) == paid_order
    end

    test "confirm_swish_payment/2 does nothing if the payment is already confirmed" do
      order = Tiki.OrdersFixtures.order_fixture(%{status: :checkout})

      Orders.subscribe_to_order(order.id)

      assert {:ok, %Checkouts.SwishCheckout{} = checkout} =
               Checkouts.create_swish_payment_request(order)

      assert :ok = Checkouts.confirm_swish_payment(checkout.callback_identifier, "PAID")

      assert_received {:paid, paid_order}

      paid_order =
        Tiki.Repo.preload(paid_order, [:stripe_checkout, :swish_checkout, :tickets, :user, :event])

      assert Orders.get_order!(order.id) == paid_order

      assert :ok = Checkouts.confirm_swish_payment(checkout.callback_identifier, "PAID")
      assert Orders.get_order!(order.id) == paid_order
    end

    test "confirm_swish_payment/2 returns an error on non-existing checkout" do
      order = Tiki.OrdersFixtures.order_fixture()

      assert {:ok, %Checkouts.SwishCheckout{}} =
               Checkouts.create_swish_payment_request(order)

      assert {:error, message} = Checkouts.confirm_swish_payment("bogus", "PAID")
      assert message == "checkout not found"
    end

    test "confirm_swish_payment/2 returns an error on invalid payment" do
      order = Tiki.OrdersFixtures.order_fixture()

      assert {:ok, %Checkouts.SwishCheckout{} = checkout} =
               Checkouts.create_swish_payment_request(order)

      assert {:error, message} =
               Checkouts.confirm_swish_payment(checkout.callback_identifier, "DECLINED")

      assert message == "invalid status: DECLINED"
    end
  end
end
