# Using Gloam In An Existing Godot Game

Gloam should feel like a backend brain, not a replacement for your Godot game.
Godot keeps rendering, input, animation, physics, and scene orchestration.

## Intended Integration

1. Copy `examples/engines/godot/addons/gloam` into your project.
2. Enable the plugin.
3. The plugin adds `GloamClient` as an Autoload singleton.
4. Configure server URL and auth mode.
5. Bind existing NPC, location, and quest nodes to Gloam IDs.
6. Convert player interactions into Gloam commands.
7. Listen for Gloam events and update scenes.

## Godot Primitives

The addon should use ordinary Godot patterns:

- Autoload for global client access.
- Signals for snapshots, events, rejections, reconnects, and resyncs.
- Groups like `gloam_npc`, `gloam_location`, and `gloam_quest_ui`.
- Exported properties or resources for binding server IDs to scene nodes.
- `HTTPRequest` for auth, session creation, snapshots, and commands.
- `WebSocketPeer` for live event streaming.

For Web exports, custom WebSocket handshake headers are browser-restricted.
Use native exports with bearer headers, or plan for cookie/ticket auth when
targeting browsers.

## Minimal Shape

```gdscript
func _ready():
    GloamClient.event_received.connect(_on_gloam_event)
    GloamClient.configure("http://localhost:4000")
    GloamClient.create_local_session("player")
    GloamClient.connect_events()

func _on_player_interact(target_id):
    GloamClient.submit_command("talk", target_id, {})

func _on_gloam_event(event):
    get_tree().call_group("gloam_npc", "apply_gloam_event", event)
```

The exact addon API will be locked when the transport layer lands.
