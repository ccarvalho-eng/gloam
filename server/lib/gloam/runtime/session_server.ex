defmodule Gloam.Runtime.SessionServer do
  @moduledoc """
  Serialized runtime owner for one Gloam session.
  """

  use GenServer

  alias Gloam.Commands.Command
  alias Gloam.Runtime.Session
  alias Gloam.Storage.EventStore

  @type option ::
          {:content, map()}
          | {:session_id, String.t()}
          | {:storage_path, String.t()}

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(session_id))
  end

  @spec submit_command(GenServer.server(), Command.t()) ::
          {:ok, [struct()]} | {:error, struct(), [struct()]}
  def submit_command(server, %Command{} = command) do
    GenServer.call(server, {:submit_command, command})
  end

  @spec snapshot(GenServer.server()) :: map()
  def snapshot(server) do
    GenServer.call(server, :snapshot)
  end

  @impl true
  def init(opts) do
    content = Keyword.fetch!(opts, :content)
    session_id = Keyword.fetch!(opts, :session_id)
    storage_path = Keyword.fetch!(opts, :storage_path)

    with {:ok, session, new_events} <- load_or_start(content, session_id, storage_path),
         :ok <- EventStore.append(storage_path, session_id, new_events) do
      {:ok, %{session: session, storage_path: storage_path}}
    end
  end

  @impl true
  def handle_call({:submit_command, %Command{} = command}, _from, state) do
    result = Session.submit_command(state.session, command)
    handle_command_result(result, state)
  end

  def handle_call(:snapshot, _from, state) do
    {:reply, Session.snapshot(state.session), state}
  end

  defp handle_command_result({:ok, session, events}, state) do
    with :ok <- persist_events(state.storage_path, session.id, events) do
      {:reply, {:ok, events}, %{state | session: session}}
    end
  end

  defp handle_command_result({:error, error, session, events}, state) do
    with :ok <- persist_events(state.storage_path, session.id, events) do
      {:reply, {:error, error, events}, %{state | session: session}}
    end
  end

  defp persist_events(_storage_path, _session_id, []), do: :ok

  defp persist_events(storage_path, session_id, events) do
    EventStore.append(storage_path, session_id, events)
  end

  defp load_or_start(content, session_id, storage_path) do
    with {:ok, events} <- EventStore.load(storage_path, session_id) do
      restore_or_start(content, session_id, events)
    end
  end

  defp restore_or_start(content, session_id, []) do
    Session.start(content, session_id: session_id)
  end

  defp restore_or_start(content, session_id, events) do
    with {:ok, session} <- Session.replay(content, session_id, events) do
      {:ok, session, []}
    end
  end

  defp via_tuple(session_id) do
    {:via, Registry, {Gloam.Runtime.Registry, session_id}}
  end
end
