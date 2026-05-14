defmodule Gloam.World.NPC do
  @moduledoc """
  Non-player character state owned by the world runtime.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          location_id: String.t(),
          disposition: atom(),
          schedule: %{optional(atom()) => String.t()},
          memory: map()
        }

  defstruct [:id, :name, :location_id, disposition: :neutral, schedule: %{}, memory: %{}]

  @required [:id, :name, :location_id]

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    :ok = validate_required(attrs)

    struct!(
      __MODULE__,
      attrs
      |> Map.take([:id, :name, :location_id, :disposition, :schedule, :memory])
      |> Map.put_new(:disposition, :neutral)
      |> Map.put_new(:schedule, %{})
      |> Map.put_new(:memory, %{})
    )
  end

  @spec scheduled_location(t(), atom()) :: String.t() | nil
  def scheduled_location(%__MODULE__{schedule: schedule}, time_band) when is_atom(time_band) do
    Map.get(schedule, time_band)
  end

  defp validate_required(attrs) do
    missing = Enum.reject(@required, &present?(attrs, &1))

    case missing do
      [] -> :ok
      _missing -> raise ArgumentError, "missing npc fields: #{inspect(missing)}"
    end
  end

  defp present?(attrs, field) do
    case Map.fetch(attrs, field) do
      {:ok, value} when is_binary(value) and value != "" -> true
      _other -> false
    end
  end
end
