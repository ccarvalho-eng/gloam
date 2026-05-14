# Authentication

Gloam uses practical secure defaults without making local development painful.

## Modes

- `dev_open`: local development only. Refused in production.
- `session_token`: default starter-kit mode.
- `external`: a host game backend mints or validates identity.

## Session Token Flow

1. A game client creates or resumes a session.
2. The server returns a short-lived bearer token.
3. HTTP requests include `Authorization: Bearer <token>`.
4. WebSocket connections send the same token in handshake headers.
5. Commands are accepted only when token session, player, and scope match.
6. Explicit tick requests require the token session and `command:write` scope.

## Godot Web Exports

Godot's `WebSocketPeer.handshake_headers` are not supported in Web exports
because browsers restrict custom WebSocket handshake headers. Native Godot
clients can use bearer headers. Browser exports should use a host-game session
cookie or a short-lived WebSocket ticket endpoint when that transport lands.

## Scopes

- `session:read`
- `command:write`
- `events:stream`
- `admin:inspect`

## Rules

- Do not embed production secrets in game clients.
- Use TLS outside local development.
- Reject actor/session mismatches before rules run.
- Never log bearer tokens.
- Return structured errors without leaking internals.
