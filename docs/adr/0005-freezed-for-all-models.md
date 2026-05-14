# ADR-0005: Freezed for All Models

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** Project owner

## Context

Domain entities cross many layers: Drift row → domain entity → Supabase DTO → UI state. Every layer needs equality, hash, `copyWith`, JSON, and — for state machines like `AsyncValue` or auth status — algebraic sum types (sealed unions).

Hand-writing these is error-prone (a forgotten field in `==` is a real bug class) and verbose. Two competing tools were in scope: `freezed` and `dart_mappable`.

## Decision

Use **Freezed** (`freezed` + `freezed_annotation`) with **json_serializable** for all domain entities, DTOs, and UI state.

- One package for value types and sealed unions: no `class Result` ceremony, no manual `==`/`hashCode`.
- Pair with `json_serializable` (bundled in the Freezed ecosystem) for Supabase DTO ⇄ JSON.
- Supabase row models are **hand-written Freezed classes that mirror the DDL** (option A from master prompt §2.4). A CI test diffs Postgres column lists against the Dart class fields and fails on divergence.
- Drift's data classes are not replaced — Drift generates its own row classes. Mapping `DriftRow → DomainEntity (Freezed)` happens in the repository layer.

## Consequences

**Positive:**
- One mental model for value types across the codebase.
- Sealed unions (`AuthState`, `SyncStatus`, `PaymentMethod` parsers) get exhaustive pattern matching via Dart 3 `switch` expressions — compiler catches missing cases.
- `copyWith` and JSON come for free.

**Negative:**
- Two layers of generated code (Drift + Freezed). Build times grow; mitigation is the standard `dart run build_runner watch` workflow.
- Hand-written Supabase models require discipline (see ADR-0008 and Section 14 risk #10). The CI diff test is the safety net.
- Migrating between Freezed major versions has historically been costly. Acceptable given the value delivered.

## Alternatives Considered

- **dart_mappable.** Comparable feature set; a few teams prefer it. Freezed has the larger community and the better sealed-union ergonomics, which we lean on heavily for state machines.
- **Hand-rolled value types.** Rejected: the entire reason this ADR exists is to not do that for ~40+ entities.
- **equatable + manual JSON.** Half a solution. No sealed unions. Rejected.
- **Generating Dart models from Postgres DDL.** Tempting (option B in master prompt §2.4) but introduces a tighter coupling and a separate tool to maintain. We chose option A: hand-written + CI diff.
