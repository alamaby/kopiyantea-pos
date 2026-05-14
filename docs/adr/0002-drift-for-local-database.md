# ADR-0002: Drift for Local Database

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** Project owner

## Context

The app must be fully functional offline: every cashier action, every product lookup, every receipt reprint, every inventory adjustment reads from and writes to a local store. The UI is reactive — POS cart, stock badges, receipt history must update instantly when underlying rows change. The local store also holds the outbox (ADR-0004) and event-sourced inventory movements (ADR-0003).

Requirements:
- Reactive queries (UI subscribes; rows change → widgets rebuild) without manual invalidation.
- Compile-time type safety from schema to query result. No string SQL with `Map<String, dynamic>` results.
- First-class migrations as code, versioned in the repo.
- Performant for tens of thousands of `transaction_items` and `inventory_movements` rows over the device's lifetime.

## Decision

Use **Drift** (`drift` + `drift_dev`) as the local persistence layer on top of SQLite.

- Schema defined as Dart `Table` classes in `/lib/core/database/`.
- DAOs expose reactive queries via `watch()` returning `Stream<T>` — Riverpod providers wrap these streams.
- Schema version increments through `MigrationStrategy` in the database class. Each upgrade is a numbered migration step.
- The Drift schema **mirrors** the Postgres DDL of Section 7 of the master prompt, with SQLite-compatible types (`TEXT` for `UUID`, `INTEGER` for `BOOLEAN`, `REAL` for `NUMERIC`).

## Consequences

**Positive:**
- `watch()` makes the offline-first UX trivial: write to the DB, the screen updates. No bus, no manual invalidation.
- End-to-end type safety: a typo in a column name fails the build.
- Migrations are reviewable in PRs and runnable in CI on a fresh DB.
- Works identically on Android, iOS, and the test VM (in-memory).

**Negative:**
- Two schemas to keep in sync (Postgres DDL and Drift). Discipline + CI diffing required (see ADR-0008 and Section 14 known risk #10).
- `NUMERIC` becomes `REAL` (double) on SQLite — money math must stay in domain pure functions (ADR-0009) and never rely on DB-side arithmetic for totals.
- Code generation adds a build step. Acceptable given the safety it buys.

## Alternatives Considered

- **sqflite + raw SQL.** Rejected: no type safety, no reactive streams without hand-rolled invalidation.
- **Isar / Hive (NoSQL).** Rejected: relational data (joins on `transaction_items → products`, `branch_products`) is awkward; migrations are weaker; no SQL for ad-hoc reports.
- **ObjectBox.** Closer fit than Hive, but Drift's reactive SQL and Postgres-shaped schema mirror remain decisively better for an app whose source of truth is also relational (Supabase).
- **Realm.** Sync model conflicts with our outbox pattern (ADR-0004); we want full control over what gets pushed.
