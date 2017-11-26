defmodule PursuitServices.Mixfile do
  use Mix.Project

  def project do
    [
      app: :pursuit_services,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {PursuitServices.App, []},
      extra_applications: [
        :logger, :dotenv, :amqp, :ecto, :postgrex
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # DB / FDM
      {:postgrex, ">= 0.0.0"},
      {:ecto, "~> 2.1"},
      # Generate DB models from schema
      {:plsm, "~> 2.0.1"},

      # .env
      {:dotenv, "~> 2.0.0"},

      # RabbitMQ
      {:amqp, "~> 1.0.0-pre.2"},

      # "Rubocop"
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false}


      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end
