defmodule Gloam.Transport.CommandJSON do
  @moduledoc """
  JSON-safe command encoding and decoding for game clients.
  """

  alias Gloam.Commands.Command
  alias Gloam.Transport.Error

  @required_fields ["id", "session_id", "actor_id", "type", "source"]

  @command_types %{
    "look" => :look,
    "travel" => :travel,
    "talk" => :talk,
    "inspect" => :inspect,
    "wait" => :wait
  }

  @command_type_strings Map.new(@command_types, fn {string, atom} -> {atom, string} end)

  @sources %{
    "player" => :player,
    "agent" => :agent,
    "system" => :system
  }

  @source_strings Map.new(@sources, fn {string, atom} -> {atom, string} end)

  @spec decode_json(String.t()) :: {:ok, Command.t()} | {:error, Error.t()}
  def decode_json(json) when is_binary(json) do
    with {:ok, payload} <- Jason.decode(json) do
      decode(payload)
    else
      {:error, _reason} -> {:error, Error.new(:invalid_json, "Command JSON is invalid")}
    end
  end

  @spec decode(map()) :: {:ok, Command.t()} | {:error, Error.t()}
  def decode(payload) when is_map(payload) do
    with :ok <- require_fields(payload),
         {:ok, type} <- decode_type(payload["type"]),
         {:ok, source} <- decode_source(payload["source"]),
         {:ok, params} <- decode_params(type, Map.get(payload, "params", %{})) do
      {:ok,
       Command.new!(%{
         id: payload["id"],
         session_id: payload["session_id"],
         actor_id: payload["actor_id"],
         type: type,
         target_id: Map.get(payload, "target_id"),
         params: params,
         source: source
       })}
    end
  end

  @spec encode(Command.t()) :: map()
  def encode(%Command{} = command) do
    %{
      "id" => command.id,
      "session_id" => command.session_id,
      "actor_id" => command.actor_id,
      "type" => Map.fetch!(@command_type_strings, command.type),
      "target_id" => command.target_id,
      "params" => encode_params(command),
      "source" => Map.fetch!(@source_strings, command.source)
    }
  end

  defp require_fields(payload) do
    missing = Enum.find(@required_fields, fn field -> missing_field?(payload, field) end)

    case missing do
      nil -> :ok
      field -> {:error, Error.new(:missing_field, "Command field is required", %{field: field})}
    end
  end

  defp missing_field?(payload, field) do
    not Map.has_key?(payload, field) or is_nil(payload[field])
  end

  defp decode_type(type) when is_binary(type) do
    case Map.fetch(@command_types, type) do
      {:ok, command_type} -> {:ok, command_type}
      :error -> {:error, Error.new(:unknown_command_type, "Command type is not supported")}
    end
  end

  defp decode_type(_type),
    do: {:error, Error.new(:unknown_command_type, "Command type is not supported")}

  defp decode_source(source) when is_binary(source) do
    case Map.fetch(@sources, source) do
      {:ok, decoded_source} -> {:ok, decoded_source}
      :error -> {:error, Error.new(:unknown_command_source, "Command source is not supported")}
    end
  end

  defp decode_source(_source),
    do: {:error, Error.new(:unknown_command_source, "Command source is not supported")}

  defp decode_params(:wait, %{"minutes" => minutes}) when is_integer(minutes) do
    {:ok, %{minutes: minutes}}
  end

  defp decode_params(:wait, params) when map_size(params) == 0, do: {:ok, %{}}

  defp decode_params(:wait, _params) do
    {:error, Error.new(:invalid_params, "Wait command params are invalid")}
  end

  defp decode_params(_type, params) when is_map(params), do: {:ok, params}

  defp decode_params(_type, _params),
    do: {:error, Error.new(:invalid_params, "Command params must be an object")}

  defp encode_params(%Command{type: :wait, params: %{minutes: minutes}}),
    do: %{"minutes" => minutes}

  defp encode_params(%Command{params: params}), do: stringify_map(params)

  defp stringify_map(params) do
    Map.new(params, fn {key, value} -> {to_string(key), stringify_value(value)} end)
  end

  defp stringify_value(value) when is_map(value), do: stringify_map(value)
  defp stringify_value(value) when is_list(value), do: Enum.map(value, &stringify_value/1)
  defp stringify_value(value) when is_atom(value), do: to_string(value)
  defp stringify_value(value), do: value
end
