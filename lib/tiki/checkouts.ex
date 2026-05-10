defmodule Tiki.Checkouts do
  @moduledoc """
  The Checkouts context.

  You probably don't want to interact with this module directly. Instead, use
  the `Tiki.Orders` module with for example `Tiki.Orders.init_checkout/3`.
  """

  @stripe Application.compile_env(:tiki, :stripe_module)
  @swish Application.compile_env(:tiki, :swish_module)

  require Logger
  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Tiki.Repo

  alias Tiki.Checkouts.StripeCheckout
  alias Tiki.Checkouts.SwishCheckout
  alias Tiki.Orders
  alias Tiki.Orders.Order
  alias Tiki.Stripe

  @doc """
  Creates a stripe payment intent with the stripe API,
  and creates a stripe checkout in the database. Returns the intent.any()

  ## Examples

      iex> create_stripe_payment_intent(%Order{user_id: 1, price: 10000})
      {:ok, %Checkouts.StripeCheckout{}}

      iex> create_stripe_payment_intent(%Order{user_id: 1, price: 0})
      {:error, _}
  """
  def create_stripe_payment_intent(%Order{user_id: user_id, price: price} = order) do
    with {:ok, %Stripe.PaymentIntent{id: intent_id, client_secret: secret}}
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
  def confirm_stripe_payment(%Stripe.PaymentIntent{id: intent_id} = intent) do
    query =
      from stc in StripeCheckout,
        where: stc.payment_intent_id == ^intent_id,
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
      |> Multi.run(:status, fn
        _repo, %{order_checkout: nil} ->
          {:error, "checkout not found"}

        _repo, %{order_checkout: {order, _}} ->
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
    message = sanitize_swish_message(order.event.name)

    with {:ok, swish_request} <-
           @swish.create_payment_request(price, %{
             "message" => message,
             "payeePaymentReference" => order.id |> String.replace("-", "")
           }),
         {:ok, checkout} <-
           create_swish_checkout(
             Map.merge(swish_request, %{user_id: user_id, order_id: order.id})
           ) do
      {:ok, checkout}
    else
      {:error, err} ->
        Logger.error("Swish payment request failed for order #{order.id}: #{inspect(err)}")
        {:error, err}
    end
  end

  # https://developer.swish.nu/api/payment-request/v2
  # allowed characters: a-ö, A-Ö, 0-9, and !?(),.-:;
  # max length: 50 chars

  @swish_allowed_chars Enum.concat([
                         ?a..?z,
                         ?A..?Z,
                         ?0..?9,
                         [?å, ?ä, ?ö, ?Å, ?Ä, ?Ö],
                         [?\s, ?!, ??, ?(, ?), ?,, ?., ?-, ?:, ?;]
                       ])
                       |> MapSet.new()

  defp sanitize_swish_message(message) do
    message
    |> String.graphemes()
    |> Enum.filter(&swish_allowed_char?/1)
    |> Enum.join()
    |> String.trim()
    |> String.slice(0, 50)
  end

  defp swish_allowed_char?(<<c::utf8>>), do: c in @swish_allowed_chars
  defp swish_allowed_char?(_), do: false

  @doc """
  Handles a Swish payment callback by updating the checkout status and transitioning
  the order accordingly. Does not return the order, but broadcasts it over PubSub. Idempotent.

  Handles all terminal Swish statuses: PAID, DECLINED, ERROR, CANCELLED.
  """

  def handle_swish_callback(callback_identifier, "PAID") do
    query = swish_checkout_query(callback_identifier)

    multi =
      Multi.new()
      |> Multi.one(:order_checkout, query)
      |> Multi.run(:status, fn
        _repo, %{order_checkout: nil} ->
          {:error, "checkout not found"}

        _repo, %{order_checkout: {order, _}} ->
          if Order.valid_transition?(order.status, :paid) do
            {:ok, :paid}
          else
            {:error, :invalid_status}
          end
      end)
      |> Multi.run(:swish_checkout, fn _repo, %{order_checkout: {_, swish_checkout}} ->
        update_swish_checkout(swish_checkout, %{status: "PAID"})
      end)
      |> Multi.update(:order, fn %{order_checkout: {order, _}} ->
        Order.changeset(order, %{status: :paid})
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

  def handle_swish_callback(callback_identifier, status)
      when status in ["DECLINED", "ERROR", "CANCELLED"] do
    query = swish_checkout_query(callback_identifier)

    multi =
      Multi.new()
      |> Multi.one(:order_checkout, query)
      |> Multi.run(:swish_checkout, fn
        _repo, %{order_checkout: nil} ->
          {:error, "checkout not found"}

        _repo, %{order_checkout: {_, swish_checkout}} ->
          if swish_checkout.status in Swish.terminal_statuses() do
            {:ok, :already_terminal}
          else
            update_swish_checkout(swish_checkout, %{status: status})
          end
      end)

    case Repo.transaction(multi) do
      {:ok, %{swish_checkout: :already_terminal}} ->
        :ok

      {:ok, %{order_checkout: {order, _}}} ->
        case Orders.maybe_cancel_order(order.id) do
          {:ok, _} -> :ok
          {:error, "order is not cancellable"} -> :ok
          {:error, reason} -> {:error, reason}
        end

      {:error, _, msg, _} ->
        {:error, msg}
    end
  end

  defp swish_checkout_query(callback_identifier) do
    from sc in SwishCheckout,
      where: sc.callback_identifier == ^callback_identifier,
      join: o in assoc(sc, :order),
      select: {o, sc}
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

  defdelegate retrieve_stripe_payment_method(payment_method_id),
    to: Module.concat(@stripe, PaymentMethod),
    as: :retrieve

  defdelegate get_swish_payment_request(id), to: @swish, as: :get_payment_request
  defdelegate get_swish_svg_qr_code!(token), to: @swish, as: :get_svg_qr_code!

  def load_stripe_client_secret!(%StripeCheckout{payment_intent_id: intent_id} = checkout) do
    {:ok, %Stripe.PaymentIntent{client_secret: client_secret}} =
      @stripe.PaymentIntent.retrieve(intent_id)

    Map.put(checkout, :client_secret, client_secret)
  end

  def load_stripe_client_secret!(%Ecto.Association.NotLoaded{} = not_loaded), do: not_loaded
  def load_stripe_client_secret!(nil), do: nil
end
