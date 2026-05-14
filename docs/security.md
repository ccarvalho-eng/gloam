# Security

Gloam's security boundary is straightforward: clients request actions, the
server decides what is valid.

## Defaults

- Server-owned fields are ignored when sent by clients.
- Commands are normalized before validation.
- Rules validate every mutation.
- Event persistence happens before broadcast.
- Duplicate command IDs are idempotent.
- Payload size limits and per-session rate limits protect the runtime.
- Admin tooling requires admin auth outside local development.

## AI Boundary

AI is future-facing. It must never become an authority boundary.

- AI proposes commands, dialogue, summaries, or metadata.
- Rules validate proposed commands.
- AI output does not write directly to the event log.
- Every AI-enhanced feature needs deterministic fallback behavior.
