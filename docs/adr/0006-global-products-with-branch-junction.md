# ADR-0006: Global Products with Branch Junction

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** Project owner

## Context

The chain operates multiple branches. Each branch needs control over:

- Which items it sells (a coffee branch and a roastery-only branch share the same menu engine but expose different SKUs).
- Local price overrides (a tourist-area branch may charge more).
- Standing discounts (happy hour at branch A only).
- Custom display names (a translation, a local nickname).
- Availability toggles (sold out today).

But the catalog itself — name, category, base price, image — should be edited once by the owner and propagate to all branches. Duplicating the catalog per branch invites drift ("Latte 16oz" vs "Latte 16 oz") and N inserts for every product change.

## Decision

**Two-table catalog**:

- `products` — global, owner-owned master catalog. One row per product across the entire chain.
- `branch_products` — composite-PK junction `(product_id, branch_id)` carrying per-branch overrides: `price_override`, `is_available`, `custom_name`, `discount_percentage`, `discount_valid_until`.

Resolution rules at sale time (encoded in `effectiveUnitPrice` — see ADR-0011):

1. Display name: `branch_products.custom_name ?? products.name`.
2. Price before discount: `branch_products.price_override ?? products.base_price`.
3. Discount: `branch_products.discount_percentage` if `discount_valid_until` is null or future, else `0`.
4. Available for sale: a branch can sell a product only if a `branch_products` row exists with `is_available = TRUE`.

RLS (ADR-0007): `products` writable only by `owner`. `branch_products` writable by `owner` globally and by `manager` for branches they have access to.

## Consequences

**Positive:**
- Owner edits catalog once, all branches see it.
- Branches retain genuine autonomy (price, name, discount, availability) without duplicating data.
- Audit and reporting across the chain are trivial — `products.id` is stable everywhere.
- Adding a new branch is one insert per available product into the junction, not a catalog clone.

**Negative:**
- Two-table read for every menu render. Mitigation: indexed join on `(branch_id, is_available)`; Drift `watch()` keeps it on the local DB.
- "Branch-only" products (never appear elsewhere) still go in the global `products` table. Mild semantic mismatch; acceptable.
- Soft-deleting a product chain-wide is `products.is_active = FALSE`. A branch wanting to keep selling it would need a separate "branch-private products" concept, deferred to future work.

## Alternatives Considered

- **One products table per branch.** Rejected: data duplication, drift, no chain-level reports.
- **Single `products` table with a `branch_id` column.** Rejected: every catalog edit becomes N writes; cross-branch reporting requires deduplication by name.
- **Two-table with full denormalization (copy `name`/`base_price` into junction).** Rejected: same drift problem as the per-branch table approach.
- **Document-store nested per-branch overrides on `products`.** Rejected: kills query power, breaks Drift relational ergonomics.
