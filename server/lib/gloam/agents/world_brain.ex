defmodule Gloam.Agents.WorldBrain do
  @moduledoc """
  Jido agent that runs bounded planning primitives for a living world.
  """

  use Jido.Agent,
    name: "gloam_world_brain",
    description: "Runs deterministic world-brain planning primitives",
    schema: [
      npcs: [type: :any, default: %{}],
      time_band: [type: :any, default: :morning],
      movements: [type: :any, default: []]
    ]
end
