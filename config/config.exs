# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

config :tiki,
  ecto_repos: [Tiki.Repo],
  stripe_module: Stripe,
  swish_module: Swish,
  metrics_port: 9001

config :tiki, Tiki.Repo,
  migration_timestamps: [
    type: :naive_datetime_usec
  ]

# Configures the endpoint
config :tiki, TikiWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: TikiWeb.ErrorHTML, json: TikiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Tiki.PubSub,
  live_view: [signing_salt: "FxCBFsEw"]

# Configures metrics prometheus exporter
config :tiki, Tiki.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  metrics_server: :disabled

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :tiki, Tiki.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.3",
  default: [
    args: ~w(
      --input=assets/css/app.css
      --output=./priv/static/assets/app.css
    ),
    cd: Path.expand("../", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# SaladUI use tails to properly merge Tailwind CSS classes
config :tails,
  color_classes: [
    "background",
    "foreground",
    "card",
    "card-foreground",
    "popover",
    "popover-foreground",
    "primary",
    "primary-foreground",
    "secondary",
    "secondary-foreground",
    "muted",
    "muted-foreground",
    "accent",
    "accent-foreground",
    "destructive",
    "destructive-foreground",
    "border",
    "input",
    "ring",
    "chart-1",
    "chart-2",
    "chart-3",
    "chart-4",
    "chart-5"
  ]

config :tiki, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, mail: 10, event_schedule: 10],
  repo: Tiki.Repo

config :fun_with_flags, :persistence,
  adapter: FunWithFlags.Store.Persistent.Ecto,
  repo: Tiki.Repo,
  ecto_table_name: "fun_with_flags_toggles"

config :fun_with_flags, :cache_bust_notifications,
  enabled: true,
  adapter: FunWithFlags.Notifications.PhoenixPubSub,
  client: Tiki.PubSub

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
