defmodule Master.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {Master.Server, %{:port => 27950}}
      # Starts a worker by calling: Master.Worker.start_link(arg)
      # {Master.Worker, arg},
    ]

    opts = [strategy: :one_for_one, name: Master.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
