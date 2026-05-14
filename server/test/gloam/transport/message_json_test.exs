defmodule Gloam.Transport.MessageJSONTest do
  use ExUnit.Case, async: true

  alias Gloam.Events.Event
  alias Gloam.Transport.MessageJSON
  alias Gloam.World.Content

  test "encodes snapshots with transport-safe calendar and player fields" do
    {:ok, session, _events} =
      Gloam.Runtime.Session.start(Content.living_village(), session_id: "session-1")

    encoded = MessageJSON.snapshot(Gloam.Runtime.Session.snapshot(session))

    assert encoded["type"] == "snapshot"
    assert encoded["session_id"] == "session-1"
    assert encoded["calendar"]["season"] == "emberwake"
    assert encoded["calendar"]["weekday"] == "ashwake"
    assert encoded["player"]["location_id"] == "village_square"
    assert encoded["npcs"] |> List.first() |> Map.fetch!("id")
  end

  test "encodes NPCs in snapshots with transport-safe schedule fields" do
    {:ok, session, _events} =
      Gloam.Runtime.Session.start(Content.living_village(), session_id: "session-1")

    encoded = MessageJSON.snapshot(Gloam.Runtime.Session.snapshot(session))
    npc = Enum.find(encoded["npcs"], &(&1["id"] == "mara"))

    assert npc["name"] == "Mara"
    assert npc["location_id"] == "blacksmith"
    assert npc["disposition"] == "focused"
    assert npc["schedule"]["evening"] == "tavern"
  end

  test "encodes events with string event types and correlation ids" do
    event =
      Event.new!(%{
        session_id: "session-1",
        type: :player_moved,
        actor_id: "player",
        subject_id: "blacksmith",
        correlation_id: "cmd-1",
        data: %{location_id: "blacksmith"}
      })

    encoded = MessageJSON.event(event)

    assert encoded["type"] == "event"
    assert encoded["event"]["type"] == "player_moved"
    assert encoded["event"]["correlation_id"] == "cmd-1"
    assert encoded["event"]["data"] == %{"location_id" => "blacksmith"}
  end

  test "encodes calendar structs inside event data" do
    content = Content.living_village()

    event =
      Event.new!(%{
        session_id: "session-1",
        type: :calendar_advanced,
        actor_id: "system",
        subject_id: content.world.id,
        correlation_id: "tick-1",
        data: %{calendar: content.world.calendar, facts: [:minute_changed], minutes: 5}
      })

    encoded = MessageJSON.event(event)

    assert encoded["event"]["data"]["calendar"]["season"] == "emberwake"
    assert encoded["event"]["data"]["facts"] == ["minute_changed"]
    assert encoded["event"]["data"]["minutes"] == 5
  end

  test "encodes NPC structs inside event data" do
    content = Content.living_village()
    npc = content.world.npcs["mara"]

    event =
      Event.new!(%{
        session_id: "session-1",
        type: :npc_moved,
        actor_id: "system",
        subject_id: npc.id,
        correlation_id: "tick-1",
        data: %{npc: npc, location_id: "tavern"}
      })

    encoded = MessageJSON.event(event)

    assert encoded["event"]["data"]["npc"]["id"] == "mara"
    assert encoded["event"]["data"]["npc"]["schedule"]["night"] == "tavern"
  end
end
