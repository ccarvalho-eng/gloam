# Next Steps

This document tracks potential next slices for Gloam. It is intentionally
practical: each item should make Gloam more useful as an agentic game server
that real engine clients can plug into.

## Product Direction

Gloam should stay engine-neutral and server-first.

Game engines own rendering, animation, input, physics, cameras, and editor
workflows. Gloam owns durable world behavior: authoritative rules, replayable
events, NPC state, clocks, schedules, memory, factions, quests, and agent
proposals.

Jido should be used for autonomous planning and reactive world behavior, but it
should not bypass Gloam's deterministic rule and event boundaries. Agents may
propose; sessions validate; events record.

## Priorities

1. Make client integration easier.
2. Make world state more expressive.
3. Expand Jido usage where it adds real agent behavior.
4. Keep runtime durability and security boring.
5. Add examples only when they prove a reusable integration surface.

## Candidate Slices

### 1. Scene Projection API

Purpose: give engines the exact state needed to render the player's current
area without requiring clients to inspect the full session snapshot.

Shape:

- `GET /api/sessions/:id/scene`
- returns current location, exits, local NPCs, calendar, and visible facts
- sorted, stable JSON fields
- bearer auth with read scope

Acceptance criteria:

- moving the player changes the scene projection
- NPC schedule ticks change visible NPCs when NPCs enter or leave the location
- projections are derived from session state, not separately persisted
- Godot sample can use the scene response as its primary render model

Avoid:

- hidden visibility rules before the basic projection is useful
- rendering concepts such as sprites, cameras, or engine node names

### 2. Event Cursor API

Purpose: let clients efficiently react to changes after their last known event.

Shape:

- `GET /api/sessions/:id/events?after=<event_id>`
- returns events after the cursor and the latest cursor
- stable ordering by persisted event order
- same event JSON shape used elsewhere

Acceptance criteria:

- a client can create a session, store a cursor, send commands, tick time, and
  fetch only new events
- unknown cursors return a structured error
- missing cursor returns the full session event history
- persisted restart keeps cursor behavior consistent

Avoid:

- server push before the polling contract is solid
- relying on event IDs as sortable values unless the event store guarantees it

### 3. Server-Sent Event Stream

Purpose: provide a simple realtime option for engines and tools that can keep a
connection open.

Shape:

- `GET /api/sessions/:id/stream`
- emits replayable event JSON
- supports `Last-Event-ID` or an explicit cursor
- heartbeat comments for idle connections

Acceptance criteria:

- stream reconnect can resume from a cursor
- disconnects do not affect session state
- command and tick events appear in order
- tests cover reconnect and stale cursor behavior

Avoid:

- WebSockets until the event and scene contracts prove insufficient
- per-engine stream formats

### 4. NPC Interaction Command

Purpose: let games interact with NPCs through the same command/rule/event model
used for movement and ticks.

Shape:

- command type: `talk`
- target: NPC ID
- params: topic or intent
- events: `npc_spoke`, `relationship_changed`, or `npc_remembered`

Acceptance criteria:

- talking to an NPC outside the player's current location is rejected
- valid interaction persists replayable events
- deterministic default dialogue works without an AI provider
- Jido can propose the interaction result, but session rules remain
  authoritative

Avoid:

- open-ended LLM calls in the session process
- dialogue trees that become a separate engine-specific content system

### 5. NPC Memory Events

Purpose: make NPCs feel persistent by recording durable memories as events.

Shape:

- event type: `npc_remembered`
- event type: `npc_memory_faded` if retention is added later
- memory entries include kind, subject, value, and source event

Acceptance criteria:

- memory changes are replayable from events
- duplicate memory writes are idempotent when given the same source
- snapshots and scene projection expose relevant memory safely
- no secrets or auth material can be stored through public params

Avoid:

- storing opaque prompt text as canonical memory
- making memory mutation a direct transport API before rules exist

### 6. Jido Signal Bridge

Purpose: expose Gloam events to Jido as signals so agents can react to world
changes without owning session state.

Shape:

- translate committed Gloam events into Jido signals
- signal types such as `gloam.calendar.advanced`, `gloam.npc.moved`, and
  `gloam.player.moved`
- signals emitted after events are persisted

Acceptance criteria:

- event persistence happens before signal emission
- failed signal delivery does not corrupt session state
- signal payloads contain event IDs for traceability
- tests cover ordering and failure behavior

Avoid:

- making signals the source of truth
- emitting from pure domain modules

### 7. Agent Proposal Inbox

Purpose: keep agent suggestions inspectable before they become commands or
events.

Shape:

- proposed command records include agent ID, reason, confidence, and command
- proposals can be accepted, rejected, or expire
- future tools can show pending proposals to designers or moderators

Acceptance criteria:

- accepting a proposal submits a normal command
- rejecting a proposal records an auditable reason
- expired proposals cannot mutate state
- replay or restart cannot apply a proposal twice

Avoid:

- implicit auto-accept for powerful mutations
- coupling proposal storage to any one AI provider

### 8. Stronger Persistence Adapter Boundary

Purpose: keep the local file event store useful while making it clear how a
production adapter should work.

Shape:

- event store behaviour
- file adapter remains default
- future Postgres adapter can implement the same contract

Acceptance criteria:

- session runtime depends on the behaviour, not a concrete module
- append and load errors remain structured at the runtime boundary
- tests cover corrupt logs and append failures
- docs explain durability expectations for production

Avoid:

- adding a database dependency before the adapter contract is stable
- hiding partial write or corrupt log behavior

### 9. Engine Adapter Contract Tests

Purpose: make it easier to add Unity, Unreal, Phaser, Defold, terminal, or
custom engine samples without drifting from the core protocol.

Shape:

- protocol fixtures under `examples/worlds`
- shared smoke expectations for session creation, movement, ticks, scene, and
  events
- each engine sample proves the same minimum contract

Acceptance criteria:

- Godot sample remains the reference example
- adding another engine does not require server changes
- CI can run at least one headless or protocol-level smoke path

Avoid:

- turning examples into product features
- engine-specific fields in core server responses

### 10. Observability And Operations

Purpose: make Gloam easier to run and debug as a game backend.

Shape:

- structured logs at HTTP/runtime boundaries
- telemetry events for session start, command accepted/rejected, tick, event
  append, and planner execution
- health endpoint includes storage readiness when practical

Acceptance criteria:

- logs never include bearer tokens or secrets
- telemetry does not fire before durable state changes when ordering matters
- docs explain how to inspect a session and event log

Avoid:

- noisy logs inside pure domain code
- metrics that require a specific hosting provider

## Suggested Order

The most useful near-term sequence is:

1. Scene Projection API.
2. Event Cursor API.
3. NPC Interaction Command.
4. NPC Memory Events.
5. Jido Signal Bridge.

This order gives real clients better integration first, then adds richer RPG
behavior, then expands reactive agent behavior on top of durable events.

## Quality Bar

Every slice should include:

- public docs for the new contract
- tests for success and rejection paths
- replay or restart coverage when persisted events are involved
- engine smoke coverage when client-facing behavior changes
- structured errors at API boundaries
- no provider-specific AI assumptions

The server should remain useful without an AI key. AI integration can improve
planning later, but the default world must be deterministic, testable, and
playable from day one.
