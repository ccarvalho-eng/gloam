# Gloam

Gloam is a Jido-powered living-world server for Godot games with persistent
NPCs, factions, memory, seasons, and consequences.

The first release focuses on a small but solid foundation: deterministic RPG
rules, replayable events, a fictional calendar, secure session tokens, and a
Godot addon that existing projects can plug into.

## Status

Gloam is being built server-first. The current foundation includes:

- a Mix server project under `server/`
- pure calendar and session domain modules
- tests for time rollover, command validation, rejection, idempotency, and event folding
- documentation for setup, architecture, protocol, and Godot integration

## Quick Start

```bash
cd server
mix setup
mix test
```

The Godot addon and Living Village sample will live under `godot/`.

## Why Gloam

Godot is excellent at scenes, input, animation, physics, and rendering. Gloam
owns the slower world brain: NPC memory, factions, schedules, quests, rumors,
seasons, and consequences that continue to make sense after a client reconnects.

Jido provides the internal agent runtime. Gloam keeps game authority in
deterministic rules: agents can propose behavior, but rules validate and events
record what happened.

## Repository Layout

```text
docs/                         user and architecture docs
server/                       Elixir server and runtime
godot/addons/gloam/           Godot addon
godot/examples/living_village Godot sample project
examples/living_village_world sample world content
```

## Documentation

- [Getting started](docs/getting-started.md)
- [Using Gloam in an existing Godot game](docs/godot-existing-game.md)
- [Authentication](docs/authentication.md)
- [Security](docs/security.md)
- [Protocol](docs/protocol.md)
- [Calendar](docs/calendar.md)
- [RPG primitives](docs/rpg-primitives.md)
- [Extensibility](docs/extensibility.md)
- [Architecture](docs/architecture.md)
- [Operations](docs/operations.md)
