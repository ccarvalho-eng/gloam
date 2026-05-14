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
          | {:tick, keyword()}

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

  @spec tick(GenServer.server(), pos_integer()) ::
          {:ok, [struct()]} | {:error, struct(), [struct()]}
  def tick(server, minutes) do
    GenServer.call(server, {:tick, minutes})
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

    tick = tick_config(Keyword.get(opts, :tick, []))

    with {:ok, session, new_events} <- load_or_start(content, session_id, storage_path),
         :ok <- EventStore.append(storage_path, session_id, new_events) do
      state = %{session: session, storage_path: storage_path, tick: tick, tick_timer: nil}
      {:ok, schedule_tick(state)}
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

  def handle_call({:tick, minutes}, _from, state) do
    result = Session.tick(state.session, minutes)
    handle_tick_result(result, state)
  end

  @impl true
  def handle_info({:tick, tick_ref}, %{tick_timer: tick_ref} = state) do
    result =
      state.session
      |> Session.tick(state.tick.minutes)
      |> persist_tick_result(state)

    handle_scheduled_tick_result(result, state)
  end

  def handle_info({:tick, _stale_tick_ref}, state) do
    {:noreply, state}
  end

  defp handle_tick_result({:ok, session, events}, state) do
    reply_after_persist(state, session, events, {:ok, events})
  end

  defp handle_tick_result({:error, error, session, events}, state) do
    {:reply, {:error, error, events}, %{state | session: session}}
  end

  defp persist_tick_result({:ok, session, events}, state) do
    with :ok <- persist_events(state.storage_path, session.id, events) do
      {:ok, session}
    end
  end

  defp persist_tick_result({:error, error, _session, _events}, _state) do
    {:error, error}
  end

  defp handle_scheduled_tick_result({:ok, session}, state) do
    state =
      %{state | session: session, tick_timer: nil}
      |> schedule_tick()

    {:noreply, state}
  end

  defp handle_scheduled_tick_result({:error, reason}, state) do
    {:stop, reason, %{state | tick_timer: nil}}
  end

  defp handle_command_result({:ok, session, events}, state) do
    reply_after_persist(state, session, events, {:ok, events})
  end

  defp handle_command_result({:error, error, session, events}, state) do
    reply_after_persist(state, session, events, {:error, error, events})
  end

  defp reply_after_persist(state, session, events, reply) do
    case persist_events(state.storage_path, session.id, events) do
      :ok -> {:reply, reply, %{state | session: session}}
      {:error, reason} -> {:stop, reason, {:error, reason, []}, state}
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

  defp tick_config(opts) do
    %{
      enabled: Keyword.get(opts, :enabled, false),
      interval_ms: Keyword.get(opts, :interval_ms, 1_000),
      minutes: Keyword.get(opts, :minutes, 5)
    }
  end

  defp schedule_tick(%{tick: %{enabled: true, interval_ms: interval_ms}, tick_timer: nil} = state) do
    tick_ref = make_ref()
    Process.send_after(self(), {:tick, tick_ref}, interval_ms)
    %{state | tick_timer: tick_ref}
  end

  defp schedule_tick(state), do: state

  defp via_tuple(session_id) do
    {:via, Registry, {Gloam.Runtime.Registry, session_id}}
  end
end
