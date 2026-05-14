defmodule Gloam.World.Player do
  @moduledoc """
  Player state owned by a Gloam session.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          location_id: String.t(),
          faction_standing: map(),
          relationships: map(),
          quests: map(),
          rumors: MapSet.t(String.t())
        }

  defstruct [
    :id,
    :location_id,
    faction_standing: %{},
    relationships: %{},
    quests: %{},
    rumors: MapSet.new()
  ]
end
