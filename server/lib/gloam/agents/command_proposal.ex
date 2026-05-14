defmodule Gloam.Agents.CommandProposal do
  @moduledoc """
  Agent-authored command proposal ready for deterministic rule validation.
  """

  alias Gloam.Agents.Error
  alias Gloam.Commands.Command
  alias Gloam.Transport.CommandJSON
  alias Gloam.Transport.Error, as: TransportError

  @type t :: %__MODULE__{
          agent_id: String.t(),
          command: Command.t(),
          reason: String.t(),
          confidence: float()
        }

  defstruct [:agent_id, :command, reason: "", confidence: 1.0]

  @known_command_keys ~w(id session_id actor_id type target_id params source)a

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attrs) when is_map(attrs) do
    with {:ok, agent_id} <- fetch_string(attrs, :agent_id),
         {:ok, command_payload} <- fetch_map(attrs, :command),
         {:ok, reason} <- optional_string(attrs, :reason, ""),
         {:ok, confidence} <- optional_float(attrs, :confidence, 1.0),
         {:ok, command} <- decode_command(command_payload) do
      {:ok,
       %__MODULE__{
         agent_id: agent_id,
         command: command,
         reason: reason,
         confidence: confidence
       }}
    end
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = proposal) do
    %{
      agent_id: proposal.agent_id,
      command: CommandJSON.encode(proposal.command),
      reason: proposal.reason,
      confidence: proposal.confidence
    }
  end

  defp decode_command(command_payload) do
    command_payload
    |> normalize_command_payload()
    |> Map.put("source", "agent")
    |> CommandJSON.decode()
    |> normalize_command_result()
  end

  defp normalize_command_result({:ok, %Command{} = command}), do: {:ok, command}

  defp normalize_command_result({:error, %TransportError{} = error}) do
    {:error,
     Error.new(:invalid_command_proposal, "Agent proposal command is invalid", %{
       command_error: %{
         code: error.code,
         message: error.message,
         details: error.details
       }
     })}
  end

  defp normalize_command_payload(payload) do
    Map.new(payload, &normalize_command_entry/1)
  end

  defp normalize_command_entry({key, value}) when key in @known_command_keys do
    {Atom.to_string(key), value}
  end

  defp normalize_command_entry({key, value}) do
    {key, value}
  end

  defp fetch_string(attrs, field) do
    attrs
    |> Map.fetch(field)
    |> normalize_required_string(field)
  end

  defp normalize_required_string({:ok, value}, _field) when is_binary(value), do: {:ok, value}

  defp normalize_required_string(_result, field) do
    {:error, Error.new(:invalid_proposal, "Agent proposal field is required", %{field: field})}
  end

  defp fetch_map(attrs, field) do
    attrs
    |> Map.fetch(field)
    |> normalize_required_map(field)
  end

  defp normalize_required_map({:ok, value}, _field) when is_map(value), do: {:ok, value}

  defp normalize_required_map(_result, field) do
    {:error, Error.new(:invalid_proposal, "Agent proposal field must be a map", %{field: field})}
  end

  defp optional_string(attrs, field, default) do
    attrs
    |> Map.get(field, default)
    |> normalize_optional_string(field)
  end

  defp normalize_optional_string(value, _field) when is_binary(value), do: {:ok, value}

  defp normalize_optional_string(_value, field) do
    {:error,
     Error.new(:invalid_proposal, "Agent proposal field must be a string", %{field: field})}
  end

  defp optional_float(attrs, field, default) do
    attrs
    |> Map.get(field, default)
    |> normalize_optional_float(field)
  end

  defp normalize_optional_float(value, _field) when is_float(value), do: {:ok, value}
  defp normalize_optional_float(value, _field) when is_integer(value), do: {:ok, value / 1}

  defp normalize_optional_float(_value, field) do
    {:error,
     Error.new(:invalid_proposal, "Agent proposal field must be numeric", %{field: field})}
  end
end
