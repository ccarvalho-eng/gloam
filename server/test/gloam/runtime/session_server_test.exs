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

    monitor_ref = Process.monitor(first_pid)
    GenServer.stop(first_pid)
    assert_receive {:DOWN, ^monitor_ref, :process, ^first_pid, _reason}

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

  defp start_session(storage_path, session_id) do
    opts = [content: Content.living_village(), session_id: session_id, storage_path: storage_path]

    with {:ok, pid} <- SessionServer.start_link(opts) do
      on_exit(fn -> stop_if_alive(pid) end)
      {:ok, pid}
    end
  end

  defp stop_if_alive(pid) do
    if Process.alive?(pid) do
      GenServer.stop(pid)
    end
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
end
