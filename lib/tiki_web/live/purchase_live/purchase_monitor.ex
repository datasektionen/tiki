defmodule TikiWeb.PurchaseLive.PurchaseMonitor do
  use GenServer

  alias Tiki.Orders

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def monitor(pid, meta) do
    GenServer.call(__MODULE__, {:monitor, pid, meta})
  end

  def init(_) do
    {:ok, %{views: %{}}}
  end

  def handle_call({:monitor, pid, meta}, _, %{views: views} = state) do
    Process.monitor(pid)
    Process.send_after(self(), {:timeout, pid, meta}, 120_000)
    {:reply, :ok, %{state | views: Map.put(views, pid, meta)}}
  end

  def handle_info({:timeout, view_pid, meta}, state) do
    case maybe_cancel_reservation(meta) do
      :cancelled -> send(view_pid, {:timeout, meta})
      :not_cancelled -> nil
    end

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, view_pid, _reason}, state) do
    {meta, new_views} = Map.pop(state.views, view_pid)
    maybe_cancel_reservation(meta)
    {:noreply, %{state | views: new_views}}
  end

  defp maybe_cancel_reservation(%{order: order}) do
    case Orders.maybe_cancel_reservation(order) do
      {:ok, _} -> :cancelled
      {:error, _} -> :not_cancelled
    end
  end
end
