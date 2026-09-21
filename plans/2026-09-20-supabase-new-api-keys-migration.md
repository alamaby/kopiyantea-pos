# Supabase New API Keys Migration (Publishable + Secret)

Created: 2026-09-20 20:03:00

## Objective

Migrasi dari legacy JWT `anon` / `service_role` ke `sb_publishable_…` / `sb_secret_…` sebelum deprecasi akhir 2026, di project production dan development. Client (Flutter) dan CI sudah memakai publishable key; sisa legacy hanya di Edge Function `keep-alive` dan beberapa docs/komentar.

## Scope

- Update `supabase/functions/keep-alive/index.ts` membaca `SUPABASE_PUBLISHABLE_KEYS` (JSON) dengan fallback aman.
- Bersihkan referensi `SUPABASE_ANON_KEY` di `MASTER_PROMPT_v5.md`, `docs/PHASE_1_SETUP.md`.
- Hapus klaim kompatibilitas legacy (`Legacy anon JWT also works`) di `env.dart`, `README.md`, workflow ping.
- Verifikasi: `build_runner`, `gen-l10n`, `analyze`, `test`, curl `apikey:` header, dispatch workflow ping.
- Deactivate legacy keys di Dashboard dev → prod (user-side, setelah hijau).

Out of scope: migrasi JWT signing keys (sistem terpisah); penambahan pemakaian `sb_secret_` baru (tidak dibutuhkan — tidak ada backend yang butuh bypass RLS); Database Webhooks/`pg_net` (tidak ada di repo, dikonfirmasi user tidak ada).

## Milestones

1. Code + docs bersih dari legacy key names.
2. Verifikasi lokal hijau.
3. User: buat `default` keys di Dashboard, sinkron GitHub/Edge secrets, deploy function, verifikasi curl + workflow.
4. User: deactivate legacy dev → observasi → prod.

## Tasks

- [x] Inventory legacy: `SUPABASE_ANON_KEY` hanya di `keep-alive/index.ts`, `MASTER_PROMPT_v5.md`, `docs/PHASE_1_SETUP.md`; `service_role`/`sb_secret` hanya komentar `no service_role needed` (aman).
- [x] Edge Function `keep-alive` → `SUPABASE_PUBLISHABLE_KEYS` JSON + fallback, header `apikey` only, `verify_jwt = false` dipertahankan.
- [x] Docs/komentar: `MASTER_PROMPT_v5.md`, `PHASE_1_SETUP.md`, `env.dart`, `README.md`, `.env.example`, workflow ping headers, `docs/supabase-keep-alive.md` deployment note.
- [x] Verifikasi: `flutter analyze` (0 error; 459 info/warning pre-existing), `flutter test` (100 passed, 5 gagal pre-existing — terbukti sama di clean tree via `git stash`).
- [ ] User-side: buat keys, update secrets, deploy function ke prod+dev, curl manual, dispatch workflow, deactivate legacy.

## Risks

- Secret key bocor = `BYPASSRLS` penuh. Mitigasi: `sb_secret_` tidak pernah masuk `lib/`, `.env`, workflow client, atau repo.
- Header salah (`Authorization: Bearer` untuk new keys) → `Invalid JWT`/401. Mitigasi: hanya header `apikey`.
- Env baru format JSON keyed-by-name; lupa `JSON.parse` → function 500. Mitigasi: helper parse + fallback + error message jelas.
- Deactivate terlalu cepat → client terlewat mati. Mitigasi: dev dulu, observasi, baru prod (reversible via re-activate).

## Progress Log

- 2026-09-20 20:03:00 — Plan dibuat; inventory selesai. Client sudah pakai publishable key (`env.dart:25` → `main.dart:75`); tidak ada `service_role`/`sb_secret` di code.
- 2026-09-20 20:03:00 — Mulai eksekusi code + docs.
- 2026-09-20 — Code selesai: `keep-alive/index.ts` resolve `SUPABASE_PUBLISHABLE_KEYS` JSON → fallback singular → fallback legacy `SUPABASE_ANON_KEY` (fallback dihapus setelah legacy OFF); 7 file docs/komentar dibersihkan. `flutter analyze`: 0 error. `flutter test`: 5 gagal pre-existing (sync_provider timing, formatters `14.30` vs `14:30` intl, widget `Kasir` finder) — dikonfirmasi identik di clean tree. `build_runner`/`gen-l10n` tidak dijalankan: tidak ada input codegen/ARB yang berubah (hanya komentar).
- 2026-09-20 — Menunggu user-side: Dashboard keys → secrets → deploy → curl → workflow → deactivate legacy dev → prod.

## Notes

- Supabase mapping: `anon` → publishable (publik, RLS), `service_role` → secret (backend only, `BYPASSRLS`). Keduanya hidup berdampingan sampai legacy di-deactivate manual.
- `verify_jwt = false` pada `keep-alive` sudah benar untuk new keys; passing check bukan autentikasi caller.
- Referensi: Supabase docs `Migrating to publishable and secret API keys`, `API keys`.
