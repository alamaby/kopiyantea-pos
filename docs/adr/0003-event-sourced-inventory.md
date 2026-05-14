# ADR-0003: Event-Sourced Inventory

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** Project owner

## Context

Inventory levels are updated by multiple actors, often offline and concurrently:

- A cashier ringing up a sale (auto-decrement via `product_recipes`).
- A manager adjusting stock after a count.
- A purchase order arriving.
- Waste / spoilage.
- Branch-to-branch transfers.

If two devices each "set stock to 12 kg" while offline and sync later, last-write-wins silently loses one update. That is unacceptable for inventory — it directly maps to money lost or money invented.

The classic POS bug is exactly this: stock counts drift from reality because absolute-value updates collide.

## Decision

Inventory is **event-sourced** via the `inventory_movements` table. The application never updates a stock level absolutely; it appends a signed delta.

- `inventory_items.cached_stock` is a **derived** field. It is the running sum of `delta_signed` over all movements for that item, materialized for fast reads.
- All five movement types (`purchase`, `sale`, `adjustment`, `waste`, `transfer`) write a row to `inventory_movements` with a signed delta. A sale of 2 lattes that each consume 18g of beans appends `delta_signed = -36` for that bean item.
- An "adjustment" after a physical count writes a delta equal to `counted - current_cached_stock` — also a delta, not an absolute write.
- Server-side trigger reconciles `cached_stock` from movements on insert.
- Sync pushes movements, never `cached_stock`. Two devices both decrementing while offline both apply on reconnect; the result is correct.

## Consequences

**Positive:**
- Concurrent offline updates compose correctly — both deltas apply.
- Full audit trail: every change to stock has a row with type, reference, actor, and timestamp. Investigations are possible.
- "Why is the bean stock at 1.2 kg?" answerable by replaying movements.
- Negative cached stock is allowed (oversold), which surfaces inventory issues rather than hiding them with a clamp.

**Negative:**
- More writes per sale than a naive UPDATE. Acceptable — POS scale, not a high-frequency-trading scale.
- `cached_stock` can drift if the trigger is bypassed. Mitigation: it is computed-only; UI never writes it directly; periodic recompute job verifies integrity.
- Initial stock onboarding is a `purchase`-typed movement (or a synthetic "opening balance" adjustment), not a direct write.

## Alternatives Considered

- **Absolute updates with LWW.** Rejected — the failure mode above is the whole reason this ADR exists.
- **Pessimistic locking on inventory rows during sale.** Impossible offline.
- **CRDT counter (PN-Counter).** Functionally similar to delta-sourcing but heavier; we get the same merge property by appending immutable deltas without needing per-replica vector state.
- **Reservation pattern (hold then commit).** Adds complexity (timeouts, cleanup) without solving the offline merge problem.
