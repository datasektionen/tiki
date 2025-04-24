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

    oban_config = Application.fetch_env!(:tiki, Oban)
    metrics_port = Application.get_env(:tiki, :metrics_port, 9001)

    children =
      [
        # Start the PromEx metrics exporter and telemetry
        Tiki.PromEx,
        # Start the Ecto repository
        Tiki.Repo,
        # Start Oban
        {Oban, oban_config},
        # Start the PubSub system
        {Phoenix.PubSub, name: Tiki.PubSub},
        Tiki.Presence,
        # Start Finch
        {Finch, name: Tiki.Finch},
        # Start the Endpoint (http/https)
        TikiWeb.Endpoint,
        # Start the PromEx plug endpoint
        {Bandit, plug: TikiWeb.MetricsPlug, port: metrics_port},
        # Start the OIDC provider configuration worker (fetches the OIDC connect configuration)
        {Oidcc.ProviderConfiguration.Worker, oidc_config},
        # Start processes required for order handling
        Tiki.OrderHandler.Supervisor,
        Tiki.PurchaseMonitor,
        Tiki.Pls
      ] ++ stripe_webhook_listener()

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

  defp stripe_webhook_listener do
    if Mix.env() == :dev do
      port = Application.fetch_env!(:tiki, TikiWeb.Endpoint)[:http][:port]
      [{Tiki.Stripe.WebhookListener, forward_to: "http://localhost:#{port}/stripe/webhook"}]
    else
      []
    end
  end
end
