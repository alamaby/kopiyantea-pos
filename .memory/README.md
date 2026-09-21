# Project Memory Index — KopiyanteaPOS

**Last updated:** 2026-09-21 08:43:00 (local WIB)
**Format version:** v1
**Active entries:** 1

## Current State

Hardening Backlog Sprint sedang berjalan (M1–M6). M1–M2 selesai: working tree bersih, backup workflow dipulihkan, `.kimchi/` + `backup_supabase/` diarsipkan ke `C:\Works\archives\kopiyantea-pos-2026-09-21`, `.gitignore` diperketat. M3 mulai dikerjakan — inisialisasi `.memory/`.

## Active Decisions

1. Client memakai publishable key (`sb_publishable_...`) — bukan anon key legacy.
2. TD-001 resolved: drift 2.21+ sudah compatible dengan analyzer 6.x tanpa upgrade freezed/riverpod major.
3. Backup dijadwalkan ulang via `supabase-backup.yml` (rclone/GDrive + pg_dump, retensi 30 hari).
4. Org tables (`organizations`, `organization_members`, `subscription_plans`, `organization_subscriptions`) masih raw-SQL — M4 akan migrate ke Drift typed DAO.
5. 5 test gagal pre-existing (sync_provider, formatters, widget_test) — target perbaiki di M5.

## Open Items / Blockers

- M4: regenerate Drift codegen + tulis ulang `OrganizationDao` typed — perlu verifikasi 0 error `flutter analyze`.
- M5: 5 test gagal perlu triase akar masalah sebelum fix.
- QA device matrix (M6): dokumen saja, eksekusi oleh user di device fisik.
- CI diff DDL⇄Drift: follow-up plan terpisah (lihat `plans/2026-09-21-hardening-backlog-sprint.md`).

## Legacy Archive

[`PROJECT_MEMORY.md`](../../PROJECT_MEMORY.md) — kronologis lengkap hingga 2026-07-02. Read-only historical archive.

## Recent Entries

- [2026-09-21 Hardening Sprint Kickoff](2026-09-21/2026-09-21-084300-hardening-sprint-kickoff.md)
