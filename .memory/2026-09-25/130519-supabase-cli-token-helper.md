# Supabase CLI Token Helper

**Date:** 2026-09-25 13:05 (local WIB)
**Plan:** `plans/2026-09-25-supabase-cli-token-helper-plan.md`
**Scope:** helper script only — no real `db push`/`deploy`, no schema/CI change.

## Task / Problem

Agent butuh `supabase db push` dan `functions deploy` tanpa `supabase login` interaktif. Port helper dari sibling `bagistruk`/`bikinstiker` ke `kopiyantea-pos` (fungsi edge: `keep-alive`).

## Key files changed

- **Baru:** `scripts/supabase-with-token.ps1` (164 baris — port 1:1, 2 adaptasi: contoh usage `keep-alive`, komentar SECURITY ke `lib/core/config/env.dart:18` envied bake bukan bundle pubspec).
- **Edit:** `.env.example` (+7 baris placeholder `SUPABASE_ACCESS_TOKEN=sbp_...placeholder...`).
- **Edit:** `README.md` (+9 baris doc CLI di seksi Database/Migrations).
- **Plan:** `plans/2026-09-25-supabase-cli-token-helper-plan.md` (4/4 tasks checked + progress log).

## Decisions

- Doc di `README.md`, bukan `AGENTS.md`/`CLAUDE.md` baru — repo ini tidak punya keduanya.
- Komentar security adaptasi ke envied (`@Envied(path: '.env')` membake ke binary), bukan copy `pubspec.yaml membundle .env` dari sibling.
- Tidak tambah `--no-verify-jwt` eksplisit: `supabase/config.toml` sudah `verify_jwt = false` untuk `keep-alive`.

## Assumptions / risks

- PowerShell 7+ / `pwsh` only (sama seperti sibling); bash user tetap manual export.
- Token plaintext di `.env.local` — proteksi hanya gitignore + never-print. Rotasi via Dashboard → Access Tokens jika bocor.
- Selalu panggil dari repo root (CLI resolve `supabase/functions/<name>` relatif workdir).
- No real push/deploy dijalankan — kredensial `.env.local` bahkan tidak ada di repo ini.

## Blockers / unresolved

- None. Follow-up opsional: operator buat `.env.local` berisi token asli lalu `--DryRun` ulang di workstation sendiri.

## Verification

- Parser: 0 errors. `Test-Path scripts/...` → True. `supabase` CLI ada.
- DryRun temp fake env (file di TEMP, dihapus setelahnya): exit 0, `DRY-RUN: supabase functions deploy keep-alive` + `token loaded (39 chars, redacted)`, LEAK False.
- Varian `export`/quoted/comment/key-lain: exit 0, LEAK False.
- Missing-file: exit 1, pesan tanpa secret.
- `Compare-Object` vs bagistruk: hanya 8 baris beda (4 usage + 1 security, masing-masing sisi).
- `git status --short`: hanya `scripts/`, `.env.example`, `README.md`, plan — no `.env.local`, no temp.

## Commit proposal

`feat(scripts): add supabase-with-token.ps1 CLI helper`

## Related

- Plan: `plans/2026-09-25-supabase-cli-token-helper-plan.md`
- Sibling ref: `../bagistruk/scripts/supabase-with-token.ps1`, `../bikinstiker/AGENTS.md` §8
