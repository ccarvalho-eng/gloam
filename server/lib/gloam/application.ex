defmodule Gloam.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {Registry, keys: :unique, name: Gloam.Runtime.Registry},
        {DynamicSupervisor, strategy: :one_for_one, name: Gloam.Runtime.SessionSupervisor},
        {Task.Supervisor, name: Gloam.Runtime.TaskSupervisor}
      ]
      |> maybe_add_http_server()

    Supervisor.start_link(children, strategy: :one_for_one, name: Gloam.Supervisor)
  end

  defp maybe_add_http_server(children) do
    case Keyword.get(http_config(), :enabled, true) do
      true -> children ++ [http_child_spec()]
      false -> children
    end
  end

  defp http_child_spec do
    config = http_config()

    {Bandit,
     plug: GloamWeb.Router,
     scheme: :http,
     ip: Keyword.get(config, :ip, :loopback),
     port: Keyword.get(config, :port, 4000)}
  end

  defp http_config do
    Application.get_env(:gloam, :http, [])
  end
end
