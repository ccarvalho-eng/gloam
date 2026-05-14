# Extensibility

Gloam should stay easy to plug into existing Godot games before it grows a DSL.

## V1 Approach

Use plain data and behaviours first:

- JSON content for starter worlds.
- Structs for domain data.
- Rule modules for command validation.
- Agent modules for autonomous proposals.
- Transport modules for JSON contracts.

This keeps the first release transparent and easy to debug.

## Spark Direction

Spark is a good fit for a later Elixir authoring DSL once the extension points
are proven by real examples.

Likely DSL areas:

- world definitions
- calendars and seasons
- command declarations
- quest states
- NPC schedules
- faction reputation rules
- agent reaction hooks

The DSL should compile into the same structs, rules, and event contracts used
by the data-first path. It should not become a second runtime.
