# Gloam

[![CI](https://github.com/ccarvalho-eng/gloam/actions/workflows/ci.yml/badge.svg)](https://github.com/ccarvalho-eng/gloam/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/gloam.svg)](https://hex.pm/packages/gloam)
[![Docs](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/gloam)
[![License](https://img.shields.io/github/license/ccarvalho-eng/gloam.svg)](LICENSE)
[![Elixir](https://img.shields.io/badge/elixir-1.19%2B-4B275F.svg)](https://elixir-lang.org)
[![Godot](https://img.shields.io/badge/godot-4.x-478CBF.svg)](https://godotengine.org)
[![Jido](https://img.shields.io/badge/powered%20by-Jido-2F6FED.svg)](https://github.com/agentjido/jido)

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

The Godot addon and Living Village sample live under `godot/`. Other engine
samples can use the same HTTP protocol and event contracts.

## Why Gloam

Game engines are excellent at scenes, input, animation, physics, rendering, and
editor workflows. Gloam owns the slower world brain: NPC memory, factions,
schedules, quests, rumors, seasons, and consequences that continue to make sense
after a client reconnects.

Jido provides the internal agent runtime. Gloam keeps game authority in
deterministic rules: agents can propose behavior, but rules validate and events
record what happened.

## Engine Adapters

Gloam speaks JSON over HTTP today and keeps its protocol engine-neutral. A Unity,
Unreal, Godot, Phaser, Defold, terminal, or custom client should all map the same
basic ideas: create a session, send commands, read snapshots, and react to
events. The checked-in Godot adapter is the first sample, not the boundary of
the project.

## Repository Layout

```text
docs/                         user and architecture docs
server/                       Elixir server and runtime
godot/addons/gloam/           Godot adapter
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
