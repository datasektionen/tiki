defmodule Tiki.Stripe.WebhookListener do
  @moduledoc """
  A simple service that automatically starts a stripe cli listener.

  Should only ever be used in dev, use a real webhook in production.

  Inspired by https://dashbit.co/blog/sdks-with-req-stripe
  """

  use GenServer
  require Logger

  def start_link(opts) do
    {stripe_cli, opts} = Keyword.pop(opts, :stripe_cli, System.find_executable("stripe"))
    {forward_to, opts} = Keyword.pop!(opts, :forward_to)
    opts = Keyword.validate!(opts, [:name, :timeout, :debug, :spawn_opt, :hibernate_after])
    GenServer.start_link(__MODULE__, %{stripe_cli: stripe_cli, forward_to: forward_to}, opts)
  end

  @impl true
  def init(%{stripe_cli: nil}) do
    Logger.warning("""
    Stripe CLI not found

    Run:
        brew install stripe/stripe-cli/stripe

    Or view:
        https://docs.stripe.com/stripe-cli
    """)

    :ignore
  end

  def init(%{stripe_cli: stripe_cli, forward_to: forward_to}) do
    args = [
      "listen",
      "--skip-update",
      "--color",
      "on",
      "--forward-to",
      forward_to
    ]

    port =
      Port.open(
        {:spawn_executable, stripe_cli},
        [
          :binary,
          :stderr_to_stdout,
          line: 2048,
          args: args
        ]
      )

    {:ok, {port, nil}}
  end

  @impl true
  def handle_info({port, {:data, {:eol, line}}}, {port, secret}) do
    Logger.debug(["[stripe] ", line])

    secret =
      case secret do
        nil ->
          case Regex.run(~r/whsec_[a-zA-Z0-9]+/, line) do
            [secret] ->
              Application.put_env(:stripity_stripe, :webhook_secret, secret)
              Logger.info(["[stripe] set secret: ", secret])
              secret

            nil ->
              nil
          end

        secret ->
          secret
      end

    {:noreply, {port, secret}}
  end
end
