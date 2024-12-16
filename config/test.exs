import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

config :tiki,
  stripe_module: Tiki.Support.StripeMock,
  swish_module: Tiki.Support.SwishMock

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :tiki, Tiki.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "tiki_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :tiki, Swish,
  api_url: "https://staging.getswish.pub.tds.tieto.com/swish-cpcapi/api",
  cacert: "swish_certs/Swish_TLS_RootCA.pem",
  cert: "swish_certs/myCertificate.pem",
  key: "swish_certs/myPrivateKey.key",
  merchant_number: System.get_env("SWISH_MERCHANT_NUMBER"),
  callback_url: System.get_env("SWISH_CALLBACK_URL")

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :tiki, TikiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "dxrLXmyQCuykBWJ7xrMFZAC+WcSMSsBMX/xPQI6gnc05CE/pTe3CAClcFem5VNB3",
  server: false

# In test we don't send emails.
config :tiki, Tiki.Mailer, adapter: Swoosh.Adapters.Test

issuer = "http://localhost:7005/op"

config :tiki, Oidcc,
  issuer: issuer,
  client_id: "test",
  client_secret: "test"

config :tiki, Oidcc.ProviderConfiguration,
  issuer: issuer,
  provider_configuration_opts: %{
    quirks: %{
      allow_unsafe_http: true
    }
  }

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
