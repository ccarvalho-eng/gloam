defmodule Gloam.Storage.EventStore do
  @moduledoc """
  Append-only file event store for local starter-kit durability.
  """

  alias Gloam.Events.Event

  @type path :: String.t()
  @type session_id :: String.t()

  @spec append(path(), session_id(), [Event.t()]) :: :ok | {:error, term()}
  def append(_path, _session_id, []), do: :ok

  def append(path, session_id, events) when is_binary(path) and is_binary(session_id) do
    file_path = event_log_path(path, session_id)

    with :ok <- File.mkdir_p(Path.dirname(file_path)),
         :ok <- append_events(file_path, events) do
      :ok
    end
  end

  @spec load(path(), session_id()) :: {:ok, [Event.t()]} | {:error, term()}
  def load(path, session_id) when is_binary(path) and is_binary(session_id) do
    path
    |> event_log_path(session_id)
    |> File.read()
    |> decode_read_result()
  end

  defp append_events(file_path, events) do
    binary =
      events
      |> Enum.map(&encode_event/1)
      |> IO.iodata_to_binary()

    File.write(file_path, binary, [:append])
  end

  defp encode_event(%Event{} = event) do
    binary = :erlang.term_to_binary(event)
    [<<byte_size(binary)::32>>, binary]
  end

  defp decode_read_result({:ok, binary}), do: decode_events(binary, [])
  defp decode_read_result({:error, :enoent}), do: {:ok, []}
  defp decode_read_result({:error, reason}), do: {:error, reason}

  defp decode_events(<<>>, events), do: {:ok, Enum.reverse(events)}

  defp decode_events(<<size::32, rest::binary>>, events) when byte_size(rest) >= size do
    <<event_binary::binary-size(size), remaining::binary>> = rest

    with {:ok, event} <- decode_event(event_binary) do
      decode_events(remaining, [event | events])
    end
  end

  defp decode_events(_binary, _events), do: {:error, :corrupt_event_log}

  defp decode_event(binary) do
    case :erlang.binary_to_term(binary, [:safe]) do
      %Event{} = event -> {:ok, event}
      _other -> {:error, :invalid_event}
    end
  rescue
    ArgumentError -> {:error, :invalid_event}
  end

  defp event_log_path(path, session_id) do
    Path.join([path, "sessions", session_id, "events.log"])
  end
end
