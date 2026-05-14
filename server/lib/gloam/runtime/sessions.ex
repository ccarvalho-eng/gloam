defmodule Gloam.Runtime.Sessions do
  @moduledoc """
  Session runtime acquisition.
  """

  alias Gloam.Runtime.SessionServer
  alias Gloam.World.Content

  @spec get_or_start(String.t()) :: {:ok, pid()} | {:error, term()}
  def get_or_start(session_id) when is_binary(session_id) do
    case Registry.lookup(Gloam.Runtime.Registry, session_id) do
      [{pid, _value}] -> {:ok, pid}
      [] -> start_session(session_id)
    end
  end

  defp start_session(session_id) do
    child_spec = {
      SessionServer,
      content: Content.living_village(), session_id: session_id, storage_path: storage_path()
    }

    case DynamicSupervisor.start_child(Gloam.Runtime.SessionSupervisor, child_spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  defp storage_path do
    Application.get_env(:gloam, :storage_path, "priv/gloam/storage")
  end
end
