defmodule PursuitServices.App do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  use Supervisor

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: PursuitServices.Worker.start_link(arg)
      # {PursuitServices.Worker, arg},
      supervisor(PursuitServices.DB, [])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PursuitServices.Supervisor]
    Supervisor.start_link(children, opts)
  end  
end