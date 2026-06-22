[
  import_deps: [:ecto, :ecto_sql, :phoenix, :let_me, :oban],
  subdirectories: ["priv/*/migrations", "docs"],
  plugins: [TailwindFormatter, Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test,docs}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"],
  locals_without_parens: [tab: 3]
]
