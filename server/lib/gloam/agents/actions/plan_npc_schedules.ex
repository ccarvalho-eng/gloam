defmodule Gloam.Agents.Actions.PlanNPCSchedules do
  @moduledoc """
  Jido action that proposes NPC movements from deterministic schedules.
  """

  use Jido.Action,
    name: "gloam_plan_npc_schedules",
    description: "Plans NPC movement proposals for a calendar time band",
    schema: [
      npcs: [type: :any, required: true],
      time_band: [type: :any, required: true]
    ]

  alias Gloam.World.NPC

  @impl Jido.Action
  def run(%{npcs: npcs, time_band: time_band}, _context)
      when is_map(npcs) and is_atom(time_band) do
    movements =
      npcs
      |> Map.values()
      |> Enum.sort_by(& &1.id)
      |> Enum.flat_map(&planned_movement(&1, time_band))

    {:ok, %{movements: movements}}
  end

  def run(_params, _context) do
    {:error,
     %{
       message: "NPC schedule planner received invalid params",
       retryable?: false
     }}
  end

  defp planned_movement(%NPC{} = npc, time_band) do
    case NPC.scheduled_location(npc, time_band) do
      nil -> []
      location_id -> maybe_movement(npc, location_id)
    end
  end

  defp maybe_movement(%NPC{location_id: location_id}, location_id), do: []

  defp maybe_movement(%NPC{} = npc, location_id) do
    [%{npc: %{npc | location_id: location_id}, location_id: location_id}]
  end
end
