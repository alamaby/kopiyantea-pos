# ADR-0008: Non-Destructive Migration Policy

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** Project owner

## Context

The app is offline-first and deployed via the Play Store / App Store, which means at any given moment **multiple app versions are talking to the same Supabase database**. A cashier may go offline for two days and come back running the previous app version. A single destructive migration ("drop the old column now that we've renamed it") will break those clients silently and irrecoverably.

Financial-grade systems also require that no migration ever puts historical data at risk. A `DROP COLUMN` on a transactions table is, in the worst case, a permanent loss.

## Decision

**Migrations are non-destructive by default.** Schema renames and removals follow a multi-release expand-then-contract sequence:

1. **ADD** the new column / table — nullable or with a safe default. Old code ignores it.
2. **BACKFILL** existing rows. Idempotent script in `/supabase/migrations/` or a one-shot.
3. **DEPLOY** an app version that **reads both** old and new locations, prefers new, falls back to old.
4. **DEPLOY** an app version that **reads new only** and writes new only. Old version usage decays.
5. After a quantified soak window (e.g., 30 days of no minimum-supported-version client writes to the old column, confirmed by query), **DROP** the old column in a separate migration.

Hard rules:

- Same migration MUST NOT introduce a replacement and drop the old artifact.
- Every destructive migration (any `DROP`, `ALTER … DROP COLUMN`, `ALTER … TYPE` that loses data) requires its own ADR with rollout dates and the soak query result.
- Migrations live in `/supabase/migrations/YYYYMMDDHHMMSS_descriptive_name.sql`. Filenames are append-only; never edit a merged migration — write a new one.
- CI runs all migrations from scratch on a fresh Postgres on every PR. A migration that fails on a clean DB is rejected.
- Drift schema versions increment monotonically; each upgrade in `MigrationStrategy` matches the Postgres step.
- `transactions` and `transaction_items` are append-only at the schema level (no UPDATE/DELETE policies, ADR-0007). Schema changes that touch these tables require extra review.

## Consequences

**Positive:**
- Older app versions keep working through a schema evolution.
- Rollbacks are real: revert the client release; the DB still serves it.
- Mistakes are isolated — a dropped column is its own change, reviewed in its own ADR.

**Negative:**
- Slower delivery for renames — at least three releases instead of one.
- Temporarily duplicated data during the soak window. Acceptable.
- Discipline burden on the team to follow the sequence; CI checks help but aren't sufficient. Code review is the backstop.

## Alternatives Considered

- **"Break old clients on next release."** Rejected: violates the offline-first contract; cashiers lose minutes/hours of pending transactions through a forced sign-out and reinstall.
- **Force minimum app version on each schema change.** Operationally hostile to staff working through a release rollout window; also offline-first apps can't reach the user to enforce it.
- **Hide schema behind a stored-procedure API.** Plausible long-term but heavy for current scope; current direct-table reads + RLS are sufficient.
