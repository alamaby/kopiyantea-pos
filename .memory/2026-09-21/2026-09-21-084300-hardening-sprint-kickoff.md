# Hardening Sprint — M3–M6 Progress

**Task:** M3–M6 hardening backlog implementasi (lanjutan entry kickoff)

**Files changed (M3–M6):**
- `.memory/README.md` — active memory index
- `.memory/2026-09-21/2026-09-21-084300-hardening-sprint-kickoff.md` — kickoff entry
- `PROJECT_STATUS.md` — updated last-updated + Maintenance Log
- `lib/core/database/tables/organization_tables.dart` — renamed table classes, TD-001 note
- `lib/core/database/app_database.dart` — registered org tables in @DriftDatabase
- `lib/core/database/daos/organization_dao.dart` — rewritten typed DAO (195 lines → 95 lines)
- `lib/core/sync/sync_dtos.dart` — enum push/pull DTOs, added `_byNameOr` helper
- `lib/features/onboarding/create_org_screen.dart` — enum fields, app_database import
- `lib/features/onboarding/join_org_screen.dart` — enum role parsing with fallback
- `lib/features/settings/organization_card.dart` — enum comparisons, added imports
- `test/core/database/organization_dao_test.dart` — new 17-case test suite
- `test/core/sync/sync_provider_test.dart` — fixed: added currentOrganizationIdProvider override
- `test/core/utils/formatters_test.dart` — fixed: CLDR id_ID time separator ':' vs '.'
- `test/widget_test.dart` — fixed: auth guard routes to login, not POS
- `test/core/sync/sync_conflict_test.dart` — new 4-case LWW/idempotency/FIFO test
- `docs/rls-smoke-checklist.md` — manual RLS verification guide
- `docs/qa-device-matrix.md` — 15-step device QA matrix (user-side execution)

**Decisions:**
- TD-001 "resolved" claim from commit 99578c2 was inaccurate — drift_dev 2.21.2 still crashes on build_runner with analyzer 6.4.1 on certain files. However, clearing `.dart_tool/build` cache allows build_runner to succeed for this project. This is a fragile workaround; true resolution requires upgrading freezed/riverpod to major 3.x.
- Org tables now registered in @DriftDatabase; DAO fully typed with Drift query builder.
- String → enum migration propagates to sync_dtos (push `.name`, pull via `_byNameOr`).
- QA device matrix is document-only; execution remains user-side.

**Assumptions / Risks:**
- Build_runner success after cache clear may not be reproducible on CI or clean checkout. Risk: next developer may hit same crash.
- Pre-existing bug in `clearOrganizationData()` referencing `user_branch_access` instead of `user_branch_accesses` (unrelated to this sprint).
- Test widget_test.dart relies on `.env` existing locally; in CI environment may need env stubs.

**Blockers:**
- None. All 126 tests pass (0 failed).

**Verification performed:**
- `flutter analyze` — 0 errors, ~449 warnings/info (mostly pre-existing style)
- `flutter test` — 126/126 passed (including 17 org DAO + 4 sync conflict + 5 fixed pre-existing)
- `dart run build_runner build --delete-conflicting-outputs` — succeeds after cache clear

**Commit proposal:**
- `feat(database): register org tables in @DriftDatabase + rewrite OrganizationDao typed`
- `test: fix 5 pre-existing failures + add sync/conflict tests + RLS smoke doc`
- `docs: add QA device matrix and update plan progress`

**Related plans:**
- `plans/2026-09-21-hardening-backlog-sprint.md`
- Follow-up (not in scope): CI diff DDL⇄Drift
