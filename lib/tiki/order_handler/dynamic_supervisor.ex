defmodule Tiki.OrderHandler.DynamicSupervisor do
  @moduledoc false

  use DynamicSupervisor

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_worker(event_id) do
    DynamicSupervisor.start_child(__MODULE__, {Tiki.OrderHandler.Worker, event_id})
  end

  @impl true
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
