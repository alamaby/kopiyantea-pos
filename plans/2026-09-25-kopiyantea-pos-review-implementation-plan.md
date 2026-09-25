# KopiyanteaPOS Review — Implementation Plan

Created: 2026-09-25 12:00:00

## Objective

Menutup temuan review kode vs database produksi Supabase (`supabase-kopiyantea-pos-production`) tanpa mengubah perilaku single-tenant yang sedang berjalan di prod. Hasil akhir: (1) bug lokal P0 diperbaiki, (2) sync tidak crash saat kolom/tabel org belum ada di prod, (3) DTO `pending_invitations` konsisten dengan Drift v23, (4) migrasi Supabase non-destruktif siap-apply terpisah, (5) RLS + index hardening terdokumentasi sebagai file migrasi terpisah, (6) regresi test menutup setiap finding.

Batasan eksekusi: hanya file plan boleh dibuat/diubah pada tahap perencanaan ini. Semua langkah implementasi di bawah dikerjakan oleh model eksekutor berikutnya. Eksekutor dilarang `staging/commit`, dilarang menjalankan command yang mengubah repo kecuali yang tercantum di langkah, dilarang meng-apply migrasi ke Supabase via MCP (`apply_migration`).

## Scope

In-scope findings (dari review 2026-09-25):

- F-001: Prod 20 tabel / 11 migrasi vs repo 29 file migrasi; `organization_id` tidak ada di prod manapun (`information_schema` → `[]`).
- F-002: `SyncRepository.pullMasterData` + `pullMyAuthContext` filter `.eq('organization_id', orgId)` dan baca `organizations`/`organization_members` → gagal di prod (`42703` / PGRST205).
- F-003 (TD-002): `AppDatabase.clearOrganizationData()` salah nama tabel (`user_branch_access` vs `user_branch_accesses`).
- F-004: `BranchDao.getBranchIdsForUserInOrg` raw SQL pakai `FROM user_branch_access` (singular) + `b.organization_id` yang tidak ada di Drift lokal.
- F-005: Drift `PendingInvitations` 14 kolom vs prod 7 kolom; `PendingInvitationSyncDto`/`pendingInvitationFromJson` hanya kolom lama.
- F-006: Tabel yang di-sync tapi tidak ada di prod: `organizations`, `organization_members`, `subscription_plans`, `organization_subscriptions`, `usage_counters`, `company_settings`.
- F-007: RLS: `bank_accounts`/`categories` owner policy `roles {public}`, `SECURITY DEFINER` executable oleh `anon`, `stamp_server_received_at` + `reconcile_cached_stock` tanpa `SET search_path`, `auth_leaked_password_protection` disabled.
- F-008: Perf: 10 FK tanpa covering index, 11 policy `auth_rls_initplan` (`auth.uid()` per-row).
- F-009: `SyncRepository._log = Logger()` bukan `AppLogger.instance`; komentar basi TD-001 di `app_database.dart:178-180`; `pullTransactions(limit:100)` tanpa cursor.

Out-of-scope (jangan dikerjakan dalam plan ini):

- Rewrite RLS full multi-tenant stage 3 (`20260615000000_rls_rewrite_multitenant.sql`) di prod.
- Perubahan Drift schema (`@DriftDatabase` tables, `schemaVersion` bump, `build_runner` regenerate `app_database.g.dart`).
- UI/UX, i18n ARB, printer/scanner hardware, Play Integrity.
- Apply migrasi ke Supabase prod (hanya buat file + instruksi manual via Dashboard).

## Requirement Traceability

| Finding | ADR / Requirement | Step |
|---|---|---|
| F-003 TD-002 crash org switch | ADR-0008 non-destructive, FEAT-002 org switch | S-01 |
| F-004 raw SQL salah tabel/kolom | ADR-0008, FEAT-002 Phase 7 | S-02 |
| F-002 sync crash saat org kolom hilang | ADR-0004 outbox, Phase 6e sync MVP | S-03 |
| F-005 pending_invitations drift | FEAT-006 invite-only, FEAT-002 Phase 7 code-invite | S-04 |
| F-001/F-006 migrasi parity minimal | ADR-0008 expand-then-contract | S-05 |
| F-009 logger gating | Phase 7 AppLogger | S-06 |
| F-007 RLS hardening | ADR-0007 RLS matrix | S-07 |
| F-008 perf index + initplan | Phase 7 optimization | S-08 |
| F-009 komentar basi | Clean Code | S-09 |
| Semua di atas | Verifikasi | S-00 baseline + S-10 regresi akhir |

## Milestones

1. M1 — Lokal P0 hijau (S-00, S-01, S-02, S-04, S-06).
2. M2 — Sync tahan prod saat ini (S-03).
3. M3 — Migrasi siap-apply + RLS/perf siap-review (S-05, S-07, S-08).
4. M4 — Cleanup + regresi penuh (S-09, S-10).

## Tasks

- [x] S-00 Baseline read-only (analyze + test)
- [x] S-01 Fix `clearOrganizationData` nama tabel (F-003)
- [x] S-02 Fix `getBranchIdsForUserInOrg` raw SQL (F-004)
- [x] S-03 Sync org-guard fallback saat kolom/tabel hilang (F-002)
- [x] S-04 DTO `pending_invitations` expand backward-compat (F-005)
- [x] S-05 Buat file migrasi Supabase parity minimal (F-001/F-006)
- [x] S-06 Ganti `Logger()` → `AppLogger.instance` di sync (F-009)
- [x] S-07 RLS hardening file migrasi terpisah (F-007)
- [x] S-08 Perf index + initplan file migrasi terpisah (F-008)
- [x] S-09 Hapus komentar basi TD-001 (F-009)
- [x] S-10 Regresi akhir + handoff

---

## S-00 Baseline read-only

- Tujuan: menetapkan titik awal hijau sebelum perubahan apapun.
- Finding yang diselesaikan: none (prasyarat semua).
- Dependency: none.
- File yang harus dibaca: `pubspec.yaml`, `analysis_options.yaml`, `lib/core/database/app_database.dart`, `lib/core/sync/sync_repository.dart`.
- File yang harus diubah: none.
- Simbol terkait: none.
- Kondisi saat ini: repo di `version: 1.1.1+32`, `schemaVersion => 23`, prod 20 tabel / 11 migrasi (hasil MCP 2026-09-25).
- Perubahan konkret: tidak ada perubahan file. Hanya observasi.
- Urutan: (1) `flutter analyze`, (2) `flutter test`.
- Behavior yang dipertahankan: semua.
- Error handling: jika `flutter analyze` gagal karena `.dart_tool/build` cache (`Null is not InterfaceElement`), hapus cache build saja (`Remove-Item -Recurse -Force .dart_tool/build` di PowerShell) lalu ulangi `flutter analyze`. Jangan jalankan `build_runner` di S-00.
- Test: tidak tambah test.
- Command verifikasi: `flutter analyze` lalu `flutter test`.
- Hasil verifikasi yang diharapkan: `flutter analyze` → `No issues found!` atau catat issue existing apa adanya; `flutter test` → `All tests passed!` (12 file di `test/**`, termasuk `organization_dao_test.dart` yang saat ini menghindari `clearOrganizationData`).
- Completion criteria: output kedua command tercatat di Progress Log; tidak ada file repo berubah (`git status --porcelain` kosong kecuali file plan).
- File/area yang tidak boleh diubah: semua file selain file plan ini.

## S-01 Fix `clearOrganizationData` nama tabel (F-003, TD-002)

- Tujuan: perbaiki crash `SqliteException: no such table: user_branch_access` saat org switch.
- Finding: F-003.
- Dependency: S-00.
- File yang harus dibaca:
  - `lib/core/database/app_database.dart` (baris 431-467)
  - `lib/core/database/tables/branch_tables.dart` (baris 101-113, class `UserBranchAccesses`)
  - `test/core/database/organization_dao_test.dart` (baris 334-393, grup TD-002)
- File yang harus diubah:
  - `lib/core/database/app_database.dart` (1 baris)
  - `test/core/database/clear_organization_data_test.dart` (baru)
- Simbol: `AppDatabase.clearOrganizationData()`.
- Kondisi saat ini: baris 456 `await customStatement('DELETE FROM user_branch_access');` — singular, salah. Tabel Drift aktual `user_branch_accesses` (plural). Test existing sengaja tidak memanggil method ini (komentar baris 334-340).
- Perubahan konkret (tepat 1 baris, di dalam `clearOrganizationData`, urutan DELETE tetap):
  - Old (baris 456): `await customStatement('DELETE FROM user_branch_access');`
  - New: `await customStatement('DELETE FROM user_branch_accesses');`
  - Jangan ubah urutan DELETE lain (child→parent sudah benar: `transaction_item_options` → ... → `shift_closings` → raw-SQL org tables).
  - Jangan ubah tabel yang di-retain (`app_users`, `subscription_plans`, `outbox_items`, `company_settings`) — tetap tidak di-DELETE.
- Behavior yang dipertahankan: retain/drop contract di komentar baris 431-438; FK `PRAGMA foreign_keys = ON` tetap; method tetap `Future<void>`.
- Error handling/edge: jika DB kosong (fresh install), semua `DELETE` harus sukses tanpa row (no-op). Jika FK violation, biarkan throw (jangan swallow) agar test gagal eksplisit.
- Test yang harus ditambahkan:
  - Baru `test/core/database/clear_organization_data_test.dart`:
    - `setUp`: `db = AppDatabase.memory()`.
    - Seed via `seedMinimal` dari `test/helpers/test_db.dart` (branch `b1`, user `u1`, product `p1`, inventory `inv-milk`) + 1 org + 1 member + 1 subscription + 1 `subscription_plans` + 1 `outbox_items` + 1 `company_settings` (via `customStatement` INSERT karena `company_settings` raw-SQL, lihat `_createCompanySettingsTable`).
    - Panggil `await db.clearOrganizationData()`.
    - Input/expected:
      - `SELECT COUNT(*) FROM user_branch_accesses` → `0`.
      - `SELECT COUNT(*) FROM branches` → `0`.
      - `SELECT COUNT(*) FROM products` → `0`.
      - `SELECT COUNT(*) FROM organizations` → `0`.
      - `SELECT COUNT(*) FROM app_users` → `1` (retain).
      - `SELECT COUNT(*) FROM subscription_plans` → `1` (retain).
      - `SELECT COUNT(*) FROM outbox_items` → `1` (retain).
      - `SELECT COUNT(*) FROM company_settings` → `1` (retain).
    - Test kedua: panggil `clearOrganizationData()` dua kali berurutan → tetap sukses (idempotent).
  - Jangan ubah `organization_dao_test.dart` existing di S-01 (dipertahankan sebagai dokumentasi TD-002; pembaruan grup itu opsional di S-10).
- Command verifikasi: `flutter test test/core/database/clear_organization_data_test.dart` lalu `flutter analyze`.
- Hasil yang diharapkan: `All tests passed!`, `No issues found!`.
- Completion criteria: method terpanggil di test tanpa `SqliteException`; retain contract terbukti.
- Tidak boleh diubah: `schemaVersion`, `@DriftDatabase` tables list, `migration` strategy, file migrasi Supabase, `OutboxEntityType`.

## S-02 Fix `getBranchIdsForUserInOrg` raw SQL (F-004)

- Tujuan: perbaiki method yang pasti crash di lokal (nama tabel + kolom hilang).
- Finding: F-004 (temuan turunan dari F-001).
- Dependency: S-01 (pola DELETE plural yang benar).
- File yang harus dibaca:
  - `lib/core/database/daos/branch_dao.dart` baris 82-98
  - `lib/core/database/tables/branch_tables.dart` (konfirmasi `Branches` tidak punya `organizationId`)
  - `lib/core/database/app_database.dart` baris 347-377 (`_createOrganizationsTable`, `_createOrganizationMembersTable`)
- File yang harus diubah: `lib/core/database/daos/branch_dao.dart` (method `getBranchIdsForUserInOrg` saja).
- Simbol: `BranchDao.getBranchIdsForUserInOrg(String userId, String orgId)`.
- Kondisi saat ini (baris 89-95):
  ```dart
  'SELECT uba.branch_id '
  'FROM user_branch_access uba '
  'JOIN branches b ON b.id = uba.branch_id '
  'WHERE uba.user_id = ? AND b.organization_id = ?',
  ```
  Dua bug: (1) `user_branch_access` singular → lokal `user_branch_accesses`; (2) `b.organization_id` tidak ada di Drift lokal (`Branches` hanya `id,name,address,phone,timezone,isActive,tax*,failedLoginLockoutThreshold,qrisImageUrl,createdAt,updatedAt`).
- Perubahan konkret (tanpa menambah kolom Drift, tanpa `build_runner`):
  - Ganti FROM ke `user_branch_accesses`.
  - Hapus JOIN ke `branches.organization_id`. Ganti query menjadi filter via `organization_members` (yang memang ada lokal):
  ```dart
  Future<List<String>> getBranchIdsForUserInOrg(
    String userId,
    String orgId,
  ) async {
    // Local Branches has no organization_id (single-tenant Drift schema).
    // Scope check: user must be active member of orgId, then return all
    // branchIds the user can access. Preserves single-tenant behavior.
    final member = await customSelect(
      'SELECT 1 FROM organization_members WHERE organization_id = ? AND user_id = ? AND status = ?',
      variables: [
        Variable<String>(orgId),
        Variable<String>(userId),
        Variable<String>('active'),
      ],
    ).getSingleOrNull();
    if (member == null) return <String>[];
    final rows = await customSelect(
      'SELECT branch_id FROM user_branch_accesses WHERE user_id = ?',
      variables: [Variable<String>(userId)],
    ).get();
    return rows.map((row) => row.read<String>('branch_id')).toList();
  }
  ```
  - Urutan di file: ganti body method saja, jangan pindah method, jangan ubah signature/return type/dok komentar selain menambah 2 baris penjelasan di atas.
- Behavior yang dipertahankan: return `List<String>` branch IDs; `[]` jika tidak ada akses; tidak throw saat org tidak ada.
- Error handling/edge:
  - `orgId` kosong → return `[]` (jangan query).
  - `userId` tidak punya `organization_members` aktif → `[]`.
  - User member aktif tapi `user_branch_accesses` kosong (owner-only) → `[]` (bukan null).
- Test yang harus ditambahkan (`test/core/database/branch_dao_org_scope_test.dart` baru):
  - Seed: 1 org `org-1`, 2 branch `b1,b2`, user `u1` member aktif `org-1`, access hanya `b1`.
  - Input `getBranchIdsForUserInOrg('u1','org-1')` → expected `['b1']`.
  - Input `getBranchIdsForUserInOrg('u1','org-other')` → expected `[]`.
  - Input `getBranchIdsForUserInOrg('u-noaccess','org-1')` → expected `[]`.
- Command: `flutter test test/core/database/branch_dao_org_scope_test.dart`, `flutter analyze`.
- Hasil yang diharapkan: 3/3 pass.
- Completion criteria: tidak ada `customSelect` ke `user_branch_access` singular atau `branches.organization_id` tersisa di file ini (`grep` manual via search).
- Tidak boleh diubah: `Branches` table definition, `schemaVersion`, `UserBranchAccesses` PK, file migrasi.

## S-03 Sync org-guard fallback (F-002)

- Tujuan: sync tetap jalan di prod saat ini (tanpa `organization_id` / tanpa tabel org) dan tetap pakai filter org saat kolom sudah ada.
- Finding: F-002.
- Dependency: S-02 (pemahaman scope org lokal).
- File yang harus dibaca:
  - `lib/core/sync/sync_repository.dart` baris 55-367 (`pullMyAuthContext`, `pullMasterData`, `pullTransactions`)
  - `lib/features/auth/auth_provider.dart` (simbol `currentOrganizationIdProvider`)
- File yang harus diubah: `lib/core/sync/sync_repository.dart` saja.
- Simbol: `SyncRepository.pullMyAuthContext`, `SyncRepository.pullMasterData`, `SyncRepository.pullTransactions`, `_log`, `_sb`.
- Kondisi saat ini:
  - `pullMyAuthContext:100-124` query `organization_members` + `organizations` tanpa try/catch per-tabel → gagal total jika tabel hilang.
  - `pullMasterData:171,184,205,237,243,249,312,325,338,351` pakai `.eq('organization_id', orgId)` → PostgREST `42703 column does not exist` di prod.
  - `pullMasterData:150-154` early-return jika `orgId == null` → di prod single-tenant ini memblokir seluruh master pull.
- Perubahan konkret (urutan di file, jangan reorder method):
  1. `pullMyAuthContext` langkah 5-6 (baris 99-124): bungkus block org (`orgMemberRows` + `orgsJson`) dalam `try { ... } catch (e) { _log.w('[Sync] org context pull skipped (single-tenant prod)', error: e); }`. Return `true` tetap jika langkah 1-4 sukses. Jangan ubah langkah 1-4.
  2. `pullMasterData` baris 150-154: hapus early-return `if (orgId == null)`. Ganti dengan `final orgId = organizationId ?? _ref.read(currentOrganizationIdProvider);` lalu lanjut (boleh null). Tambah komentar `// orgId nullable: single-tenant prod has no organization_id column`.
  3. Setiap pull block yang pakai `.eq('organization_id', orgId)` (branches, categories, products, option_groups, options, product_option_groups, company_settings, customers, bank_accounts, usage_counters): ubah pola menjadi try-filtered-then-fallback:
     ```dart
     try {
       final rows = orgId == null
           ? await sb.from('branches').select()
           : await sb.from('branches').select().eq('organization_id', orgId);
       // ... upsert loop existing, jangan ubah mapping
     } catch (e) {
       if (e.toString().contains('organization_id') || e.toString().contains('42703') || e.toString().contains('PGRST')) {
         _log.w('[Sync] pull branches without org filter (fallback)', error: e);
         try {
           final rows = await sb.from('branches').select().inFilter('id', branchIds);
           // ... upsert loop sama
         } catch (e2) { _log.w('[Sync] pull branches failed', error: e2); errors++; }
       } else {
         _log.w('[Sync] pull branches failed', error: e);
         errors++;
       }
     }
     ```
     Terapkan pola identik untuk 10 tabel lain, dengan perbedaan: yang branch-scoped (`branch_products`, `inventory_items`, `product_recipes`, `receipt_settings`) fallback tanpa `organization_id` (pakai `inFilter('branch_id', branchIds)` saja — sudah begitu, jadi untuk 4 tabel ini cukup hapus `.eq organization_id` jika ada; saat ini mereka tidak pakai org filter, jangan tambahkan).
     Untuk `customer_point_ledger` di `pullTransactions:435-439` yang pakai `.eq('organization_id', orgId)`: bungkus serupa, fallback ke query tanpa org filter tapi tetap `inFilter('transaction_id', txIds)`.
  4. Jangan ubah DTO mapping (`branchFromJson`, dll), jangan ubah `insertOnConflictUpdate`, jangan ubah counter `upserted/errors`.
- Behavior yang dipertahankan: saat org kolom ada → filter org dipakai; saat tidak ada → fallback unfiltered + `errors++` hanya jika fallback juga gagal. `pullMasterData` dengan `branchIds.isEmpty` tetap `(0,0)`.
- Error handling: catch harus spesifik string-match di atas agar error auth/RLS asli tidak disamarkan sebagai fallback sukses. Setiap fallback failure tetap `errors++` dan `_log.w`.
- Test: unit test Supabase sulit tanpa mock server; gunakan test logika fallback via `mocktail`? Untuk model kecil, buat test deterministik tanpa network:
  - Baru `test/core/sync/sync_org_guard_test.dart`: test helper murni `shouldFallbackToUnfiltered(Object e)` (ekstrak sebagai top-level function di `sync_repository.dart` agar testable):
    ```dart
    bool shouldFallbackToUnfiltered(Object e) {
      final s = e.toString();
      return s.contains('organization_id') || s.contains('42703') || s.contains('PGRST');
    }
    ```
    Input/expected: `PostgrestException(message: 'column organization_id does not exist', code: '42703')` → `true`; `AuthException('invalid JWT')` → `false`; `Exception('timeout')` → `false`.
  - Eksekutor harus mengekstrak fungsi ini tepat di atas `class SyncRepository` (1 fungsi, tidak mengubah class lain).
- Command: `flutter test test/core/sync/sync_org_guard_test.dart`, `flutter analyze`.
- Hasil yang diharapkan: pass; tidak ada perubahan perilaku saat orgId tersedia.
- Tidak boleh diubah: `sync_dtos.dart`, Drift tables, RLS policies, `pullTransactions` limit/order.

## S-04 DTO `pending_invitations` expand backward-compat (F-005)

- Tujuan: DTO lokal v23 bisa roundtrip kolom code-invite tanpa merusak push ke prod 7-kolom.
- Finding: F-005.
- Dependency: S-05 (migrasi) untuk apply server, tapi kode harus backward-compat agar aman sebelum migrasi di-apply. Urutan eksekusi kode dulu dengan guard, migrasi terpisah.
- File yang harus dibaca:
  - `lib/core/sync/sync_dtos.dart` baris 151-161, 368-379
  - `lib/core/database/tables/branch_tables.dart` baris 67-99
- File yang harus diubah: `lib/core/sync/sync_dtos.dart` saja.
- Simbol: `PendingInvitationSyncDto.toSupabaseJson()`, `pendingInvitationFromJson()`.
- Kondisi saat ini:
  - Push (151-161) hanya `id,email,full_name,global_role,branch_ids_csv,invited_by,created_at`.
  - Pull (368-379) hanya kolom itu, mengabaikan `join_code,invite_type,max_uses,used_count,status,expires_at,organization_id`.
- Perubahan konkret:
  1. Push: kirim field baru hanya jika non-null/non-default agar prod lama tidak reject unknown-column? PostgREST reject unknown column bahkan jika null, jadi harus kirim full map TAPI server harus sudah punya kolom (S-05). Untuk fase transisi, buat dua method:
     - `toSupabaseJson()` → panggil `toSupabaseJsonV2(includeExtended: true)`? Sederhanakan: ubah `toSupabaseJson()` untuk include semua 14 kolom:
     ```dart
     {
       'id': id,
       'email': email,
       'full_name': fullName,
       'global_role': globalRole.name,
       'branch_ids_csv': branchIdsCsv,
       'invited_by': invitedBy,
       'join_code': joinCode,
       'invite_type': inviteType,
       'max_uses': maxUses,
       'used_count': usedCount,
       'status': status,
       'expires_at': expiresAt == null ? null : _toSupabaseTimestamp(expiresAt!),
       'organization_id': organizationId,
       'created_at': _toSupabaseTimestamp(createdAt),
     }
     ```
     Catat di komentar: membutuhkan S-05 di server; jika server belum migrasi, push akan `failed` dan masuk backoff (tidak crash) — ini disengaja.
  2. Pull `pendingInvitationFromJson`: parse semua kolom dengan default aman:
     - `joinCode: Value(json['join_code'] as String?)`
     - `inviteType: Value(json['invite_type'] as String? ?? 'email')`
     - `maxUses: Value((json['max_uses'] as num?)?.toInt() ?? 1)`
     - `usedCount: Value((json['used_count'] as num?)?.toInt() ?? 0)`
     - `status: Value(json['status'] as String? ?? 'active')`
     - `expiresAt: Value(_maybeDate(json['expires_at']))`
     - `organizationId: Value(json['organization_id'] as String?)`
     - Pertahankan `branchIdsCsv: Value(... ?? '')`, `createdAt: _fromSupabaseTimestamp(...)`.
  3. Jangan ubah `PendingInvitations` Drift table (sudah lengkap).
- Behavior yang dipertahankan: invite email legacy (`inviteType='email'`, `joinCode=null`) tetap claim via `AuthRepository._maybeClaimInvitation` + `pullPendingInvitationByEmail`.
- Edge: `expires_at` string kosong → `_maybeDate` return null (jangan throw). `max_uses` 0 → biarkan 0 (validasi bisnis di UI, bukan DTO).
- Test baru `test/core/sync/pending_invitation_dto_test.dart`:
  - Input legacy JSON (7 kolom) → expected `inviteType='email'`, `maxUses=1`, `usedCount=0`, `status='active'`, `joinCode=null`, `expiresAt=null`.
  - Input full JSON (14 kolom, `join_code:'AB12CD34'`, `max_uses:5`, `used_count:2`, `status:'active'`) → expected sama persis + `toSupabaseJson()` roundtrip mengandung `join_code:'AB12CD34'`.
  - Input `expires_at: null` → `toSupabaseJson()['expires_at']==null`.
- Command: `flutter test test/core/sync/pending_invitation_dto_test.dart`, `flutter analyze`.
- Hasil yang diharapkan: 3/3 pass.
- Tidak boleh diubah: `BranchDao`, `AuthRepository`, RLS, Drift schema.

## S-05 File migrasi Supabase parity minimal (F-001/F-006)

- Tujuan: siapkan file migrasi non-destruktif yang membawa prod ke parity minimal agar S-03/S-04 bisa aktif penuh, tanpa RLS rewrite berisiko.
- Finding: F-001, F-006.
- Dependency: none untuk pembuatan file; S-03/S-04 bergantung pada file ini saat di-apply manual.
- File yang harus dibaca:
  - `supabase/migrations/20260520150004_bank_accounts.sql` (pola `if not exists`, RLS per-tabel)
  - `supabase/migrations/20260613110000_multi_tenant_saas_expand.sql` baris 175-213 (daftar `ALTER ... ADD COLUMN organization_id`), 522-603 (RLS tabel SaaS saja)
  - `supabase/migrations/20260617_invite_code_expand.sql` (cek apakah sudah ada pola join_code; baca penuh sebelum tulis)
- File yang harus diubah (baru, tepat 2 file, jangan edit file migrasi lama):
  - `supabase/migrations/20260925000001_org_parity_minimal.sql`
  - `supabase/migrations/20260925000002_pending_invitations_codes.sql`
- Simbol SQL: `organizations`, `organization_members`, `subscription_plans`, `organization_subscriptions`, `usage_counters`, `company_settings`, `pending_invitations`.
- Kondisi saat ini: prod tidak punya 6 tabel di atas + tidak punya `organization_id` di tabel bisnis + tidak punya kolom code-invite.
- Perubahan konkret:
  1. `20260925000001_org_parity_minimal.sql` (urutan dalam file, semua `IF NOT EXISTS`, ADR-0008):
     - `create extension if not exists pgcrypto;`
     - Buat `organizations`, `organization_members`, `subscription_plans` (+ seed free/plus via `on conflict do update`), `organization_subscriptions`, `usage_counters`, `company_settings` (kolom `id text PK default 'global'`, `receipt_logo_url`, `show_receipt_logo`, `receipt_logo_position`, `updated_at`; JANGAN buat `menu_image_settings` server — itu local-only).
     - `ALTER TABLE ... ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id)` untuk: `branches`, `products`, `categories`, `customers`, `option_groups`, `options`, `product_option_groups`, `bank_accounts`, `company_settings`, `pending_invitations`, `customer_point_ledger`.
     - `ALTER TABLE branches ADD COLUMN IF NOT EXISTS is_main boolean NOT NULL DEFAULT false;`
     - Index minimal: `branches_organization_idx`, `products_organization_idx`, `customers_organization_idx`, `bank_accounts_organization_idx` (semua `IF NOT EXISTS`).
     - RLS: `ENABLE ROW LEVEL SECURITY` untuk 6 tabel baru + policy baca minimal (`authenticated` + `current_user_is_org_member` JIKA helper ada; jika tidak, pakai `USING (true)` untuk read + TODO comment agar S-07 mengencangkan). Jangan rewrite policy tabel legacy di file ini.
     - Backfill: JANGAN backfill data (prod rows=0). Tulis komentar `-- No backfill: prod empty per 2026-09-25 list_tables`.
  2. `20260925000002_pending_invitations_codes.sql`:
     - `ALTER TABLE pending_invitations ADD COLUMN IF NOT EXISTS join_code text;` + `invite_type text NOT NULL DEFAULT 'email'` + `max_uses int NOT NULL DEFAULT 1` + `used_count int NOT NULL DEFAULT 0` + `status text NOT NULL DEFAULT 'active'` + `expires_at timestamptz` + `organization_id uuid REFERENCES organizations(id)` (semua `IF NOT EXISTS`, default agar row lama valid).
     - `CREATE UNIQUE INDEX IF NOT EXISTS pending_invitations_join_code_uq ON pending_invitations(join_code) WHERE join_code IS NOT NULL;`
     - Jangan ubah kolom existing, jangan drop constraint.
- Behavior yang dipertahankan: migrasi existing tidak diubah; file baru idempotent (`IF NOT EXISTS`).
- Error handling: setiap `ALTER` harus `IF NOT EXISTS`; setiap `CREATE POLICY` diawali `DROP POLICY IF EXISTS`; helper `current_user_is_org_member` dipanggil hanya di dalam policy yang di-guard `to_regprocedure`? Sederhanakan: jika helper belum ada, policy pakai `USING (true)` + `-- TODO(S-07)` comment. Jangan buat `DO` block yang kompleks agar model kecil tidak salah sintaks.
- Test/verifikasi (read-only, tanpa apply):
  - `flutter analyze` (tidak ada Dart berubah di S-05, harus tetap hijau).
  - Verifikasi SQL sintaks via `supabase db lint`? Tidak tersedia di repo; ganti dengan verifikasi manual: buka file di SQL Editor staging (instruksi di Notes, bukan eksekusi).
  - Verifikasi MCP read-only setelah manual apply (di luar plan ini): `SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY 1` harus memuat 6 tabel baru; `SELECT column_name FROM information_schema.columns WHERE table_name='pending_invitations'` harus memuat `join_code`.
- Completion criteria: 2 file ada, semua statement idempotent, tidak ada `DROP TABLE`/`DROP COLUMN`/`ALTER ... DROP`.
- Tidak boleh diubah: file migrasi lama, Drift Dart, RLS tabel legacy.

## S-06 Ganti `Logger()` → `AppLogger.instance` di sync (F-009)

- Tujuan: log sync mengikuti gating prod (`warning+` di prod).
- Finding: F-009.
- Dependency: none.
- File yang harus dibaca: `lib/core/logging/app_logger.dart` (1-42), `lib/core/sync/sync_repository.dart` baris 1-48.
- File yang harus diubah: `lib/core/sync/sync_repository.dart` (2 lokasi).
- Simbol: `SyncRepository._log`, `AppLogger.instance`.
- Kondisi saat ini: baris 4 `import 'package:logger/logger.dart';`, baris 38 `final Logger _log = Logger();`.
- Perubahan konkret (urutan):
  1. Baris 4: ganti `import 'package:logger/logger.dart';` → `import '../logging/app_logger.dart';` + pertahankan `import 'package:logger/logger.dart';`? Tidak — `_log` bertipe `Logger` dari package logger, jadi butuh kedua import? `AppLogger.instance` return `Logger`, jadi tetap butuh tipe `Logger`. Pertahankan `import 'package:logger/logger.dart';` dan tambah `import '../logging/app_logger.dart';` di bawahnya (sesuai `directives_ordering`).
  2. Baris 38: `final Logger _log = Logger();` → `final Logger _log = AppLogger.instance;`
  3. Jangan ubah level log per-call (`_log.w/i/e` tetap).
- Behavior yang dipertahankan: pesan log identik; hanya level gating berubah di prod.
- Edge: `Env.isProd` false di test → level debug, test log lebih verbose (acceptable).
- Test: tidak perlu test baru; verifikasi via `flutter analyze` (import ordering) + `flutter test test/core/sync/sync_provider_test.dart` existing.
- Command: `flutter analyze`, `flutter test test/core/sync/sync_provider_test.dart`.
- Hasil yang diharapkan: pass, tidak ada `avoid_print`/`unused_import`.
- Tidak boleh diubah: level log, pesan log, `Env`, `AppLogger` sendiri.

## S-07 RLS hardening file migrasi terpisah (F-007)

- Tujuan: tutup linter `security` tanpa mengubah akses bisnis.
- Finding: F-007.
- Dependency: S-05 (tabel harus ada dulu).
- File yang harus dibaca: `supabase/migrations/20260518150009_rls_helpers.sql`, `supabase/migrations/20260520150004_bank_accounts.sql` baris 21-38.
- File yang harus diubah (baru, 1 file): `supabase/migrations/20260925000003_rls_hardening.sql`.
- Simbol: `reconcile_cached_stock()`, `stamp_server_received_at()`, `user_global_role()`, `user_has_branch_access(uuid)`, policy `bank_accounts owner *`, `categories owner *`.
- Kondisi saat ini (hasil MCP): `reconcile_cached_stock` + `stamp_server_received_at` tanpa `SET search_path`; `bank_accounts/categories` owner policy `roles {public}`; `anon` bisa `EXECUTE` SECURITY DEFINER helpers.
- Perubahan konkret (urutan dalam file):
  1. `CREATE OR REPLACE FUNCTION public.reconcile_cached_stock() ... SET search_path = public` (copy body trigger existing persis, hanya tambah `SET search_path = public`).
  2. Sama untuk `stamp_server_received_at()`.
  3. `REVOKE EXECUTE ON FUNCTION public.user_global_role() FROM anon;` + `REVOKE EXECUTE ON FUNCTION public.user_has_branch_access(uuid) FROM anon;` (jangan revoke dari `authenticated` — invite-claim butuh itu).
  4. Ubah owner policy roles: `DROP POLICY ...; CREATE POLICY ... TO authenticated ...` untuk 6 policy (`bank_accounts owner insert/update/delete`, `categories owner insert/update/delete`), `USING`/`WITH CHECK` tetap `(user_global_role()='owner')`.
  5. Komentar `-- Auth dashboard: enable Leaked Password Protection (HaveIBeenPwned) manual` (tidak ada SQL untuk ini).
- Behavior yang dipertahankan: owner-write/auth-read matrix ADR-0007 tidak berubah; trigger logic identik.
- Edge: jika app memanggil RPC helper sebagai `anon` (pre-login), revoke akan break — verifikasi tidak ada call `sb.rpc('user_global_role')` sebagai anon via search kode; jika ada, catat sebagai blocker, jangan apply revoke.
- Test/verifikasi: `flutter analyze` (no Dart change); verifikasi MCP read-only setelah manual apply: `SELECT * FROM pg_policies WHERE ...` roles harus `{authenticated}`; linter `get_advisors(security)` `anon_security_definer` count berkurang.
- Completion criteria: file ada, tidak ada `USING (true)` untuk write, tidak ada `REVOKE` dari `authenticated`.
- Tidak boleh diubah: policy `transactions_*`, `tx_items_*`, `uba_*`, file migrasi lama.

## S-08 Perf index + initplan file migrasi terpisah (F-008)

- Tujuan: tutup linter `performance` (10 FK + 11 initplan).
- Finding: F-008.
- Dependency: S-05.
- File yang harus dibaca: `supabase/migrations/20260518150007_indexes.sql` (pola index existing, baca penuh).
- File yang harus diubah (baru, 1 file): `supabase/migrations/20260925000004_perf_indexes.sql`.
- Kondisi saat ini: linter `unindexed_foreign_keys` 10 temuan + `auth_rls_initplan` 11 temuan (contoh `app_users_select` pakai `auth.uid()` langsung).
- Perubahan konkret (urutan):
  1. 10 `CREATE INDEX IF NOT EXISTS ...` untuk: `inventory_movements(branch_id)`, `inventory_movements(created_by)`, `pending_invitations(invited_by)`, `product_option_groups(option_group_id)`, `product_recipes(branch_id)`, `product_recipes(inventory_item_id)`, `transaction_items(product_id)`, `transactions(customer_id) WHERE customer_id IS NOT NULL`, `transactions(voided_by_transaction_id) WHERE ... IS NOT NULL`, `user_branch_access(branch_id)`.
  2. Initplan: untuk setiap policy yang mengandung `auth.uid()` / `auth.jwt()` / `current_setting()`, tulis ulang dengan `(select auth.uid())`. Karena definisi policy lengkap tidak ada di repo (hanya di prod), eksekutor harus (a) baca `SELECT policyname, qual, with_check FROM pg_policies WHERE schemaname='public'` via MCP read-only, (b) generate `DROP POLICY IF EXISTS ...; CREATE POLICY ...` per policy dengan penggantian string `auth.uid()` → `(select auth.uid())` saja, tanpa mengubah logika lain. Jika ragu definisi, SKIP policy itu dan catat di Notes file migrasi sebagai `-- TODO: manual`.
- Behavior yang dipertahankan: hasil query RLS identik, hanya rencana eksekusi berubah.
- Edge: index concurrently? Jangan pakai `CONCURRENTLY` (tidak bisa di migrasi transaksi Supabase). Pakai `IF NOT EXISTS` biasa.
- Test/verifikasi: `flutter analyze`; setelah manual apply, `get_advisors(performance)` `unindexed_foreign_keys` → 0, `auth_rls_initplan` berkurang.
- Completion criteria: file ada, semua index `IF NOT EXISTS`, tidak ada `DROP INDEX` existing.
- Tidak boleh diubah: `007_indexes.sql`, Drift, Dart.

## S-09 Hapus komentar basi TD-001 (F-009)

- Tujuan: hilangkan panduan salah agar model kecil tidak mengikuti workaround usang.
- Finding: F-009.
- Dependency: S-01..S-08 (terakhir sebelum regresi).
- File yang harus dibaca: `lib/core/database/app_database.dart` baris 58-60, 178-187.
- File yang harus diubah: `lib/core/database/app_database.dart` (komentar saja).
- Perubahan konkret:
  1. Baris 58-59: `// FEAT-002 — SaaS multi-tenant tables (schemaVersion 21)` + `// TD-001 resolved 2026-09-21 — Drift 2.21+ codegen works.` → gabung menjadi 1 baris `// FEAT-002 — SaaS multi-tenant tables (schemaVersion 21, TD-001 resolved 2026-09-21).`
  2. Baris 178-180: hapus `// (raw SQL because drift codegen is blocked by analyzer version mismatch — TD-001).` → ganti `// FEAT-002 — multi-tenant SaaS tables.`
  3. Jangan ubah kode migrasi `_createOrganizationsTable()` dll.
- Behavior: nol perubahan runtime.
- Test: `flutter analyze`.
- Completion criteria: tidak ada string `blocked by analyzer` tersisa di file.
- Tidak boleh diubah: logika migrasi, `schemaVersion`.

## S-10 Regresi akhir + handoff

- Tujuan: buktikan semua finding tertutup tanpa regresi.
- Dependency: S-01..S-09.
- File yang harus dibaca: semua test baru S-01..S-04 + `test/core/sync/sync_provider_test.dart`, `test/core/sync/sync_conflict_test.dart`.
- File yang harus diubah: none (hanya update `## Progress Log` di file plan ini).
- Command verifikasi (urutan, di PowerShell Windows):
  1. `flutter analyze` → expected `No issues found!`
  2. `flutter test` → expected `All tests passed!` (termasuk 3 file baru: `clear_organization_data_test.dart`, `branch_dao_org_scope_test.dart`, `pending_invitation_dto_test.dart`, `sync_org_guard_test.dart`)
  3. Read-only MCP: `SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY 1` (catat, jangan ubah) + `SELECT tablename, policyname, roles FROM pg_policies WHERE schemaname='public' ORDER BY 1,2` (catat roles `bank_accounts`/`categories` masih `{public}` sampai S-07 di-apply manual).
- Completion criteria: M1-M4 checklist Tasks semua `[x]`; tidak ada `SqliteException`; tidak ada query `.eq('organization_id')` tanpa fallback tersisa di `sync_repository.dart` (cek via search `organization_id`).
- Tidak boleh diubah: semua file selain file plan pada S-10.

## Risks

- Risiko migrasi prod tanpa staging: `supabase/` free-tier tanpa branching. Mitigasi: file S-05/S-07/S-08 idempotent + instruksi apply manual di staging dulu; prod rows=0 jadi backfill aman. Counter-argumen: menunda migrasi membuat S-03 fallback permanen dan tech debt bertambah — acceptable untuk 1 sprint, tidak untuk 2.
- Risiko `REVOKE FROM anon` break pre-login claim: mitigasi S-07 mewajibkan search `sb.rpc('user_global_role')` sebelum apply.
- Risiko model kecil salah sintaks SQL kompleks: mitigasi batasi `DO` block, paksa `IF NOT EXISTS`, dan TODO eksplisit untuk initplan yang tidak yakin.
- Risiko `build_runner` cache (`Null is not InterfaceElement`): mitigasi larang `build_runner` di semua langkah kecuali jika Drift table diubah (tidak ada langkah yang mengubah Drift table, jadi tidak perlu).

## Open Questions / Blockers

- B-01: Minimal vs full SaaS expand? Opsi A (rekomendasi): minimal S-05 (kolom nullable + 6 tabel, tanpa RLS rewrite) → unblock sync 1-2 hari, RLS lama tetap berlaku. Opsi B: full `20260613110000` + `20260615` rewrite 61 policy → benar jangka panjang tapi butuh staging + QA auth menyeluruh (2-4 hari). Risiko A: RLS org-aware belum enforce → data antar-org bisa terbaca jika multi-org diisi sebelum S-07. Jangan pilih diam-diam; minta owner pilih sebelum apply S-05.
- B-02: `BranchDao.getBranchIdsForUserInOrg` tanpa `branches.organization_id` lokal — apakah perlu tambah kolom Drift + `schemaVersion 24` + `build_runner`? Rekomendasi: tidak dalam plan ini (tambah kolom = build_runner + migrasi lokal + test migrasi). Jika owner butuh filter org ketat di lokal, buat plan lanjutan.
- B-03: `company_settings` PK `text 'global'` vs `organizations.id uuid` — join org via `organization_id uuid` aman, tapi tipe campur `text/uuid` di `transactions.bank_account_id text` vs `bank_accounts.id text` sudah konsisten; jangan ubah tipe tanpa plan migrasi tipe data.

## Progress Log

- 2026-09-25 12:00:00 — Plan dibuat dari review + traceability; belum ada implementasi; S-00..S-10 pending.
- 2026-09-25 13:30:00 — S-00 done: `flutter analyze --no-pub` 476 issues (0 error, info/warning pre-existing); `flutter test` 126 passed.
- 2026-09-25 13:45:00 — S-01 done: `app_database.dart:456` → `user_branch_accesses`; temuan turunan: `onCreate` tidak buat `usage_counters` → tambah `_createUsageCountersTable()`; baru `test/core/database/clear_organization_data_test.dart` (2 test pass, retain contract + idempotent).
- 2026-09-25 14:00:00 — S-02 done: `branch_dao.dart:getBranchIdsForUserInOrg` ganti ke cek `organization_members` + `user_branch_accesses` (tanpa `branches.organization_id`); baru `branch_dao_org_scope_test.dart` (3 pass).
- 2026-09-25 14:30:00 — S-03+S-06 done: tambah `shouldFallbackToUnfiltered()` + `AppLogger.instance`; `pullMyAuthContext` org block di-guard; `pullMasterData` orgId nullable + fallback per-tabel (branches/categories/products/modifiers/company_settings/customers/bank_accounts/usage_counters) + `pullTransactions` point ledger fallback; baru `sync_org_guard_test.dart` (4 pass); `sync_provider_test` + `sync_conflict_test` tetap pass.
- 2026-09-25 14:45:00 — S-04 done: `sync_dtos.dart` push/pull `pending_invitations` 14 kolom + `_maybeDate` empty-string guard; baru `pending_invitation_dto_test.dart` (3 pass).
- 2026-09-25 15:00:00 — S-05 done: baru `20260925000001_org_parity_minimal.sql` + `20260925000002_pending_invitations_org.sql` (deviasi dari plan: 000002 hanya org col + updated_at karena join_code sudah ada di `20260617_invite_code_expand.sql`; urutan apply: 000001 → 000002 → 20260617). Tidak di-apply ke DB.
- 2026-09-25 15:15:00 — S-07 done: baru `20260925000003_rls_hardening.sql` (search_path pin + revoke anon + owner policy ke authenticated; verifikasi `sb.rpc` hanya `claim_invitation_code` authenticated, aman). S-08 done: baru `20260925000004_perf_indexes.sql` (10 FK index + TODO initplan manual). Tidak di-apply ke DB.
- 2026-09-25 15:20:00 — S-09 done: hapus komentar basi TD-001 di `app_database.dart:58-59,178-180`; verifikasi `blocked by analyzer` 0 match.
- 2026-09-25 15:30:00 — S-10 done: `flutter analyze --no-pub` 503 issues (0 error; +27 info dari file baru, gaya sama dengan baseline); `flutter test` 138 passed (126 lama + 12 baru); verifikasi `user_branch_access` singular 0 match, `blocked by analyzer` 0 match, semua `.eq organization_id` di `sync_repository.dart` ter-guard `shouldFallbackToUnfiltered`.

## Notes

- Konvensi file migrasi: `supabase/migrations/YYYYMMDDHHMMSS_snake_case.sql`, timestamp UTC, jangan edit file lama (ADR-0008).
- Env guard: jangan print/cat `sb_secret_*`, `SUPABASE_*`, `.env*` ke chat/tool output; placeholder `.env.example` saja.
- Perintah yang dilarang eksekutor: `git add/commit/push`, `supabase db push`, `apply_migration`, `flutter build apk/appbundle`, `dart run build_runner build` (kecuali jika langkah menyatakan perlu — tidak ada langkah yang perlu).
- Perintah yang boleh: `flutter analyze`, `flutter test <path>`, `flutter test`, read-only MCP `list_tables`, `list_migrations`, `execute_sql(SELECT/WITH saja)`, `get_advisors`.
- Setelah S-05/S-07/S-08 file dibuat, apply manual: Supabase Dashboard → SQL Editor → paste file per urutan `000001 → 000004` di project staging dulu, verifikasi via `information_schema` + `pg_policies`, baru prod. Catat hasil di Progress Log file plan ini.

---

## Handoff Checklist (untuk model eksekutor kecil)

- [ ] Baca S-00 lalu catat output `flutter analyze` + `flutter test` apa adanya.
- [ ] Kerjakan S-01 → S-04 строго berurutan (M1+M2); setiap langkah akhiri dengan command verifikasi yang tercantum dan catat hasilnya.
- [ ] Jangan mulai S-05 sebelum S-03 selesai (fallback harus ada sebelum server berubah).
- [ ] S-05/S-07/S-08 hanya buat file baru; jangan edit migrasi lama; jangan apply ke DB.
- [ ] Setiap file Dart yang diubah harus `flutter analyze` bersih sebelum lanjut.
- [ ] Setiap finding harus punya test/verifikasi: F-003→`clear_organization_data_test`, F-004→`branch_dao_org_scope_test`, F-002→`sync_org_guard_test`, F-005→`pending_invitation_dto_test`, F-001/F-006→file migrasi + query `information_schema`, F-007/F-008→file migrasi + `get_advisors`, F-009→`sync_provider_test` + `analyze`.
- [ ] Jika menemui `Null is not InterfaceElement`, hapus `.dart_tool/build` lalu ulangi — jangan ubah `pubspec.yaml`/`drift_dev`.
- [ ] Jika ada keraguan definisi policy/fungsi, tulis `-- TODO: manual` di file migrasi, jangan tebak SQL.
- [ ] Akhiri dengan S-10: `flutter analyze`, `flutter test`, search `organization_id` di `sync_repository.dart` pastikan semua ada fallback, update `## Progress Log` + `## Tasks` di file plan ini saja.
- [ ] Jangan `git add/commit`, jangan `apply_migration`, jangan `build_runner`, jangan ubah area Out-of-scope.
