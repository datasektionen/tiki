defmodule Tiki.MixProject do
  use Mix.Project

  def project do
    [
      app: :tiki,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Tiki.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix, "~> 1.7.16"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3.0", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:ex_cldr_dates_times, "~> 2.0"},
      {:tz, "~> 0.28"},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.0"},
      {:stripity_stripe, "~> 3.0"},
      {:req, "~> 0.5"},
      {:req_s3, "~> 0.2.3"},
      {:imgproxy, "~> 3.0"},
      {:oidcc_plug, "~> 0.1.0"},
      {:oidcc, "~> 3.4.0"},
      {:let_me, "~> 1.2"},
      {:qrcode_ex, "~> 0.1.0"},
      {:excoveralls, "~> 0.18", only: :test},
      {:k6, "~> 0.2.0", only: :dev, runtime: false},
      {:tailwind_formatter, "~> 0.4.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:phx_gen_oidcc, "~> 0.1.0", only: :dev, runtime: false},
      {:salad_ui,
       git: "https://github.com/adriansalamon/salad_ui",
       branch: "main",
       only: :dev,
       runtime: false},
      {:tails, "~> 0.1"},
      {:mjml, "~> 5.0"},
      {:oban, "~> 2.18"},
      {:fun_with_flags, "~> 1.0"},
      {:fun_with_flags_ui, "~> 1.0"},
      {:nimble_csv, "~> 1.2"},
      {:prom_ex, "~> 1.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
