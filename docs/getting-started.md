# Getting Started

## Requirements

- Elixir and Erlang/OTP
- Godot 4.x

## Run The Server

```bash
cd server
mix setup
mix test
mix run --no-halt
```

The HTTP and WebSocket surfaces will be added after the core runtime slice.

## Run The Godot Sample

The Living Village sample will be added under:

```text
godot/examples/living_village/
```

The intended first-run flow is:

1. Start the Gloam server.
2. Open the Living Village project in Godot.
3. Run the main scene.
4. Create a local session.
5. Submit commands like travel, talk, inspect, and wait.
6. Watch events update the Godot scene.

## Development Loop

Use examples as smoke tests:

```bash
cd server
mix precommit
```

When the Godot sample lands, run it after every server protocol change.
