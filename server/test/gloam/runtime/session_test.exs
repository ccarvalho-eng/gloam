defmodule Gloam.Runtime.SessionTest do
  use ExUnit.Case, async: true

  alias Gloam.Commands.Command
  alias Gloam.Events.Event
  alias Gloam.Runtime.Session
  alias Gloam.World.Content

  test "starts a session and folds the initial snapshot" do
    {:ok, session, events} = Session.start(Content.living_village(), session_id: "session-1")

    snapshot = Session.snapshot(session)

    assert Enum.map(events, & &1.type) == [:session_started]
    assert snapshot.session_id == "session-1"
    assert snapshot.player.location_id == "village_square"
    assert snapshot.calendar.season == :emberwake
    assert snapshot.calendar.weekday == :ashwake
  end

  test "accepts valid travel commands and appends events" do
    {:ok, session, _events} = Session.start(Content.living_village(), session_id: "session-1")

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

    {:ok, updated, events} = Session.submit_command(session, command)

    assert Enum.map(events, & &1.type) == [:player_moved]
    assert Session.snapshot(updated).player.location_id == "blacksmith"
  end

  test "rejects actor/session mismatches before rules run" do
    {:ok, session, _events} = Session.start(Content.living_village(), session_id: "session-1")

    command =
      Command.new!(%{
        id: "cmd-1",
        session_id: "other-session",
        actor_id: "player",
        type: :travel,
        target_id: "blacksmith",
        params: %{},
        source: :player
      })

    {:error, error, updated, events} = Session.submit_command(session, command)

    assert error.code == :session_mismatch
    assert Enum.map(events, & &1.type) == [:command_rejected]
    assert Session.snapshot(updated).player.location_id == "village_square"
  end

  test "deduplicates command ids without reapplying mutations" do
    {:ok, session, _events} = Session.start(Content.living_village(), session_id: "session-1")

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

    {:ok, moved, [_event]} = Session.submit_command(session, command)
    {:ok, deduped, events} = Session.submit_command(moved, command)

    assert events == []
    assert Session.snapshot(deduped).player.location_id == "blacksmith"
    assert length(deduped.events) == length(moved.events)
  end

  test "wait advances the calendar through the same event path" do
    {:ok, session, _events} = Session.start(Content.living_village(), session_id: "session-1")

    command =
      Command.new!(%{
        id: "cmd-1",
        session_id: "session-1",
        actor_id: "player",
        type: :wait,
        target_id: nil,
        params: %{minutes: 90},
        source: :player
      })

    {:ok, updated, events} = Session.submit_command(session, command)

    assert Enum.map(events, & &1.type) == [:calendar_advanced]
    assert Session.snapshot(updated).calendar.hour == 7
    assert Session.snapshot(updated).calendar.minute == 30
  end

  test "tick advances calendar time through replayable events" do
    {:ok, session, _events} = Session.start(Content.living_village(), session_id: "session-1")

    assert {:ok, updated, events} = Session.tick(session, 15)

    assert Enum.map(events, & &1.type) == [:calendar_advanced]
    assert Session.snapshot(updated).calendar.hour == 6
    assert Session.snapshot(updated).calendar.minute == 15
  end

  test "tick rejects invalid minute values without changing state" do
    {:ok, session, _events} = Session.start(Content.living_village(), session_id: "session-1")

    assert {:error, error, ^session, []} = Session.tick(session, 0)
    assert error.code == :invalid_tick_duration
  end

  test "tick returns structured errors when NPC schedule planning fails" do
    content = Content.living_village()
    invalid_content = %{content | world: %{content.world | npcs: :invalid}}
    {:ok, session, _events} = Session.start(invalid_content, session_id: "session-1")

    assert {:error, error, ^session, []} = Session.tick(session, 15)
    assert error.code == :npc_schedule_planning_failed
  end

  test "tick moves scheduled NPCs through replayable events" do
    {:ok, session, _events} = Session.start(Content.living_village(), session_id: "session-1")

    assert Session.snapshot(session).npcs["mara"].location_id == "blacksmith"
    assert {:ok, updated, events} = Session.tick(session, 720)

    assert Enum.map(events, & &1.type) == [:calendar_advanced, :npc_moved, :npc_moved]
    assert Session.snapshot(updated).calendar.time_band == :evening
    assert Session.snapshot(updated).npcs["mara"].location_id == "tavern"
  end

  test "replay restores NPC movement events even if static content changed" do
    content = Content.living_village()
    {:ok, session, _events} = Session.start(content, session_id: "session-1")
    {:ok, moved, events} = Session.tick(session, 720)
    npc_moved = Enum.find(events, &(&1.type == :npc_moved and &1.subject_id == "mara"))

    content_without_mara = %{
      content
      | world: %{content.world | npcs: Map.delete(content.world.npcs, "mara")}
    }

    assert {:ok, replayed} = Session.replay(content_without_mara, "session-1", moved.events)
    assert Session.snapshot(replayed).npcs["mara"].location_id == "tavern"
    assert %Event{} = npc_moved
  end
end
