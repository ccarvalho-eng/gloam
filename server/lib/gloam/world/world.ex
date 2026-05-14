defmodule Gloam.World.World do
  @moduledoc """
  Static world content plus current calendar state.
  """

  alias Gloam.World.{Calendar, NPC}

  @type t :: %__MODULE__{
          id: String.t(),
          calendar: Calendar.t(),
          locations: %{String.t() => struct()},
          npcs: %{String.t() => NPC.t()},
          factions: map(),
          quests: map(),
          flags: MapSet.t(atom())
        }

  defstruct [
    :id,
    :calendar,
    locations: %{},
    npcs: %{},
    factions: %{},
    quests: %{},
    flags: MapSet.new()
  ]
end
