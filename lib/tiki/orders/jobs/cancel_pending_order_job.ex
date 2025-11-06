defmodule Tiki.Orders.Jobs.CancelPendingOrderJob do
  @moduledoc """
  Oban job to cancel pending orders that have exceeded their timeout window.

  Orders are automatically cancelled if not paid within 10 minutes of creation.
  This job is scheduled when an order is created and runs after the timeout period.

  ## Job Arguments

  - `order_id` - UUID of the order to cancel
  """

  use Oban.Worker,
    queue: :order_cancellations,
    max_attempts: 5

  require Logger
  alias Tiki.Orders

  @timeout_minutes 10

  @doc """
  Schedule a job to cancel an order after the timeout period.

  Called when an order is created. The job will run after 10 minutes.
  """
  def schedule_cancellation(order_id) do
    %{"order_id" => order_id}
    |> __MODULE__.new(schedule_in: {@timeout_minutes, :minutes})
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"order_id" => order_id}}) do
    Logger.info("Attempting to cancel pending order: #{order_id}")

    case Orders.maybe_cancel_order(order_id, :timeout) do
      {:ok, _order} ->
        Logger.info("Successfully cancelled pending order: #{order_id}")
        :ok

      {:error, "order not found, nothing to cancel"} ->
        Logger.warning("Order not found for cancellation: #{order_id}")
        :ok

      {:error, "order is not cancellable"} ->
        # Order was already paid or cancelled (normal case)
        Logger.debug("Order already paid or cancelled: #{order_id}")
        :ok

      {:error, reason} ->
        # Unexpected error, retry
        Logger.error("Failed to cancel order #{order_id}: #{reason}")
        {:error, reason}
    end
  end

  def get_timeout_minutes, do: @timeout_minutes
end
