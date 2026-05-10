defmodule Tiki.Orders.CancelWorker do
  @moduledoc """
  Oban worker for cancelling Swish payment requests when an order is cancelled.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  alias Tiki.Orders

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"swish_id" => swish_id}}) do
    cancel_swish_payment(swish_id)
  end

  def perform(%Oban.Job{args: %{}}) do
    :ok
  end

  @doc """
  Enqueues a Swish payment cancellation job for the given order, if the order has a Swish checkout.
  """
  def enqueue(order_id) do
    order = Orders.get_order!(order_id)

    case order do
      %{swish_checkout: %{id: checkout_id}} ->
        %{"swish_id" => checkout_id}
        |> new()
        |> Oban.insert()

      _ ->
        :ok
    end
  end

  defp cancel_swish_payment(swish_id) do
    swish_module = Application.get_env(:tiki, :swish_module)

    case swish_module.cancel_payment_request(swish_id) do
      {:ok, _response} ->
        Logger.info("Successfully cancelled Swish payment: #{swish_id}")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to cancel Swish payment #{swish_id}: #{inspect(reason)}")
        # Retry the job by returning error
        {:error, reason}
    end
  end
end
