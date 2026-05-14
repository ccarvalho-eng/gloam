# Calendar

Gloam worlds use fictional calendars so games can react to time without tying
their lore to real-world dates.

## Living Village Defaults

Seasons:

- `emberwake`
- `sungrove`
- `gloamfall`
- `frosthush`

Weekdays:

- `ashwake`
- `mirthtide`
- `wispwend`
- `thornrest`
- `starwane`

Time bands:

- `morning`
- `day`
- `evening`
- `night`

## Rules

- Ticks advance the calendar by in-world minutes.
- The calendar changes through events.
- `wait` uses the same event path as scheduled ticks.
- Seasonal effects must be replayable from the event log.

## Runtime Ticks

Session runtimes support manual and scheduled ticks. Ticks are disabled by
default so host games can decide whether time advances from player commands,
engine frames, server schedules, or their own simulation loop.

When enabled, scheduled ticks produce `calendar_advanced` events with
`actor_id: "system"` and the world ID as the subject. The event payload contains
the updated calendar, changed facts, and the number of in-world minutes advanced.
Ticks may also emit `npc_moved` events when a scheduled NPC changes location for
the new time band.

Environment variables:

- `GLOAM_TICKS_ENABLED=true`: enables scheduled ticks for newly started
  sessions.
- `GLOAM_TICK_INTERVAL_MS`: real milliseconds between scheduled ticks.
- `GLOAM_TICK_MINUTES`: in-world minutes advanced per scheduled tick.
