# Architecture

Gloam separates pure game rules from runtime effects.

## Boundaries

- `world`: structs and pure domain data.
- `commands`: normalized intent.
- `rules`: deterministic validation and event planning.
- `events`: canonical facts and folding.
- `runtime`: supervised OTP processes.
- `agents`: autonomous proposal logic.
- `transport`: JSON encoding and decoding.
- `auth`: token and scope checks.
- `gloam_web`: delivery only.

## Runtime Direction

- A registry indexes sessions.
- A dynamic supervisor starts session runtimes on demand.
- One session process serializes commands and ticks per session.
- Slow work runs through a task supervisor.
- Events persist before broadcast or follow-up dispatch.
- Snapshots are derived from events.

## Agent Boundary

Jido agents can propose behavior. They do not mutate world state directly.
Agent proposals are normalized into `Gloam.Commands.Command` structs and then
sent through the same deterministic session/rules/event path as player commands.
NPC schedule planning follows the same rule: Jido actions propose movement, and
Gloam persists replayable events.
