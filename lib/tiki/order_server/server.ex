defmodule Tiki.OrderServer.Server do
  use Supervisor

  alias Tiki.OrderServer

  @registry :event_registry
  @subscriber_registry :event_subscriber_registry

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      {OrderServer.Supervisor, []},
      {Registry, [keys: :unique, name: @registry]},
      {Registry, [keys: :duplicate, name: @subscriber_registry]}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]

    Supervisor.init(children, opts)
  end
end
