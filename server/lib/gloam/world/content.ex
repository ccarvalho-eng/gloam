defmodule Gloam.World.Content do
  @moduledoc """
  Built-in content used by examples and smoke tests.
  """

  alias Gloam.World.{Calendar, Location, NPC, Player, World}

  @spec living_village() :: %{world: World.t(), player: Player.t()}
  def living_village do
    %{
      world: %World{
        id: "living_village",
        calendar: living_village_calendar(),
        locations: living_village_locations(),
        npcs: living_village_npcs()
      },
      player: %Player{id: "player", location_id: "village_square"}
    }
  end

  defp living_village_calendar do
    Calendar.new!(
      days_per_season: 30,
      hours_per_day: 24,
      minutes_per_hour: 60,
      season_names: [:emberwake, :sungrove, :gloamfall, :frosthush],
      weekday_names: [:ashwake, :mirthtide, :wispwend, :thornrest, :starwane],
      year: 1,
      season_index: 0,
      day_of_season: 1,
      hour: 6,
      minute: 0
    )
  end

  defp living_village_locations do
    [
      %Location{
        id: "village_square",
        name: "Village Square",
        exits: ["blacksmith", "old_well", "tavern"],
        tags: [:public, :outdoors]
      },
      %Location{
        id: "blacksmith",
        name: "Blacksmith",
        exits: ["village_square"],
        tags: [:craft, :indoors]
      },
      %Location{
        id: "old_well",
        name: "Old Well",
        exits: ["village_square", "north_road"],
        tags: [:mystery, :outdoors]
      },
      %Location{
        id: "tavern",
        name: "Tavern",
        exits: ["village_square"],
        tags: [:social, :indoors]
      },
      %Location{
        id: "north_road",
        name: "North Road",
        exits: ["old_well"],
        tags: [:road, :outdoors]
      }
    ]
    |> Map.new(&{&1.id, &1})
  end

  defp living_village_npcs do
    [
      NPC.new!(%{
        id: "mara",
        name: "Mara",
        location_id: "blacksmith",
        disposition: :focused,
        schedule: %{
          morning: "blacksmith",
          day: "blacksmith",
          evening: "tavern",
          night: "tavern"
        }
      }),
      NPC.new!(%{
        id: "owen",
        name: "Owen",
        location_id: "old_well",
        disposition: :curious,
        schedule: %{
          morning: "old_well",
          day: "village_square",
          evening: "tavern",
          night: "old_well"
        }
      })
    ]
    |> Map.new(&{&1.id, &1})
  end
end
