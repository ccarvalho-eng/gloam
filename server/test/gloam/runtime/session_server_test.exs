defmodule Gloam.Runtime.SessionServerTest do
  use ExUnit.Case, async: false

  alias Gloam.Commands.Command
  alias Gloam.Runtime.SessionServer
  alias Gloam.Storage.EventStore
  alias Gloam.World.Content

  test "starts a session server and persists accepted commands" do
    storage_path = tmp_path()
    {:ok, pid} = start_session(storage_path, "session-1")

    command = travel_command("cmd-1", "session-1", "blacksmith")

    assert {:ok, events} = SessionServer.submit_command(pid, command)
    assert Enum.map(events, & &1.type) == [:player_moved]
    assert SessionServer.snapshot(pid).player.location_id == "blacksmith"

    assert {:ok, persisted} = EventStore.load(storage_path, "session-1")
    assert Enum.map(persisted, & &1.type) == [:session_started, :player_moved]
  end

  test "resumes from persisted events before accepting commands" do
    storage_path = tmp_path()
    {:ok, first_pid} = start_session(storage_path, "session-1")

    assert {:ok, [_event]} =
             SessionServer.submit_command(
               first_pid,
               travel_command("cmd-1", "session-1", "blacksmith")
             )

    assert :ok = stop_session(first_pid)

    {:ok, resumed_pid} = start_session(storage_path, "session-1")

    assert SessionServer.snapshot(resumed_pid).player.location_id == "blacksmith"
    assert SessionServer.snapshot(resumed_pid).event_count == 2
  end

  test "deduplicates command ids without appending another event" do
    storage_path = tmp_path()
    {:ok, pid} = start_session(storage_path, "session-1")
    command = travel_command("cmd-1", "session-1", "blacksmith")

    assert {:ok, [_event]} = SessionServer.submit_command(pid, command)
    assert {:ok, []} = SessionServer.submit_command(pid, command)

    assert {:ok, persisted} = EventStore.load(storage_path, "session-1")
    assert Enum.map(persisted, & &1.type) == [:session_started, :player_moved]
  end

  test "manual ticks advance and persist session calendar events" do
    storage_path = tmp_path()
    {:ok, pid} = start_session(storage_path, "session-1")

    assert {:ok, events} = SessionServer.tick(pid, 20)
    assert Enum.map(events, & &1.type) == [:calendar_advanced]
    assert SessionServer.snapshot(pid).calendar.minute == 20

    assert {:ok, persisted} = EventStore.load(storage_path, "session-1")
    assert Enum.map(persisted, & &1.type) == [:session_started, :calendar_advanced]
  end

  test "resumes persisted NPC movement from tick events" do
    storage_path = tmp_path()
    {:ok, first_pid} = start_session(storage_path, "session-1")

    assert {:ok, events} = SessionServer.tick(first_pid, 720)
    assert Enum.map(events, & &1.type) == [:calendar_advanced, :npc_moved, :npc_moved]
    assert SessionServer.snapshot(first_pid).npcs["mara"].location_id == "tavern"
    assert :ok = stop_session(first_pid)

    {:ok, resumed_pid} = start_session(storage_path, "session-1")

    assert SessionServer.snapshot(resumed_pid).npcs["mara"].location_id == "tavern"
  end

  test "automatic ticks are opt-in and persist through the same event path" do
    storage_path = tmp_path()

    {:ok, pid} =
      start_session(storage_path, "session-1", tick: [enabled: true, interval_ms: 10, minutes: 5])

    assert eventually(fn -> SessionServer.snapshot(pid).calendar.minute >= 5 end)

    assert {:ok, persisted} = EventStore.load(storage_path, "session-1")
    assert Enum.any?(persisted, &(&1.type == :calendar_advanced))
  end

  test "ignores stale scheduled tick messages" do
    storage_path = tmp_path()
    {:ok, pid} = start_session(storage_path, "session-1")

    send(pid, {:tick, make_ref()})
    Process.sleep(10)

    assert SessionServer.snapshot(pid).calendar.minute == 0
    assert {:ok, persisted} = EventStore.load(storage_path, "session-1")
    assert Enum.map(persisted, & &1.type) == [:session_started]
  end

  defp start_session(storage_path, session_id, extra_opts \\ []) do
    opts =
      [content: Content.living_village(), session_id: session_id, storage_path: storage_path] ++
        extra_opts

    with {:ok, pid} <- SessionServer.start_link(opts) do
      on_exit(fn -> stop_session(pid) end)
      {:ok, pid}
    end
  end

  defp stop_session(pid) do
    GenServer.stop(pid)
  catch
    :exit, {:noproc, _call} -> :ok
  end

  defp travel_command(id, session_id, target_id) do
    Command.new!(%{
      id: id,
      session_id: session_id,
      actor_id: "player",
      type: :travel,
      target_id: target_id,
      params: %{},
      source: :player
    })
  end

  defp tmp_path do
    path =
      Path.join(
        System.tmp_dir!(),
        "gloam-session-server-#{System.os_time(:nanosecond)}-#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf(path) end)
    path
  end

  defp eventually(fun), do: eventually(fun, 20)

  defp eventually(_fun, 0), do: false

  defp eventually(fun, attempts_left) do
    case fun.() do
      true ->
        true

      false ->
        Process.sleep(10)
        eventually(fun, attempts_left - 1)
    end
  end
end
