defmodule Gloam.World.CalendarTest do
  use ExUnit.Case, async: true

  alias Gloam.World.Calendar

  test "advances minutes into time bands, weekdays, seasons, and years" do
    calendar =
      Calendar.new!(
        days_per_season: 2,
        hours_per_day: 24,
        minutes_per_hour: 60,
        season_names: [:dawnmere, :sunreach, :gloaming, :frostwane],
        weekday_names: [:firstday, :secondday],
        year: 1,
        season_index: 0,
        day_of_season: 2,
        hour: 23,
        minute: 30
      )

    {:ok, advanced, facts} = Calendar.advance(calendar, 60)

    assert advanced.year == 1
    assert advanced.season == :sunreach
    assert advanced.day_of_season == 1
    assert advanced.weekday == :firstday
    assert advanced.hour == 0
    assert advanced.minute == 30
    assert advanced.time_band == :night

    assert :day_changed in facts
    assert :season_changed in facts
  end

  test "rolls over years when the final season completes" do
    calendar =
      Calendar.new!(
        days_per_season: 1,
        hours_per_day: 24,
        minutes_per_hour: 60,
        season_names: [:dawnmere, :sunreach, :gloaming, :frostwane],
        weekday_names: [:firstday],
        year: 7,
        season_index: 3,
        day_of_season: 1,
        hour: 23,
        minute: 59
      )

    {:ok, advanced, facts} = Calendar.advance(calendar, 1)

    assert advanced.year == 8
    assert advanced.season == :dawnmere
    assert advanced.day_of_season == 1
    assert advanced.hour == 0
    assert advanced.minute == 0

    assert :year_changed in facts
    assert :season_changed in facts
  end
end
