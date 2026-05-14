defmodule Gloam.MixProject do
  use Mix.Project

  def project do
    [
      app: :gloam,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Gloam.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp description do
    "Jido-powered living-world server for Godot games."
  end

  defp package do
    [
      name: "gloam",
      maintainers: ["Cristiano Carvalho"],
      licenses: ["Apache-2.0"],
      files: ~w(lib docs .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "../docs/getting-started.md",
        "../docs/godot-existing-game.md",
        "../docs/authentication.md",
        "../docs/security.md",
        "../docs/protocol.md",
        "../docs/calendar.md",
        "../docs/rpg-primitives.md",
        "../docs/extensibility.md",
        "../docs/architecture.md",
        "../docs/operations.md"
      ]
    ]
  end

  defp deps do
    []
  end

  defp aliases do
    [
      setup: ["deps.get"],
      precommit: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test"
      ]
    ]
  end
end
