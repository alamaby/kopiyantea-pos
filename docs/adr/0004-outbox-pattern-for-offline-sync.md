# ADR-0004: Outbox Pattern for Offline Sync

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** Project owner

## Context

The app commits writes locally first and pushes to Supabase later. The push side has three failure modes that must be survived without losing data and without producing duplicates:

1. **Network down** — the user finishes a sale; the push must wait and retry.
2. **App killed mid-push** — OS kills the process between local write and server ack.
3. **Server transient errors** — 5xx, throttling, brief Supabase outage.

We also need a single, observable place to inspect what's pending sync — for the user (status indicator) and for diagnostics.

## Decision

Adopt the **outbox pattern** with a local Drift table `outbox` and a background worker.

Flow:
```
UI → Drift (write entity)  ─── same transaction ──→  Drift (write outbox row, status=pending)
                                                          │
                                                          ▼
                                         workmanager isolate / foreground tick
                                                          │
                                                          ▼
                                                  Supabase INSERT
                                                          │
                                                 on success: mark outbox row done
                                                 on failure: backoff + retry
```

- **Transactional enqueue.** The entity write and the outbox row write occur in one Drift transaction. Either both land or neither does. No "I created the sale but forgot to queue it" failure mode.
- **Idempotent push.** Each outbox row carries the entity's UUID v7 (ADR-0001). Server inserts use `ON CONFLICT (id) DO NOTHING`, so a retry after an unacknowledged success is harmless.
- **Backoff schedule.** `1s, 5s, 30s, 5m, 30m`, then plateau at 30m until manual intervention or app foreground.
- **Worker.** `workmanager` for OS-scheduled background sync; an in-app ticker also drains the outbox while the app is foreground and online.
- **Ordering.** Outbox is drained in FIFO order per entity type. Cross-type ordering is not guaranteed; entities are designed to be independently insertable (e.g. a `transaction_item` join is by `transaction_id`, the server accepts items even if they arrive before/after their header thanks to deferred FK or batched push within a single request).
- **Master-data pull is separate.** Pull is not in the outbox — outbox is the push channel only. Pull happens on app start, on foreground, and on a timer.

## Consequences

**Positive:**
- Crash-safe: nothing is "in flight in memory."
- Idempotent by design via UUID v7 primary key.
- Observable: a single table answers "what's pending?" and powers the UI sync indicator.
- Decoupled UI from network. POS never blocks on Supabase.

**Negative:**
- Two writes per entity (entity + outbox row). Acceptable — same transaction, ~negligible cost.
- Background isolates on Android have OEM-specific quirks (Doze, MIUI, etc.). Mitigation: foreground tick is the primary path; workmanager is the safety net. See Section 14 risk #1.
- Operators must understand: a stuck outbox row needs inspection, not deletion.

## Alternatives Considered

- **Direct write to Supabase with local cache invalidation.** Rejected: blocks UI on network; loses data on crash before the server ack.
- **Supabase Realtime + offline buffer.** Realtime is for pull, not durable push.
- **Manual sync button only.** Rejected: too much cognitive load on cashiers; sync must be invisible.
- **Two-phase commit / SAGA across devices.** Massively over-engineered for the failure surface we have.
