defmodule Membrane.Template.Mixfile do
  use Mix.Project

  @version "0.1.1"
  @github_url "https://github.com/jellyfish-dev/elixir_server_sdk"
  @homepage_url "https://membrane.stream"

  def project do
    [
      app: :jellyfish_server_sdk,
      version: @version,
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer(),

      # hex
      description: "Jellyfish Server SDK",
      package: package(),

      # docs
      name: "Jellyfish Server SDK",
      source_url: @github_url,
      homepage_url: @homepage_url,
      docs: docs(),

      # test coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration_test], do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:tesla, "~> 1.5"},
      {:mint, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:websockex, "~> 0.4.3"},

      # protobuf deps
      {:protobuf, "~> 0.12.0"},
      # Tests
      {:divo, "~> 1.3.1", only: [:test]},

      # Docs, credo, test coverage, dialyzer
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, ">= 0.0.0", only: [:test, :integration_test], runtime: false}
    ]
  end

  defp dialyzer() do
    opts = [
      flags: [:error_handling]
    ]

    if System.get_env("CI") == "true" do
      # Store PLTs in cacheable directory for CI
      [plt_local_path: "priv/plts", plt_core_path: "priv/plts"] ++ opts
    else
      opts
    end
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => @homepage_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      formatters: ["html"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Jellyfish, Jellyfish.ServerMessage, Jellyfish.Exception],
      groups_for_modules: [
        "Server notifications": ~r/^Jellyfish\.ServerMessage[.a-zA-Z]*$/
      ]
    ]
  end

  def aliases do
    [
      integration_test: [
        "cmd docker compose -f docker-compose-integration.yaml pull",
        "cmd docker compose -f docker-compose-integration.yaml run test"
      ]
    ]
  end
end
