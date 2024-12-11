defmodule Tiki.OrderHandler.Supervisor do
  @moduledoc false

  use Supervisor

  alias Tiki.OrderHandler

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      {OrderHandler.DynamicSupervisor, []},
      {Registry, keys: :unique, name: Tiki.OrderHandler.Registry}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
