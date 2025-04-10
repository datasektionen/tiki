defmodule Tiki.PurchaseMonitor do
  @moduledoc """
  A process that tracks pending orders and
  cancels them if they don't get purchased in time.

  This also ensures that we don't "leak"/lose tickets if
  anything goes wrong.
  """
  use GenServer
  alias Tiki.Orders
  alias Tiki.Orders.Order

  # 10 minutes
  @order_timeout 60_000 * 10

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def monitor(%Order{} = order) do
    GenServer.call(__MODULE__, {:monitor, order})
  end

  def init(_) do
    {:ok, %{orders: %{}}}
  end

  def handle_call({:monitor, order}, _, %{orders: orders} = state) do
    Process.send_after(self(), {:timeout, order.id}, @order_timeout)
    {:reply, :ok, %{state | orders: Map.put(orders, order.id, order)}}
  end

  def handle_info({:timeout, order_id}, %{orders: orders} = state) do
    if Map.get(orders, order_id) do
      Orders.maybe_cancel_order(order_id)
    end

    {:noreply, %{state | orders: Map.delete(orders, order_id)}}
  end

  @doc """
  Returns the configured time in minutes until an order is timed out.
  """
  def timeout_minutes do
    div(@order_timeout, 60_000)
  end
end
