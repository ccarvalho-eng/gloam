defmodule Gloam.Transport.MessageJSON do
  @moduledoc """
  JSON-safe outbound messages for game clients.
  """

  alias Gloam.Events.Event
  alias Gloam.World.{Calendar, Player}

  @spec snapshot(map()) :: map()
  def snapshot(snapshot) when is_map(snapshot) do
    %{
      "type" => "snapshot",
      "session_id" => snapshot.session_id,
      "world_id" => snapshot.world_id,
      "calendar" => calendar(snapshot.calendar),
      "player" => player(snapshot.player),
      "event_count" => snapshot.event_count
    }
  end

  @spec event(Event.t()) :: map()
  def event(%Event{} = event) do
    %{
      "type" => "event",
      "event" => %{
        "id" => event.id,
        "session_id" => event.session_id,
        "type" => to_string(event.type),
        "actor_id" => event.actor_id,
        "subject_id" => event.subject_id,
        "data" => stringify_value(event.data),
        "correlation_id" => event.correlation_id
      }
    }
  end

  defp calendar(%Calendar{} = calendar) do
    %{
      "year" => calendar.year,
      "season" => to_string(calendar.season),
      "day_of_season" => calendar.day_of_season,
      "weekday" => to_string(calendar.weekday),
      "hour" => calendar.hour,
      "minute" => calendar.minute,
      "time_band" => to_string(calendar.time_band)
    }
  end

  defp player(%Player{} = player) do
    %{
      "id" => player.id,
      "location_id" => player.location_id,
      "faction_standing" => stringify_value(player.faction_standing),
      "relationships" => stringify_value(player.relationships),
      "quests" => stringify_value(player.quests),
      "rumors" => player.rumors |> MapSet.to_list() |> Enum.sort()
    }
  end

  defp stringify_value(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} -> {to_string(key), stringify_value(nested_value)} end)
  end

  defp stringify_value(value) when is_list(value), do: Enum.map(value, &stringify_value/1)
  defp stringify_value(value) when is_atom(value), do: to_string(value)
  defp stringify_value(value), do: value
end
