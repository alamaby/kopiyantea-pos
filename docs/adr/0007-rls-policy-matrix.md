# ADR-0007: RLS Policy Matrix

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** Project owner

## Context

Supabase exposes Postgres directly to authenticated clients. Without Row Level Security, any authenticated cashier could in principle read another branch's transactions, edit prices, or worse — modify financial history. We need deny-by-default, role-and-branch-aware authorization at the database layer, not just in app code.

Three roles exist (`global_role` on `app_users`):

- **owner** — chain-wide read/write on master data, read-all on transactions.
- **manager** — branch-scoped read/write on local catalog overrides, inventory, customers; read on local transactions.
- **cashier** — branch-scoped read on catalog; insert on transactions assigned to themselves; read on their own/branch's transactions.

Cross-cutting rule: **no UPDATE or DELETE on `transactions` or `transaction_items`.** Append-only — voids are compensating transactions.

## Decision

- `ALTER TABLE … ENABLE ROW LEVEL SECURITY` on every table. Default deny.
- Two helper SQL functions, marked `STABLE SECURITY DEFINER`:

  - `user_has_branch_access(p_branch_id UUID)` — returns true if the current `auth.uid()` has a `user_branch_access` row for `p_branch_id`.
  - `user_global_role()` — returns the current user's `app_users.global_role`.

- Policies are declared per-table, per-operation. The full matrix:

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `branches` | owner + accessor | owner | owner | owner |
| `app_users` | self + owner + manager-of-shared-branch | owner | self (limited cols) + owner | owner |
| `user_branch_access` | self + owner | owner | — | owner |
| `products` | all authenticated | owner | owner | owner |
| `branch_products` | branch-accessor | owner / branch-manager | owner / branch-manager | owner |
| `inventory_items` | branch-accessor | owner / branch-manager | owner / branch-manager | owner |
| `inventory_movements` | branch-accessor | branch-accessor (with `created_by = auth.uid()`) | — | — |
| `product_recipes` | branch-accessor | owner / branch-manager | owner / branch-manager | owner / branch-manager |
| `customers` | all authenticated | all authenticated | all authenticated | owner |
| `transactions` | branch-accessor | branch-accessor (cashier_id = auth.uid()) | **denied** | **denied** |
| `transaction_items` | via parent transaction | branch-accessor (parent transaction owned) | **denied** | **denied** |
| `receipt_settings` | branch-accessor | owner / branch-manager | owner / branch-manager | owner |

- The Supabase **service role key never ships to clients**. It is reserved for server-side admin scripts and migrations only.
- All policies are versioned in `/supabase/migrations/`. Dashboard edits are forbidden (master prompt §2.2).

## Consequences

**Positive:**
- A compromised cashier device cannot read other branches.
- Financial integrity is enforced by the database, not by trust in the client.
- Auditable: policy text is in version control; changes go through PR.

**Negative:**
- Every new table needs an explicit policy set — easy to forget, so a CI check verifies `pg_class.relrowsecurity = true` for every public table.
- Helper functions run on every row; they are `STABLE` and indexed on `user_branch_access(user_id, branch_id)`, so cost stays sub-millisecond.
- Owners debugging "why can't I see this row?" must understand RLS. README + ADR-0007 are the answer.

## Alternatives Considered

- **App-layer authorization only.** Rejected: bypassable by any reverse-engineered token; violates defense-in-depth.
- **Per-branch Supabase projects.** Operationally horrible — schema changes must be applied N times.
- **Schema-per-tenant in one Postgres.** Considered for the multi-tenant SaaS direction (Section 14 risk #7) but out of scope for MVP single-tenant chain.
