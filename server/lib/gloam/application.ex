defmodule Gloam.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Gloam.Runtime.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Gloam.Runtime.SessionSupervisor},
      {Task.Supervisor, name: Gloam.Runtime.TaskSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Gloam.Supervisor)
  end
end
