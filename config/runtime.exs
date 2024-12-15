import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/tiki start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :tiki, TikiWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :tiki, Tiki.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # Swish
  swish_api_url = System.get_env("SWISH_API_URL") || raise "SWISH_API_URL is not set"
  swish_cert = System.get_env("SWISH_CERT") || raise "SWISH_CERT is not set"
  swish_key = System.get_env("SWISH_KEY") || raise "SWISH_KEY is not set"

  swish_merchant_number =
    System.get_env("SWISH_MERCHANT_NUMBER") || raise "SWISH_MERCHANT_NUMBER is not set"

  swish_callback_url =
    System.get_env("SWISH_CALLBACK_URL") || raise "SWISH_CALLBACK_URL is not set"

  config :tiki, Swish,
    api_url: swish_api_url,
    cert: swish_cert |> Base.decode64!(),
    key: swish_key |> Base.decode64!(),
    merchant_number: swish_merchant_number,
    callback_url: swish_callback_url

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :tiki, TikiWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # Stripe config
  stripe_api_key = System.get_env("STRIPE_API_KEY") || raise "STRIPE_API_KEY is not set"

  stripe_webhook_secret =
    System.get_env("STRIPE_WEBHOOK_SECRET") || raise "STRIPE_WEBHOOK_SECRET is not set"

  config :stripity_stripe,
    api_key: stripe_api_key,
    webhook_secret: stripe_webhook_secret

  # Oidc login
  oidc_issuer_url = System.get_env("OIDC_ISSUER_URL") || "https://sso.datasektionen.se/op"
  oidc_client_id = System.get_env("OIDC_CLIENT_ID") || raise "OIDC_CLIENT_ID is not set"

  oidc_client_secret =
    System.get_env("OIDC_CLIENT_SECRET") || raise "OIDC_CLIENT_SECRET is not set"

  config :tiki, Oidcc,
    issuer: oidc_issuer_url,
    client_id: oidc_client_id,
    client_secret: oidc_client_secret

  config :tiki, Oidcc.ProviderConfiguration, issuer: oidc_issuer_url

  # S3 config
  bucket = System.get_env("S3_BUCKET_NAME") || raise "S3_BUCKET_NAME is not set"
  region = System.get_env("AWS_REGION") || "eu-north-1"
  endpoint_url = System.get_env("AWS_ENDPOINT_URL_S3")

  endpoint_frontend_url =
    System.get_env("AWS_FRONTEND_ENDPOINT_URL_S3")

  access_key_id = System.get_env("AWS_ACCESS_KEY_ID") || raise "AWS_ACCESS_KEY_ID is not set"

  secret_access_key =
    System.get_env("AWS_SECRET_ACCESS_KEY") || raise "AWS_SECRET_ACCESS_KEY is not set"

  config :tiki, Tiki.S3,
    bucket: bucket,
    region: region,
    endpoint_url: endpoint_url,
    endpoint_frontend_url: endpoint_frontend_url,
    access_key_id: access_key_id,
    secret_access_key: secret_access_key

  # Imgproxy config
  imgproxy_key = System.get_env("IMGPROXY_KEY") || raise "IMGPROXY_KEY is not set"
  imgproxy_salt = System.get_env("IMGPROXY_SALT") || raise "IMGPROXY_SALT is not set"

  image_frontend_url =
    System.get_env("IMAGE_FRONTEND_URL") || raise "IMAGE_FRONTEND_URL is not set"

  config :imgproxy,
    key: imgproxy_key,
    salt: imgproxy_salt,
    prefix: image_frontend_url
end
