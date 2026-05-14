# Getting Started

## Requirements

- asdf with Erlang/OTP `28.4.1` and Elixir `1.19.5-otp-28`
- Godot 4.x for the included sample adapter

The repository includes a root `.tool-versions` file. From the repository root,
install the pinned BEAM toolchain with:

```bash
asdf install
```

## Run The Server

```bash
cd server
mix setup
mix test
mix run --no-halt
```

The server starts a Bandit HTTP listener on `127.0.0.1:4000` by default.
Set `GLOAM_PORT` before boot when you need a different local port.
Open `http://127.0.0.1:4000/` in a browser to confirm the API is running.

## Run The Godot Sample

Start the server in one terminal and keep it running:

```bash
cd server
mix run --no-halt
```

Open the Living Village sample with:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path examples/engines/godot
```

The intended first-run flow is:

1. Start the Gloam server.
2. Open `examples/engines/godot/project.godot` in Godot.
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

Run at least one engine sample after every server protocol change.
