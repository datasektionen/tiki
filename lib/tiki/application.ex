defmodule Tiki.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    oidc_config =
      Application.get_env(:tiki, Oidcc.ProviderConfiguration, [])
      |> Enum.into(%{name: Tiki.OpenIdConfigurationProvider, backoff_type: :exponential})

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
      # Start the Endpoint (http/https)
      TikiWeb.Endpoint,
      # Start the OIDC provider configuration worker (fetches the OIDC connect configuration)
      {Oidcc.ProviderConfiguration.Worker, oidc_config},
      # Start processes required for order handling
      Tiki.OrderHandler.Supervisor,
      Tiki.PurchaseMonitor,
      Tiki.Pls
    ]

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
