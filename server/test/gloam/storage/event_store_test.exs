defmodule Gloam.Storage.EventStoreTest do
  use ExUnit.Case, async: true

  alias Gloam.Commands.Command
  alias Gloam.Runtime.Session
  alias Gloam.Storage.EventStore
  alias Gloam.World.Content

  test "persists and reloads a session event log" do
    path = tmp_path()

    {:ok, session, start_events} =
      Session.start(Content.living_village(), session_id: "session-1")

    command =
      Command.new!(%{
        id: "cmd-1",
        session_id: "session-1",
        actor_id: "player",
        type: :travel,
        target_id: "blacksmith",
        params: %{},
        source: :player
      })

    {:ok, moved, travel_events} = Session.submit_command(session, command)

    assert :ok = EventStore.append(path, moved.id, start_events)
    assert :ok = EventStore.append(path, moved.id, travel_events)

    assert {:ok, events} = EventStore.load(path, "session-1")
    assert Enum.map(events, & &1.type) == [:session_started, :player_moved]

    {:ok, replayed} = Session.replay(Content.living_village(), "session-1", events)

    assert Session.snapshot(replayed).player.location_id == "blacksmith"
    assert Session.snapshot(replayed).event_count == 2
  end

  test "missing session logs load as an empty event stream" do
    assert {:ok, []} = EventStore.load(tmp_path(), "missing-session")
  end

  defp tmp_path do
    Path.join(System.tmp_dir!(), "gloam-event-store-#{System.unique_integer([:positive])}")
  end
end
