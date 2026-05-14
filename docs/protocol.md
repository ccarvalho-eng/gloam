# Protocol

The protocol is JSON over HTTP and WebSocket.

## HTTP

- `POST /api/sessions`
- `GET /api/sessions/:id/snapshot`
- `POST /api/sessions/:id/commands`
- `POST /api/sessions/:id/ticks`
- `POST /api/auth/refresh`

## WebSocket

- `GET /ws/sessions/:id`

Server messages:

- `snapshot`
- `event`
- `command.accepted`
- `command.rejected`
- `heartbeat`
- `resync.required`
- `error`

## Command

```json
{
  "id": "cmd-123",
  "session_id": "session-1",
  "actor_id": "player",
  "type": "travel",
  "target_id": "blacksmith",
  "params": {},
  "source": "player"
}
```

Command decoding uses an explicit allowlist for command types and sources. It
does not convert arbitrary strings into atoms.

## Tick Events

Scheduled ticks and `wait` commands both emit `calendar_advanced` events. Engine
clients should treat these as authoritative calendar updates and refresh local
time, schedules, lighting, UI clocks, or seasonal state from the event payload.

Host engines can also advance session time explicitly:

```json
{
  "minutes": 5
}
```

The tick endpoint requires the same session bearer token and `command:write`
scope as command submission. Accepted ticks return `calendar_advanced` events.

## Error

```json
{
  "code": "invalid_command",
  "message": "Target location is not reachable from current location",
  "details": {},
  "correlation_id": "cmd-123"
}
```
