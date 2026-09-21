# Hardening Backlog Sprint — Kickoff

**Task:** M1–M6 hardening backlog sesuai plan `plans/2026-09-21-hardening-backlog-sprint.md`

**Files changed (M1–M2):**
- `.github/workflows/supabase-backup.yml` — restored from git history (commit 9973cb9^)
- `.gitignore` — added `.env.dev`, `.env.stg`, `.env*.local`, `backup_supabase/`, `.kimchi/`, `.claude/`
- Archived: `.kimchi/` → `C:\Works\archives\kopiyantea-pos-2026-09-21\.kimchi`
- Archived: `backup_supabase/` → `C:\Works\archives\kopiyantea-pos-2026-09-21\backup_supabase`
- `supabase/functions/keep-alive/index.ts`, `supabase/config.toml`, migration files — committed
- Docs: README, PHASE_1_SETUP, MASTER_PROMPT_v5, system-context, plans — committed

**Decisions:**
- Backup restore: opsi A (rclone/GDrive + pg_dump, retensi 30 hari) dipilih.
- Arsip eksternal: `.kimchi/` dan `backup_supabase/` dipindah ke `C:\Works\archives\kopiyantea-pos-2026-09-21/`, bukan dihapus permanen.
- Drift typed DAO: bertahap — hanya migrasi 4 tabel org ke `@DriftDatabase`, tanpa CI diff (CI diff jadi follow-up terpisah).
- Secret hygiene audit: tidak ada secret (env, jks, key.properties) yang pernah ter-commit atau ter-push. Aman lanjut.

**Assumptions / Risks:**
- Regenerasi Drift codegen di M4 bisa mengubah `app_database.g.dart` secara signifikan (770KB+). Perlu verifikasi build_runner clean.
- Perubahan String → enum di sync_dtos merembet ke caller — `flutter analyze` sebagai kompas.
- Test pre-existing gagal (5 kasus) — belum diketahui akarnya, perlu triase di M5.

**Blockers:**
- Tidak ada saat ini.

**Verification performed:**
- `git check-ignore` sukses 4/4 path (.env, .env.dev, .env.stg, upload-keystore.jks)
- `git log --all -- .env .env.dev .env.stg upload-keystore.jks key.properties` = kosong (no secrets in history)
- `git status --short` bersih setelah 5 komit atomik

**Commit proposal:**
- `ci(supabase): restore scheduled database and storage backup workflow`
- `feat(supabase): publishable keys and keep-alive edge probe`
- `feat(saas): multi-tenant expand migration and RLS rewrite`
- `docs: refresh readme, setup guide and master prompt for new api keys`
- `chore(repo): remove archived .kimchi directory from working tree`

**Related plans:**
- `plans/2026-09-21-hardening-backlog-sprint.md`
- `plans/2026-09-20-supabase-new-api-keys-migration.md`
