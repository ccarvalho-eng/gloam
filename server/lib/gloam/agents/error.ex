defmodule Gloam.Agents.Error do
  @moduledoc """
  Structured error returned by agent proposal boundaries.
  """

  @type t :: %__MODULE__{code: atom(), message: String.t(), details: map()}

  defstruct [:code, :message, details: %{}]

  @spec new(atom(), String.t(), map()) :: t()
  def new(code, message, details \\ %{}) do
    %__MODULE__{code: code, message: message, details: details}
  end
end
