defmodule Gloam.Commands.Command do
  @moduledoc """
  Normalized command submitted by a player or autonomous runtime actor.
  """

  @type source :: :player | :agent | :system
  @type command_type :: :look | :travel | :talk | :inspect | :wait

  @type t :: %__MODULE__{
          id: String.t(),
          session_id: String.t(),
          actor_id: String.t(),
          type: command_type(),
          target_id: String.t() | nil,
          params: map(),
          source: source()
        }

  defstruct [:id, :session_id, :actor_id, :type, :target_id, params: %{}, source: :player]

  @required [:id, :session_id, :actor_id, :type, :source]

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    :ok = validate_required(attrs)

    struct!(
      __MODULE__,
      Map.take(attrs, [:id, :session_id, :actor_id, :type, :target_id, :params, :source])
    )
  end

  defp validate_required(attrs) do
    missing = Enum.reject(@required, &Map.has_key?(attrs, &1))

    case missing do
      [] -> :ok
      _missing -> raise ArgumentError, "missing command fields: #{inspect(missing)}"
    end
  end
end
