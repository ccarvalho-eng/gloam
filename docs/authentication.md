# Authentication

Gloam uses practical secure defaults without making local development painful.

## Modes

- `dev_open`: local development only. Refused in production.
- `session_token`: default starter-kit mode.
- `external`: a host game backend mints or validates identity.

## Session Token Flow

1. Godot creates or resumes a session.
2. The server returns a short-lived bearer token.
3. HTTP requests include `Authorization: Bearer <token>`.
4. WebSocket connections send the same token in handshake headers.
5. Commands are accepted only when token session, player, and scope match.

## Scopes

- `session:read`
- `command:write`
- `events:stream`
- `admin:inspect`

## Rules

- Do not embed production secrets in Godot.
- Use TLS outside local development.
- Reject actor/session mismatches before rules run.
- Never log bearer tokens.
- Return structured errors without leaking internals.
