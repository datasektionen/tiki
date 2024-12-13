import Config

# Configure your database
config :tiki, Tiki.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: System.get_env("POSTGRES_DB", "tiki_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :tiki, Tiki.Swish,
  api_url: "https://staging.getswish.pub.tds.tieto.com/swish-cpcapi/api",
  cert: System.get_env("SWISH_CERT") |> Base.decode64!(),
  key: System.get_env("SWISH_PRIVATE_KEY") |> Base.decode64!(),
  merchant_number: System.get_env("SWISH_MERCHANT_NUMBER"),
  callback_url: System.get_env("SWISH_CALLBACK_URL")

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with esbuild to bundle .js and .css sources.
config :tiki, TikiWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "cVqPQsYKwarX0n6VtPvogLYWyonqal69S6+MiHH8bw4al77hR99mQ96pJX+eiBx5",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.
config :tiki, TikiWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/tiki_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :tiki, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Config for Stripe
config :stripity_stripe,
  api_key: System.get_env("STRIPE_API_KEY"),
  webhook_secret: System.get_env("STRIPE_WEBHOOK_SECRET")

# Path to install SaladUI components
config :salad_ui, components_path: Path.join(File.cwd!(), "lib/tiki_web/components")

config :tiki, Oidcc,
  # issuer: "http://localhost:7005/op",
  issuer: "https://sso.datasektionen.se/op",
  client_id: System.get_env("OIDC_CLIENT_ID"),
  client_secret: System.get_env("OIDC_CLIENT_SECRET")

config :tiki, Oidcc.ProviderConfiguration,
  issuer: "https://sso.datasektionen.se/op",
  provider_configuration_opts: %{
    quirks: %{
      allow_unsafe_http: true
    }
  }

# S3 config
config :tiki, Tiki.S3,
  bucket: System.get_env("S3_BUCKET_NAME"),
  region: System.get_env("AWS_REGION"),
  endpoint_url: System.get_env("AWS_ENDPOINT_URL_S3"),
  endpoint_frontend_url: System.get_env("AWS_FRONTEND_ENDPOINT_URL_S3"),
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY")

# Imgproxy config
config :imgproxy,
  key: System.get_env("IMGPROXY_KEY"),
  salt: System.get_env("IMGPROXY_SALT"),
  prefix: System.get_env("IMAGE_FRONTEND_URL")
