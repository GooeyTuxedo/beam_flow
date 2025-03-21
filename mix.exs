defmodule BeamFlow.MixProject do
  use Mix.Project

  def project do
    [
      app: :beam_flow,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ],
      excoveralls: [
        minimum_coverage: 90,
        terminal_output: "console",
        skip_files: []
      ]
    ]
  end

  # Configuration for the OTP application.
  def application do
    [
      mod: {BeamFlow.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_other_env), do: ["lib"]

  # Specifies your project dependencies.
  defp deps do
    [
      {:argon2_elixir, "~> 4.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix, "~> 1.7.20"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.1"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1"},
      {:bandit, "~> 1.5"},
      {:logger_json, "~> 6.2.1"},
      {:ecto_logger_json, "~> 0.1"},
      {:plug_logger_json, "~> 0.7"},
      {:plug, "~> 1.17"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind beam_flow", "esbuild beam_flow"],
      "assets.deploy": [
        "tailwind beam_flow --minify",
        "esbuild beam_flow --minify",
        "phx.digest"
      ],
      lint: ["format", "credo --strict"],
      "lint.ci": ["format --check-formatted", "credo --strict"],
      # Add coverage aliases
      "test.coverage": ["test --cover"],
      coveralls: ["coveralls"],
      "coveralls.html": ["coveralls.html"],
      "coveralls.json": ["coveralls.json"]
    ]
  end
end
