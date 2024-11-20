defmodule Tiki.Checkouts do
  @moduledoc """
  The Checkouts context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Tiki.Swish
  alias Tiki.Repo

  alias Tiki.Checkouts.StripeCheckout
  alias Tiki.Checkouts.SwishCheckout

  @doc """
  Returns the list of stripe_checkouts.

  ## Examples

      iex> list_stripe_checkouts()
      [%StripeCheckout{}, ...]

  """
  def list_stripe_checkouts do
    Repo.all(StripeCheckout)
  end

  @doc """
  Gets a single stripe_checkout.

  Raises `Ecto.NoResultsError` if the Stripe checkout does not exist.

  ## Examples

      iex> get_stripe_checkout!(123)
      %StripeCheckout{}

      iex> get_stripe_checkout!(456)
      ** (Ecto.NoResultsError)

  """
  def get_stripe_checkout!(id), do: Repo.get!(StripeCheckout, id)

  @doc """
  Creates a stripe_checkout.

  ## Examples

      iex> create_stripe_checkout(%{field: value})
      {:ok, %StripeCheckout{}}

      iex> create_stripe_checkout(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_stripe_checkout(attrs \\ %{}) do
    %StripeCheckout{}
    |> StripeCheckout.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a stripe_checkout.

  ## Examples

      iex> update_stripe_checkout(stripe_checkout, %{field: new_value})
      {:ok, %StripeCheckout{}}

      iex> update_stripe_checkout(stripe_checkout, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_stripe_checkout(%StripeCheckout{} = stripe_checkout, attrs) do
    stripe_checkout
    |> StripeCheckout.changeset(attrs)
    |> Repo.update()
  end

  def create_swish_checkout(attrs \\ %{}) do
    %SwishCheckout{}
    |> SwishCheckout.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a stripe payment intent with the stripe API,
  and creates a stripe checkout in the database. Returns the intent.any()

  ## Examples

      iex> create_stripe_payment_intent(1, 1, 10000)
      {:ok, %Stripe.PaymentIntent{}}

      iex> create_stripe_payment_intent(1, 1, 10000)
      {:error, %Stripe.Error{}}
  """
  def create_stripe_payment_intent(order_id, user_id, price) do
    with {:ok, intent} <-
           Stripe.PaymentIntent.create(%{
             amount: price * 100,
             currency: "sek"
           }),
         {:ok, _stripe_ceckout} <-
           create_stripe_checkout(%{
             user_id: user_id,
             order_id: order_id,
             price: price * 100,
             payment_intent_id: intent.id
           }) do
      {:ok, intent}
    else
      {:error, err} -> {:error, err}
    end
  end

  @doc """
  Confirms a stripe payment intent with the stripe API,
  and updates the stripe checkout in the database. Returns the order.

  ## Examples

      iex> confirm_stripe_payment("pi_1H9Z2pJZ2Z2Z2Z2Z2Z2Z2Z2Z2")
      {:ok, %Order{}}

      iex> confirm_stripe_payment("pi_1H9Z2pJZ2Z2Z2Z2Z2Z2Z2Z2Z2")
      {:error, "Order not found"}

      iex> confirm_stripe_payment("pi_1H9Z2pJZ2Z2Z2Z2Z2Z2Z2Z2Z2")
      {:error, "Payment intent status is not succeeded"}
  """
  def confirm_stripe_payment(intent_id) do
    query =
      from stc in StripeCheckout,
        where: stc.payment_intent_id == ^intent_id,
        join: o in assoc(stc, :order),
        select: o

    with {:ok,
          %Stripe.PaymentIntent{
            status: status,
            id: ^intent_id,
            currency: currency,
            payment_method: pm
          }} <- Stripe.PaymentIntent.retrieve(intent_id, %{}),
         checkout <- Repo.get_by!(StripeCheckout, payment_intent_id: intent_id),
         {:ok, _} <-
           update_stripe_checkout(checkout, %{
             status: status,
             payment_method_id: pm,
             currency: currency
           }) do
      if status == "succeeded" do
        case Repo.one(query) do
          nil -> {:error, "Order not found"}
          order -> {:ok, order}
        end
      else
        {:error, "Payment intent status is not succeeded"}
      end
    else
      {:error, err} -> {:error, err}
    end
  end

  @doc """
  Creates a Swish payment request with the Swish API,
  and creates a Swish checkout in the database. Returns the request.
  """
  def create_swish_payment_request(order_id, user_id, price) do
    with {:ok, swish_request} <- Swish.create_payment_request(price),
         {:ok, checkout} <-
           create_swish_checkout(
             Map.merge(swish_request, %{user_id: user_id, order_id: order_id})
           ) do
      {:ok, checkout}
    else
      {:error, err} -> {:error, err}
    end
  end

  def confirm_swish_payment(callback_identifier) do
    query =
      from sc in SwishCheckout,
        where: sc.callback_identifier == ^callback_identifier,
        join: o in assoc(sc, :order),
        select: {o, sc}

    Multi.new()
    |> Multi.one(:order_checkout, query)
    |> Multi.run(:confirm_payment, fn _repo, %{order_checkout: {order, checkout}} ->
      if order.status != :pending do
        {:error, "Order is not pending"}
      else
        status = swish_to_order_status(checkout.status)
      end
    end)
  end

  defp swish_to_order_status("PAID"), do: :paid
  defp swish_to_order_status(_status) when is_binary(_status), do: :cancelled
end
