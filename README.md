# Tiki

## Setup (Docker)

This is the easiest way to get the project up and running. You will need to have Docker and Docker Compose installed on your machine. Simply run:

```bash
docker-compose up
```

The application will be available at `http://localhost:4000` in your browser. An admin user is available by default, using "Login with KTH" with the username `turetek`. See the `docker-compose.yml` file for more information. By default, there
are no payment methods configured, so you will have to set them up manually. Both payment methods are hidden behind feature flags. Go to `/admin/feature-flags` to enable them. You will need `:stripe_enabled` and `:swish_enabled` to be enabled, respectively.

* For Stripe, you can set up a test account [here](https://dashboard.stripe.com/test/dashboard) for free. Then, get your
  secret key and public key from dashboard end set them in the `config/.env` file.

* Swish (Swish Sandbox) is complicated to get working, and needs keys from Swish, see [here](https://developer.swish.nu/documentation/environments#swish-sandbox). Set the variables in the `config/.env` file. You will also need to set up a proxy from a public URL to your local machine, for example using Cloudflare Tunnel or ngrok.

Se the `config/.env.example` file for more information.

## Setup (Local)

This is not recommended unless you know what you are doing. To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser. See the `docker-compose.yml` file for
inspiration of what services are needed and how to set them up.

## Learn more about phoenix

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
