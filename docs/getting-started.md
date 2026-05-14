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

The server starts a Bandit HTTP listener on `127.0.0.1:4000` by default.
Set `GLOAM_PORT` before boot when you need a different local port.

## Run The Godot Sample

Start the server in one terminal and keep it running:

```bash
cd server
mix run --no-halt
```

Open the Living Village sample with:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path godot
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
