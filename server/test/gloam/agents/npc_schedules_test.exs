defmodule Gloam.Agents.NPCSchedulesTest do
  use ExUnit.Case, async: true

  alias Gloam.Agents.NPCSchedules
  alias Gloam.World.Content

  test "runs a Jido world brain action to plan scheduled NPC movement proposals" do
    content = Content.living_village()

    assert {:ok, movements} =
             NPCSchedules.plan_movements(%{
               npcs: content.world.npcs,
               time_band: :evening
             })

    mara = Enum.find(movements, &(&1.npc.id == "mara"))

    assert mara.location_id == "tavern"
    assert mara.npc.location_id == "tavern"
  end

  test "stores the latest movement plan on the Jido agent state" do
    content = Content.living_village()

    assert {:ok, brain, movements} =
             NPCSchedules.plan_with_brain(%{
               npcs: content.world.npcs,
               time_band: :evening
             })

    assert brain.name == "gloam_world_brain"
    assert brain.state.time_band == :evening
    assert brain.state.movements == movements
  end

  test "does not propose movement when an NPC already matches the schedule" do
    content = Content.living_village()

    assert {:ok, movements} =
             NPCSchedules.plan_movements(%{
               npcs: content.world.npcs,
               time_band: :morning
             })

    assert movements == []
  end
end
