defmodule Gloam.World.Location do
  @moduledoc """
  Static and derived location data for a world.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          exits: [String.t()],
          tags: [atom()]
        }

  defstruct [:id, :name, exits: [], tags: []]
end
