defmodule Tiki.Orders.CancelWorker do
  @moduledoc """
  Oban worker for cancelling Swish payment requests when an order is cancelled.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  import Ecto.Query, warn: false
  alias Tiki.Checkouts.SwishCheckout
  alias Tiki.Orders
  alias Tiki.Repo

  @swish Application.compile_env(:tiki, :swish_module)

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"swish_id" => swish_id}}) do
    status =
      Repo.one(from sc in SwishCheckout, where: sc.swish_id == ^swish_id, select: sc.status)

    if status in Swish.terminal_statuses() do
      Logger.info(
        "Swish payment #{swish_id} already in terminal state (#{status}), skipping cancellation"
      )

      :ok
    else
      cancel_swish_payment(swish_id)
    end
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
      %{swish_checkout: %{swish_id: swish_id}} ->
        %{"swish_id" => swish_id}
        |> new()
        |> Oban.insert()

      _ ->
        :ok
    end
  end

  defp cancel_swish_payment(swish_id) do
    case @swish.cancel_payment_request(swish_id) do
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
