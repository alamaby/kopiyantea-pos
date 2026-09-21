# M4 — Org Tables Drift Typed

**Task:** Registrasi 4 tabel org ke `@DriftDatabase`, tulis ulang `OrganizationDao` typed, update semua caller, tambah test DAO baru.

**Files:**
- `lib/core/database/tables/organization_tables.dart` — rename `_X` → `X` (4 kelas), komentar TD-001 → catatan migrasi selesai.
- `lib/core/database/app_database.dart` — uncomment import + 4 tabel di `@DriftDatabase`; `schemaVersion` tetap 23; blok `from < 21` dan `_seedSubscriptionPlans()` tidak disentuh.
- `lib/core/database/daos/organization_dao.dart` — tulis ulang typed (92 baris): select/join/`insertOnConflictUpdate`, tanpa `customStatement`/`customSelect`/`_map*Row`/plain class; tanpa `insertOrReplace`.
- `lib/core/sync/sync_dtos.dart` — push pakai `.name` untuk field enum; pull parse via helper `_byNameOr`; `featuresJson` tetap `jsonEncode(json['features'])`.
- `lib/features/onboarding/create_org_screen.dart` — enum langsung (tanpa `.name`); import Row types dari `app_database.dart`.
- `lib/features/onboarding/join_org_screen.dart` — parse `value.role` (String) via `byName` + try/catch fallback `cashier`.
- `lib/features/settings/organization_card.dart` — tampilan enum (`row.status.name`).
- `lib/core/database/daos/dao_providers.dart` — tidak berubah.
- `test/core/database/organization_dao_test.dart` — baru (17 kasus).

**Decisions:**
- Hanya `insertOnConflictUpdate` (larangan `insertOrReplace` karena FK cascade `organization_members`).
- Review temuan: filter status di `getOrganizationsForUser` memakai `.equals('active')` mentah — diperbaiki jadi `.equalsValue(OrganizationMemberStatus.active)` + import `enums.dart`.

**Assumptions / Risks:**
- TD-001 "resolved" rapuh: build_runner crash `Null is not InterfaceElement` tanpa clear `.dart_tool/build` lebih dulu. Workaround berfungsi; true fix butuh freezed/riverpod 3.x.
- Perubahan String → enum merembet ke semua caller; `flutter analyze` dipakai sebagai kompas.

**Blockers:** Tidak ada (TD-001 workaround tercatat).

**Verification:**
- `dart run build_runner build --delete-conflicting-outputs` bersih (setelah clear cache).
- `flutter analyze` 0 error.
- `flutter test test/core/database/organization_dao_test.dart` hijau (17/17).
- Smoke manual fresh-install + upgrade DB lama v23: belum dijalankan (butuh device).

**Commit proposal:** `feat(database): register org tables in @DriftDatabase + rewrite OrganizationDao typed`

**Related plans:** `plans/2026-09-21-hardening-backlog-sprint.md` (M4), follow-up CI diff DDL⇄Drift terpisah.
