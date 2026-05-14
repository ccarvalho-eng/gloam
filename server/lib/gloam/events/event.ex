defmodule Gloam.Events.Event do
  @moduledoc """
  Canonical fact produced by accepted or rejected world commands.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          session_id: String.t(),
          type: atom(),
          actor_id: String.t() | nil,
          subject_id: String.t() | nil,
          data: map(),
          correlation_id: String.t() | nil
        }

  defstruct [:id, :session_id, :type, :actor_id, :subject_id, :data, :correlation_id]

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    struct!(__MODULE__, Map.put_new(attrs, :id, generate_id()))
  end

  defp generate_id do
    System.unique_integer([:positive, :monotonic])
    |> Integer.to_string()
  end
end
