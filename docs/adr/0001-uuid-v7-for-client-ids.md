# ADR-0001: UUID v7 for Client IDs

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** Project owner

## Context

KopiyanteaPOS is an offline-first POS. Every domain entity — transactions, transaction items, customers, inventory movements — must be creatable while offline and synced later. This forces ID generation onto the client. Two properties are non-negotiable:

1. **Globally unique without coordination.** Two cashiers on two devices must never collide.
2. **Idempotency.** When a queued sync replays after a flaky network, the server must recognize "I have already accepted this row" and not duplicate it. The natural way is to use the entity's primary key as the idempotency key (`INSERT … ON CONFLICT (id) DO NOTHING`).

Additionally, transactions are queried and paginated by time at every report screen and on the receipt list. A pure-random ID forces a separate `created_at` index and produces poor B-tree locality on insert.

## Decision

All client-generated primary keys are **UUID v7** — a time-ordered 128-bit ID with a millisecond Unix-timestamp prefix and 74 bits of randomness.

- ID generation happens on the client at entity creation time using the `uuid` package's v7 mode.
- The same `id` value travels through Drift → outbox → Supabase → `transactions.id`. No server-side rewrite.
- The server treats `id` as the idempotency key. Inserts use `ON CONFLICT (id) DO NOTHING`.
- Cursor pagination uses `id` directly (time-ordered), eliminating the need for a separate `(created_at, id)` composite cursor.

## Consequences

**Positive:**
- Offline creation is safe by construction — no collision risk, no server round-trip.
- Replayed syncs are inherently idempotent; the outbox can retry aggressively without dedup tables.
- B-tree inserts on `transactions.id` are append-mostly (good page locality, less index bloat than UUID v4).
- Receipts can be listed and paginated without a secondary index lookup.

**Negative:**
- UUID v7 leaks creation time. Acceptable here — transactions already store `client_created_at` openly.
- 36-char string in logs is bulky vs. an integer sequence. Acceptable for a POS volume.
- Clock skew between devices can reorder IDs slightly across devices. Conflict resolution (ADR-0004) uses server-side `server_received_at`, not the v7 timestamp, for ordering authority.

## Alternatives Considered

- **UUID v4 (random).** Rejected: poor index locality; requires separate time index for pagination.
- **Server-generated bigint sequences.** Rejected outright: impossible offline.
- **Snowflake / ULID.** ULID is functionally equivalent to UUID v7 but with weaker tooling support in Dart and Postgres. UUID v7 won on ecosystem (`uuid` package, native Postgres `UUID` type).
- **Composite keys (`branch_id` + local counter).** Rejected: complicates joins, breaks Drift codegen ergonomics, and per-branch counters still need coordination on multi-device setups within a branch.
