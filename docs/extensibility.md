# Extensibility

Gloam should stay easy to plug into existing games before it grows a DSL.

## V1 Approach

Use plain data and behaviours first:

- JSON content for starter worlds.
- Structs for domain data.
- Rule modules for command validation.
- Agent modules for autonomous proposals.
- Transport modules for JSON contracts.

This keeps the first release transparent and easy to debug.

## Agent Proposals

The first Jido integration is intentionally small:
`Gloam.Agents.propose_command/2` runs a Jido action that turns agent intent into
a normal Gloam command.

Agents do not mutate world state directly. They propose commands such as:

- an NPC guide suggesting travel to a nearby location
- a faction scheduler suggesting a talk, inspect, or wait command
- a future storyteller model suggesting a quest-facing command

The session runtime still validates the command, persists events, deduplicates
command IDs, and exposes the resulting snapshot. This keeps AI and autonomous
systems useful without making them authoritative.

```elixir
{:ok, proposal} =
  Gloam.Agents.propose_command(%{
    agent_id: "village-guide",
    reason: "The player asked for directions.",
    command: %{
      "id" => "agent-cmd-1",
      "session_id" => "session-1",
      "actor_id" => "player",
      "type" => "travel",
      "target_id" => "blacksmith",
      "params" => %{}
    }
  })

Session.submit_command(session, proposal.command)
```

`Gloam.Agents.plan_npc_movements/2` uses the same pattern for deterministic NPC
schedules: a Jido action proposes NPC movement from the current time band, then
the session runtime persists `npc_moved` events if the proposal changes world
state.

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
