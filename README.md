<div align="center">
  <img width="300" alt="gloam" src="https://github.com/user-attachments/assets/1243c391-692d-497b-9ba1-d3a06910185e" />
  
  [![CI](https://github.com/ccarvalho-eng/gloam/actions/workflows/ci.yml/badge.svg)](https://github.com/ccarvalho-eng/gloam/actions/workflows/ci.yml)
  [![License](https://img.shields.io/github/license/ccarvalho-eng/gloam.svg)](LICENSE)
  [![Elixir](https://img.shields.io/badge/elixir-1.19%2B-4B275F.svg)](https://elixir-lang.org)
  [![Godot](https://img.shields.io/badge/godot-4.x-478CBF.svg)](https://godotengine.org)
  [![Jido](https://img.shields.io/badge/powered%20by-Jido-2F6FED.svg)](https://github.com/agentjido/jido)
</div>

Gloam is an agentic game server for living worlds, built with Jido and designed
for any engine. It gives games persistent NPCs, factions, memory, seasons, and
consequences.

The first release focuses on a small but solid foundation: deterministic RPG
rules, replayable events, a fictional calendar, secure session tokens, and
client adapters that existing projects can plug into.

## Status

Gloam is being built server-first. The current foundation includes:

- a Mix server project under `server/`
- a supervised Bandit HTTP API for game clients
- pure calendar and session domain modules
- tests for time rollover, command validation, rejection, idempotency, and event folding
- documentation for setup, architecture, protocol, and engine integration

## Quick Start

```bash
cd server
mix setup
mix test
```

Engine adapters and runnable samples live under `examples/engines/`. Shared
world fixtures live under `examples/worlds/`. Future engine samples can sit
beside Godot and use the same HTTP protocol and event contracts.

## Why Gloam

Game engines are excellent at scenes, input, animation, physics, rendering, and
editor workflows. Gloam owns the slower world brain: NPC memory, factions,
schedules, quests, rumors, seasons, and consequences that continue to make sense
after a client reconnects.

Jido provides the internal agent primitives. Gloam keeps game authority in
deterministic rules: agents can propose behavior, but rules validate and events
record what happened.

In practice, an agent proposal is an ordinary game command suggested by an NPC,
faction, director, schedule, or future AI model. Gloam runs that proposed command
through the same rule engine and event log as player commands, so agents can add
life to the world without bypassing server authority.

## Engine Adapters

Gloam speaks JSON over HTTP today and keeps its protocol engine-neutral. A Unity,
Unreal, Godot, Phaser, Defold, terminal, or custom client should all map the same
basic ideas: create a session, send commands, read snapshots, and react to
events. The checked-in Godot adapter is the first sample, not the boundary of
the project.

## Repository Layout

```text
docs/                                user and architecture docs
server/                              Elixir server and runtime
examples/engines/godot/addons/gloam/ Godot adapter
examples/engines/godot/living_village/ Godot sample project
examples/worlds/living_village/      sample world content
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
