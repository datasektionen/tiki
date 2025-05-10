defmodule Tiki.Checkouts do
  @moduledoc """
  The Checkouts context.

  You probably don't want to interact with this module directly. Instead, use
  the `Tiki.Orders` module with for example `Tiki.Orders.init_checkout/3`.
  """

  @stripe Application.compile_env(:tiki, :stripe_module)
  @swish Application.compile_env(:tiki, :swish_module)

  import Ecto.Query, warn: false
  alias Tiki.Checkouts.SwishRefund
  alias Ecto.Multi
  alias Tiki.Repo

  alias Tiki.Checkouts.StripeCheckout
  alias Tiki.Checkouts.SwishCheckout
  alias Tiki.Orders
  alias Tiki.Orders.Order

  @doc """
  Creates a stripe payment intent with the stripe API,
  and creates a stripe checkout in the database. Returns the intent.any()

  ## Examples

      iex> create_stripe_payment_intent(%Order{user_id: 1, price: 10000})
      {:ok, %Stripe.PaymentIntent{}}

      iex> create_stripe_payment_intent(%Order{user_id: 1, price: 0})
      {:error, %Stripe.Error{}}
  """
  def create_stripe_payment_intent(%Order{user_id: user_id, price: price} = order) do
    with {:ok,
          %Stripe.PaymentIntent{
            id: intent_id,
            client_secret: secret
          }}
         when not is_nil(secret) <-
           @stripe.PaymentIntent.create(%{
             amount: price * 100,
             currency: "sek",
             metadata: %{tiki_order_id: order.id}
           }),
         {:ok, stripe_checkout} <-
           create_stripe_checkout(%{
             user_id: user_id,
             order_id: order.id,
             price: price * 100,
             payment_intent_id: intent_id
           }) do
      {:ok, Map.put(stripe_checkout, :client_secret, secret)}
    else
      {:error, err} -> {:error, err}
    end
  end

  @doc """
  Confirms a stripe payment intent with the stripe API,
  and updates the stripe checkout in the database. Does not return the order, but
  broadcasts it over PubSub.
  """
  def confirm_stripe_payment(%Stripe.PaymentIntent{} = intent) do
    query =
      from stc in StripeCheckout,
        where: stc.payment_intent_id == ^intent.id,
        join: o in assoc(stc, :order),
        select: {o, stc}

    multi =
      Multi.new()
      |> Multi.one(:order_checkout, query)
      |> Multi.run(:validate_intent, fn _, _ ->
        case intent.status do
          "succeeded" -> {:ok, intent}
          _ -> {:error, :invalid_status}
        end
      end)
      |> Multi.run(:status, fn _repo, %{order_checkout: {order, _}} ->
        if Order.valid_transition?(order.status, :paid) do
          {:ok, :paid}
        else
          {:error, :invalid_status}
        end
      end)
      |> Multi.run(:checkout, fn _repo, %{order_checkout: {_, checkout}} ->
        update_stripe_checkout(checkout, %{
          status: intent.status,
          payment_method_id: intent.payment_method,
          currency: intent.currency
        })
      end)
      |> Multi.update(:order, fn %{order_checkout: {order, _}, status: status} ->
        Order.changeset(order, %{status: status})
      end)

    case Repo.transaction(multi) do
      {:ok, %{order: order}} ->
        Orders.confirm_order(order)

        :ok

      {:error, :status, :invalid_status, _} ->
        :ok

      {:error, _, msg, _} ->
        {:error, msg}
    end
  end

  @doc """
  Creates a Swish payment request with the Swish API,
  and creates a Swish checkout in the database. Returns the request.
  """
  def create_swish_payment_request(%Order{user_id: user_id, price: price} = order) do
    with {:ok, swish_request} <-
           @swish.create_payment_request(price, %{
             "message" => order.event.name |> String.slice(0, 50),
             "payeePaymentReference" => order.id |> String.replace("-", "")
           }),
         {:ok, checkout} <-
           create_swish_checkout(
             Map.merge(swish_request, %{user_id: user_id, order_id: order.id})
           ) do
      {:ok, checkout}
    else
      {:error, err} -> {:error, err}
    end
  end

  @doc """
  Confirms a Swish payment request with a given callback identifier that
  should be recieved from the Swish API. Does not return the order, but
  broadcasts it over PubSub.
  """

  def confirm_swish_payment(id, callback_identifier, status) do
    query =
      from sc in SwishCheckout,
        where: sc.swish_id == ^id and sc.callback_identifier == ^callback_identifier,
        join: o in assoc(sc, :order),
        select: {o, sc}

    multi =
      Multi.new()
      |> Multi.run(:status_paid, fn _, _ ->
        case swish_to_order_status(status) do
          :paid -> {:ok, :paid}
          _ -> {:error, "invalid status: #{status}"}
        end
      end)
      |> Multi.one(:order_checkout, query)
      |> Multi.run(:status, fn
        _repo, %{order_checkout: nil} ->
          {:error, "checkout not found"}

        _repo, %{order_checkout: {order, _}} ->
          to = swish_to_order_status(status)

          if Order.valid_transition?(order.status, to) do
            {:ok, to}
          else
            {:error, :invalid_status}
          end
      end)
      |> Multi.run(:swish_checkout, fn _repo, %{order_checkout: {_, swish_checkout}} ->
        update_swish_checkout(swish_checkout, %{status: status})
      end)
      |> Multi.update(:order, fn %{status: status, order_checkout: {order, _}} ->
        Order.changeset(order, %{status: status})
      end)

    case Repo.transaction(multi) do
      {:ok, %{order: order}} ->
        Orders.confirm_order(order)

        :ok

      {:error, :status, :invalid_status, _} ->
        :ok

      {:error, _, msg, _} ->
        {:error, msg}
    end
  end

  @doc """
  Refunds a Swish payment request. Returns the Swish refund.
  """
  def refund_swish_checkout(%SwishCheckout{} = swish_checkout, amount) do
    case @swish.refund(swish_checkout.swish_id, amount) do
      {:ok, refund} ->
        SwishRefund.changeset(%SwishRefund{swish_checkout_id: swish_checkout.id}, refund)
        |> Repo.insert()

      {:error, resason} ->
        {:error, resason}
    end
  end

  def update_swish_refund(id, callback_identifier, status) do
    multi =
      Multi.new()
      |> Multi.one(
        :data,
        from(sr in SwishRefund,
          where: sr.refund_id == ^id and sr.callback_identifier == ^callback_identifier,
          join: sc in assoc(sr, :swish_checkout),
          join: o in assoc(sc, :order),
          select: %{order: o, refund: sr}
        )
      )
      |> Multi.update(:refund, fn
        %{data: %{refund: refund}} -> SwishRefund.changeset(refund, %{status: status})
        %{data: nil} -> {:error, "could not find refund"}
      end)
      |> Multi.run(:audit, fn _repo, %{data: %{order: order, refund: refund}} ->
        Orders.AuditLog.log(order.id, "order.swish_refund.update", refund)
      end)

    case Repo.transaction(multi) do
      {:ok, _} ->
        :ok

      {:error, :data, :not_found, _} ->
        {:error, "Swish refund not found"}

      {:error, _, msg, _} ->
        {:error, msg}
    end
  end

  defp create_stripe_checkout(attrs) do
    %StripeCheckout{}
    |> StripeCheckout.changeset(attrs)
    |> Repo.insert()
  end

  defp update_stripe_checkout(%StripeCheckout{} = stripe_checkout, attrs) do
    stripe_checkout
    |> StripeCheckout.changeset(attrs)
    |> Repo.update()
  end

  defp create_swish_checkout(attrs) do
    %SwishCheckout{}
    |> SwishCheckout.changeset(attrs)
    |> Repo.insert()
  end

  defp update_swish_checkout(%SwishCheckout{} = swish_checkout, attrs) do
    swish_checkout
    |> SwishCheckout.changeset(attrs)
    |> Repo.update()
  end

  defp swish_to_order_status("PAID"), do: :paid
  defp swish_to_order_status(status) when is_binary(status), do: :cancelled

  defdelegate retrieve_stripe_payment_method(payment_method_id),
    to: Module.concat(@stripe, PaymentMethod),
    as: :retrieve

  defdelegate get_swish_payment_request(id), to: @swish, as: :get_payment_request
  defdelegate get_swisg_svg_qr_code!(token), to: @swish, as: :get_svg_qr_code!

  def load_stripe_client_secret!(%StripeCheckout{payment_intent_id: intent_id} = checkout) do
    {:ok, %Stripe.PaymentIntent{client_secret: client_secret}} =
      @stripe.PaymentIntent.retrieve(intent_id)

    Map.put(checkout, :client_secret, client_secret)
  end

  def load_stripe_client_secret!(%Ecto.Association.NotLoaded{} = not_loaded), do: not_loaded
  def load_stripe_client_secret!(nil), do: nil
end
