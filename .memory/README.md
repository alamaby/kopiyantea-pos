# Project Memory Index — KopiyanteaPOS

**Last updated:** 2026-09-21 13:07:00 (local WIB)
**Format version:** v1
**Active entries:** 4

## Current State

Hardening Backlog Sprint **SELESAI** (M1–M6). Semua milestone tereksekusi: working tree bersih, backup workflow dipulihkan, `.kimchi/` + `backup_supabase/` diarsipkan, `.gitignore` diperketat, org tables terdaftar di `@DriftDatabase` + DAO typed, 126 test hijau (0 gagal), RLS smoke checklist siap, QA device matrix dokumen siap. TD-001 belum benar-benar resolved (build_runner perlu clear cache), tapi workaround berfungsi.

## Active Decisions

1. Client memakai publishable key (`sb_publishable_...`) — bukan anon key legacy.
2. Org tables (`organizations`, `organization_members`, `subscription_plans`, `organization_subscriptions`) sekarang Drift typed + terdaftar di `@DriftDatabase`. DAO menggunakan typed queries.
3. Backup dijadwalkan ulang via `supabase-backup.yml` (rclone/GDrive + pg_dump, retensi 30 hari).
4. Arsip `.kimchi/` + `backup_supabase/` di `C:\Works\archives\kopiyantea-pos-2026-09-21/`.
5. CI diff DDL⇄Drift: follow-up plan terpisah (belum dieksekusi).

## Open Items / Blockers

- **TD-002 (HIGH):** `clearOrganizationData()` di `lib/core/database/app_database.dart:456` referensi tabel salah (`user_branch_access` seharusnya `user_branch_accesses`). Crash saat dipanggil. Fix: satu kata di baris 456.
- **TD-001 workaround (HIGH):** Build_runner build crash dengan `Null is not InterfaceElement` jika cache `.dart_tool/build` tidak dibersihkan. Setiap regen butuh `Remove-Item -Recurse .dart_tool/build` dulu. True fix = freezed 3.x + riverpod 3.x upgrade.
- QA device matrix (M6): dokumen siap, eksekusi oleh user di device fisik — status PENDING EKSEKUSI.
- Secret rotation: `.env` lokal ter-commit secara tidak sengaja (perlu di-blacklist dari git tracking jika pernah ter-push).

## Legacy Archive

[`PROJECT_MEMORY.md`](../../PROJECT_MEMORY.md) — kronologis lengkap hingga 2026-07-02. Read-only historical archive.

## Recent Entries

- [2026-09-21 M6 QA Matrix Doc](2026-09-21/130710-m6-qa-matrix-doc.md)
- [2026-09-21 M5 Test Hijau RLS Smoke Doc](2026-09-21/130705-m5-test-hijau-rls-smoke-doc.md)
- [2026-09-21 M4 Org Tables Drift Typed](2026-09-21/130700-m4-org-tables-drift-typed.md)
- [2026-09-21 Hardening Sprint M3–M6](2026-09-21/2026-09-21-084300-hardening-sprint-kickoff.md)
