defmodule Tiki.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      TikiWeb.Telemetry,
      # Start the Ecto repository
      Tiki.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Tiki.PubSub},
      Tiki.Presence,
      # Start Finch
      {Finch, name: Tiki.Finch},
      TikiWeb.EventLive.PurchaseMonitor,
      # TODO: Wrap this in a supervisor that restarts the worker, and
      # does not crash the app if the OIDC provider is down
      {Oidcc.ProviderConfiguration.Worker,
       %{
         issuer: Application.fetch_env!(:tiki, Oidcc)[:issuer],
         name: Tiki.OpenIdConfigurationProvider,
         provider_configuration_opts: %{
           quirks: %{
             allow_unsafe_http: true
           }
         }
       }},
      # Start the Endpoint (http/https)
      TikiWeb.Endpoint

      # Start a worker by calling: Tiki.Worker.start_link(arg)
      # {Tiki.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tiki.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TikiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
