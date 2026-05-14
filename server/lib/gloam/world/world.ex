defmodule Gloam.World.World do
  @moduledoc """
  Static world content plus current calendar state.
  """

  alias Gloam.World.Calendar

  @type t :: %__MODULE__{
          id: String.t(),
          calendar: Calendar.t(),
          locations: %{String.t() => struct()},
          npcs: map(),
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
