defmodule Gloam.World.Calendar do
  @moduledoc """
  Fictional world calendar used by sessions, schedules, and seasonal rules.
  """

  @type fact ::
          :minute_changed | :time_band_changed | :day_changed | :season_changed | :year_changed

  @type t :: %__MODULE__{
          days_per_season: pos_integer(),
          hours_per_day: pos_integer(),
          minutes_per_hour: pos_integer(),
          season_names: [atom()],
          weekday_names: [atom()],
          year: pos_integer(),
          season_index: non_neg_integer(),
          day_of_season: pos_integer(),
          hour: non_neg_integer(),
          minute: non_neg_integer(),
          season: atom(),
          weekday: atom(),
          time_band: atom()
        }

  defstruct [
    :days_per_season,
    :hours_per_day,
    :minutes_per_hour,
    :season_names,
    :weekday_names,
    :year,
    :season_index,
    :day_of_season,
    :hour,
    :minute,
    :season,
    :weekday,
    :time_band
  ]

  @required [
    :days_per_season,
    :hours_per_day,
    :minutes_per_hour,
    :season_names,
    :weekday_names,
    :year,
    :season_index,
    :day_of_season,
    :hour,
    :minute
  ]

  @spec new!(keyword()) :: t()
  def new!(attrs) when is_list(attrs) do
    attrs
    |> Map.new()
    |> new!()
  end

  def new!(attrs) when is_map(attrs) do
    :ok = validate_required(attrs)
    :ok = validate_positive(attrs, [:days_per_season, :hours_per_day, :minutes_per_hour, :year])
    :ok = validate_non_empty_list(attrs, :season_names)
    :ok = validate_non_empty_list(attrs, :weekday_names)

    attrs
    |> Map.take(@required)
    |> normalize()
  end

  @spec advance(t(), non_neg_integer()) :: {:ok, t(), [fact()]} | {:error, :invalid_minutes}
  def advance(%__MODULE__{} = calendar, minutes) when is_integer(minutes) and minutes >= 0 do
    advanced =
      calendar
      |> absolute_minute()
      |> Kernel.+(minutes)
      |> from_absolute_minute(calendar)

    {:ok, advanced, change_facts(calendar, advanced)}
  end

  def advance(%__MODULE__{}, _minutes), do: {:error, :invalid_minutes}

  defp validate_required(attrs) do
    missing = Enum.reject(@required, &Map.has_key?(attrs, &1))

    case missing do
      [] -> :ok
      _missing -> raise ArgumentError, "missing calendar fields: #{inspect(missing)}"
    end
  end

  defp validate_positive(attrs, keys) do
    invalid = Enum.reject(keys, fn key -> valid_positive?(Map.fetch!(attrs, key)) end)

    case invalid do
      [] -> :ok
      _invalid -> raise ArgumentError, "calendar fields must be positive: #{inspect(invalid)}"
    end
  end

  defp validate_non_empty_list(attrs, key) do
    value = Map.fetch!(attrs, key)

    case value do
      [_head | _tail] -> :ok
      _other -> raise ArgumentError, "#{key} must be a non-empty list"
    end
  end

  defp valid_positive?(value), do: is_integer(value) and value > 0

  defp normalize(attrs) do
    attrs =
      attrs
      |> Map.update!(:season_index, &normalize_index(&1, length(attrs.season_names)))
      |> Map.update!(:day_of_season, &normalize_day(&1, attrs.days_per_season))
      |> Map.update!(:hour, &normalize_index(&1, attrs.hours_per_day))
      |> Map.update!(:minute, &normalize_index(&1, attrs.minutes_per_hour))

    struct!(__MODULE__, Map.merge(attrs, derived(attrs)))
  end

  defp derived(attrs) do
    %{
      season: value_at!(attrs.season_names, attrs.season_index),
      weekday: weekday(attrs),
      time_band: time_band(attrs)
    }
  end

  defp weekday(attrs) do
    day_index = absolute_day(attrs) |> rem(length(attrs.weekday_names))
    value_at!(attrs.weekday_names, day_index)
  end

  defp normalize_day(day, days_per_season) when is_integer(day) and day >= 1 do
    rem(day - 1, days_per_season) + 1
  end

  defp normalize_index(value, size) when is_integer(value) and size > 0 do
    value |> rem(size) |> positive_remainder(size)
  end

  defp positive_remainder(value, size) when value < 0, do: value + size
  defp positive_remainder(value, _size), do: value

  defp absolute_minute(%__MODULE__{} = calendar) do
    calendar
    |> Map.from_struct()
    |> absolute_minute()
  end

  defp absolute_minute(attrs) do
    day_minutes = attrs.hours_per_day * attrs.minutes_per_hour
    absolute_day(attrs) * day_minutes + attrs.hour * attrs.minutes_per_hour + attrs.minute
  end

  defp absolute_day(attrs) do
    seasons_per_year = length(attrs.season_names)
    days_per_year = attrs.days_per_season * seasons_per_year
    completed_years = attrs.year - 1
    completed_seasons = attrs.season_index * attrs.days_per_season

    completed_years * days_per_year + completed_seasons + attrs.day_of_season - 1
  end

  defp from_absolute_minute(absolute_minute, %__MODULE__{} = template) do
    attrs = Map.from_struct(template)
    day_minutes = attrs.hours_per_day * attrs.minutes_per_hour
    absolute_day = div(absolute_minute, day_minutes)
    minute_of_day = rem(absolute_minute, day_minutes)
    days_per_year = attrs.days_per_season * length(attrs.season_names)
    day_of_year = rem(absolute_day, days_per_year)

    attrs
    |> Map.merge(%{
      year: div(absolute_day, days_per_year) + 1,
      season_index: div(day_of_year, attrs.days_per_season),
      day_of_season: rem(day_of_year, attrs.days_per_season) + 1,
      hour: div(minute_of_day, attrs.minutes_per_hour),
      minute: rem(minute_of_day, attrs.minutes_per_hour)
    })
    |> new!()
  end

  defp change_facts(before, after_calendar) do
    [
      changed?(:minute_changed, before.minute != after_calendar.minute),
      changed?(:time_band_changed, before.time_band != after_calendar.time_band),
      changed?(:day_changed, before.day_of_season != after_calendar.day_of_season),
      changed?(:season_changed, before.season != after_calendar.season),
      changed?(:year_changed, before.year != after_calendar.year)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp changed?(fact, true), do: fact
  defp changed?(_fact, false), do: nil

  defp value_at!(values, index) do
    Enum.find_value(Enum.with_index(values), fn
      {value, ^index} -> value
      {_value, _other_index} -> nil
    end)
  end

  defp time_band(%{hour: hour}) when hour in 6..11, do: :morning
  defp time_band(%{hour: hour}) when hour in 12..17, do: :day
  defp time_band(%{hour: hour}) when hour in 18..21, do: :evening
  defp time_band(_attrs), do: :night
end
