defmodule Gloam.World.NPCTest do
  use ExUnit.Case, async: true

  alias Gloam.World.NPC

  test "builds an NPC with schedule and disposition defaults" do
    npc =
      NPC.new!(%{
        id: "mara",
        name: "Mara",
        location_id: "blacksmith",
        schedule: %{evening: "tavern"}
      })

    assert npc.id == "mara"
    assert npc.disposition == :neutral
    assert npc.schedule.evening == "tavern"
  end
end
