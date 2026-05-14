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
end
