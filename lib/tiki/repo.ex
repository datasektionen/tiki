defmodule Tiki.Repo do
  use Ecto.Repo,
    otp_app: :tiki,
    adapter: Ecto.Adapters.Postgres

  use Paginator
end
