defmodule Tiki.Workers.OrderTimeoutWorker do
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [fields: [:args, :worker], states: [:available, :scheduled, :executing]]

  alias Tiki.Orders

  # 10 minutes. TODO: have this be configurable?
  @order_timeout_seconds 10 * 60

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"order_id" => order_id}}) do
    Orders.maybe_cancel_order(order_id)
    :ok
  end

  @doc """
  Schedules a timeout job for the given order. The order will be cancelled
  if it has not been paid within #{div(@order_timeout_seconds, 60)} minutes.
  """
  def schedule(%Tiki.Orders.Order{} = order) do
    %{order_id: order.id}
    |> new(scheduled_at: DateTime.add(DateTime.utc_now(), @order_timeout_seconds))
    |> Oban.insert()
  end

  @doc """
  Returns the configured timeout in minutes.
  """
  def timeout_minutes, do: div(@order_timeout_seconds, 60)
end
