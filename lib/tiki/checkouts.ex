defmodule Tiki.Checkouts do
  @moduledoc """
  The Checkouts context.
  """

  @stripe Application.compile_env(:tiki, :stripe_module)
  @swish Application.compile_env(:tiki, :swish_module)

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Tiki.Repo

  alias Tiki.Checkouts.StripeCheckout
  alias Tiki.Checkouts.SwishCheckout
  alias Tiki.Orders
  alias Tiki.Orders.Order
  alias Tiki.Tickets

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
  Updates a swish_checkout.

  ## Examples

      iex> update_swish_checkout(stripe_checkout, %{field: new_value})
      {:ok, %StripeCheckout{}}

      iex> update_swish_checkout(stripe_checkout, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_swish_checkout(%SwishCheckout{} = swish_checkout, attrs) do
    swish_checkout
    |> SwishCheckout.changeset(attrs)
    |> Repo.update()
  end

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
             currency: "sek"
           }),
         {:ok, stripe_ceckout} <-
           create_stripe_checkout(%{
             user_id: user_id,
             order_id: order.id,
             price: price * 100,
             payment_intent_id: intent_id
           }) do
      {:ok, Map.put(stripe_ceckout, :client_secret, secret)}
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
        if order.status != :pending do
          {:error, :already_finished}
        else
          # TODO: convert to status
          {:ok, :paid}
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
        Orders.broadcast(
          order.event_id,
          {:tickets_updated, Tickets.get_availible_ticket_types(order.event_id)}
        )

        Orders.broadcast_order(order.id, :paid, order)

        :ok

      {:error, :status, :already_finished, _} ->
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
    with {:ok, swish_request} <- @swish.create_payment_request(price),
         {:ok, checkout} <-
           create_swish_checkout(
             Map.merge(swish_request, %{user_id: user_id, order_id: order.id})
           ) do
      {:ok, checkout}
    else
      {:error, err} -> {:error, err}
    end
  end

  def confirm_swish_payment(callback_identifier, status) do
    query =
      from sc in SwishCheckout,
        where: sc.callback_identifier == ^callback_identifier,
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
          if order.status != :pending do
            {:error, :already_finished}
          else
            {:ok, swish_to_order_status(status)}
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
        Orders.broadcast(
          order.event_id,
          {:tickets_updated, Tickets.get_availible_ticket_types(order.event_id)}
        )

        Orders.broadcast_order(order.id, :paid, order)

        :ok

      {:error, :status, :already_finished, _} ->
        :ok

      {:error, _, msg, _} ->
        {:error, msg}
    end
  end

  defp swish_to_order_status("PAID"), do: :paid
  defp swish_to_order_status(status) when is_binary(status), do: :cancelled

  def retrive_stripe_payment_method(payment_method_id) do
    @stripe.PaymentMethod.retrieve(payment_method_id)
  end

  def load_stripe_client_secret!(%StripeCheckout{payment_intent_id: intent_id} = checkout) do
    {:ok, %Stripe.PaymentIntent{client_secret: client_secret}} =
      @stripe.PaymentIntent.retrieve(intent_id)

    Map.put(checkout, :client_secret, client_secret)
  end

  def load_stripe_client_secret!(%Ecto.Association.NotLoaded{} = not_loaded), do: not_loaded
  def load_stripe_client_secret!(nil), do: nil
end
