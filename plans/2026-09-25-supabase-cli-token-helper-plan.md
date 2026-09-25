# Supabase CLI Token Helper — Implementation Plan

Created: 2026-09-25 12:00:00

## Objective

Sediakan `scripts/supabase-with-token.ps1` di `kopiyantea-pos` — port 1:1 dari sibling `bagistruk`/`bikinstiker` — agar `supabase db push` dan `functions deploy keep-alive` bisa dijalankan tanpa `supabase login` interaktif dan tanpa export manual `SUPABASE_ACCESS_TOKEN`, dengan token dibaca dari `.env.local` (gitignored) dan tidak pernah tercetak ke log.

## Scope

In-scope:

- `scripts/supabase-with-token.ps1` baru (PowerShell 7+, repo jalan di `win32` + `pwsh`).
- Placeholder `SUPABASE_ACCESS_TOKEN` di `.env.example`.
- Dokumentasi singkat di `README.md` seksi Database/Migrations.
- Verifikasi aman tanpa menyentuh remote (DryRun + missing-file + parser check).

Out-of-scope:

- Varian bash `.sh` (sibling juga hanya `.ps1`).
- Eksekusi `db push` / `functions deploy` asli ke Supabase prod.
- Rotasi token, `supabase link`, perubahan CI (`supabase-ping*.yml`), perubahan `supabase/config.toml`.
- Perubahan Drift schema / `build_runner` / RLS.

## Milestones

1. Script helper ter-port dan teradaptasi ke konvensi kopiyantea-pos.
2. `.env.example` + `README.md` terdokumentasi.
3. Verifikasi lolos tanpa kebocoran secret.

## Tasks

- [x] Task 1 — Buat `scripts/supabase-with-token.ps1` (port dari sibling, contoh usage ke `keep-alive`)
- [x] Task 2 — Tambah placeholder `SUPABASE_ACCESS_TOKEN` di `.env.example`
- [x] Task 3 — Dokumentasikan cara pakai di `README.md`
- [x] Task 4 — Verifikasi DryRun + missing-file + git status bersih

### Task 1 detail — `scripts/supabase-with-token.ps1`

Target file: `scripts/supabase-with-token.ps1`. Folder `scripts/` belum ada — buat folder dulu.

Sumber port: `bagistruk/scripts/supabase-with-token.ps1:1-164` (= `bikinstiker/scripts/supabase-with-token.ps1:1-164`). Copy logika 1:1, ubah hanya 2 hal:

1. Contoh usage header (baris 3-6) ganti ke fungsi repo ini:
   ```powershell
   #   & "scripts/supabase-with-token.ps1" db push
   #   & "scripts/supabase-with-token.ps1" functions deploy keep-alive
   #   & "scripts/supabase-with-token.ps1" -DryRun functions deploy keep-alive
   #   & "scripts/supabase-with-token.ps1" --DryRun functions deploy keep-alive
   ```
2. Komentar SECURITY (baris 8) adaptasi ke mekanisme env repo ini. Sibling menulis `pubspec.yaml:62 membundle .env ke APK/AAB`. Kopiyantea-pos tidak membundle via `pubspec.yaml:120-121` (hanya `assets/images/`), tapi membake via `lib/core/config/env.dart:18` (`@Envied(path: '.env')`). Tulis:
   ```
   #   - Token ONLY from `.env.local`. NEVER put it in `.env` (lib/core/config/env.dart:18 bakes `.env` into the binary via envied).
   ```
3. Pesan error contoh (baris 144) tetap: `Contoh: & scripts/supabase-with-token.ps1 db push`.

Spesifikasi perilaku (jangan disederhanakan):

1. `#Requires -Version 7.0`, `param([string[]]$SupabaseArgs, [string]$EnvFile = ".env.local", [switch]$DryRun)` dengan `$SupabaseArgs` di position 0.
2. Normalisasi `--X` → `-X` agar dua sintaks dash jalan.
3. Ekstrak `--EnvFile`/`-EnvFile` dan `--DryRun`/`-DryRun` dari sisa args.
4. Resolve repo root via `Split-Path -Parent $PSScriptRoot`, cek `Test-Path` env file → error tanpa isi secret jika hilang.
5. Parser `.env.local` minimal: skip kosong/`#`, strip prefix `export `, split `=` pertama, trim key/value, hanya ambil `SUPABASE_ACCESS_TOKEN`, strip outer quote ganda/tunggal.
6. Validasi non-empty → error `SUPABASE_ACCESS_TOKEN kosong/hilang... Jangan commit file ini.` Warning non-fatal jika tidak prefix `sbp_`.
7. Cek `Get-Command supabase`, error dengan link docs jika hilang.
8. Jika args kosong → error contoh usage.
9. DryRun: print `DRY-RUN: supabase <args>` + `token loaded (N chars, redacted)`, exit 0, tidak panggil CLI.
10. Eksekusi: `$env:SUPABASE_ACCESS_TOKEN = $token` → `& supabase @SupabaseArgs` → `exit $LASTEXITCODE` → `finally { Remove-Item Env:\SUPABASE_ACCESS_TOKEN }`. Tidak ada `Write-Output` nilai token di manapun.

### Task 2 detail — `.env.example`

File: `.env.example` (saat ini 35 baris, tanpa blok token). Tambah di akhir (bahasa Inggris mengikuti konvensi file ini yang seluruhnya English):

```env
# --- Supabase CLI only: Personal Access Token (`db push` / `functions deploy`) ---
# Real value ONLY in `.env.local`, NEVER in `.env` (lib/core/config/env.dart:18
# bakes `.env` into the binary via envied). Consumed via helper
# `scripts/supabase-with-token.ps1`, which reads the token from `.env.local`
# without ever printing it. Get one at Supabase Dashboard → Account → Access Tokens (prefix sbp_).
SUPABASE_ACCESS_TOKEN=sbp_...placeholder...
```

Placeholder `sbp_...placeholder...` sengaja fake tapi berprefix `sbp_` agar lolos format warning dan jelas bukan token asli.

Tidak perlu ubah `.gitignore`: `.env`, `.env.local`, `.env.*.local`, `supabase/.temp/` sudah diignore (`.gitignore:22-24,35-37`).

### Task 3 detail — `README.md`

Lokasi: seksi `## Database and Migrations` (`README.md:207-211`). Tambah blok setelah paragraf migrasi (fenced block agar highlight PowerShell):

````md
CLI via access token (tanpa `supabase login`):

```powershell
& "scripts/supabase-with-token.ps1" db push
& "scripts/supabase-with-token.ps1" functions deploy keep-alive
```

Token `SUPABASE_ACCESS_TOKEN` (prefix `sbp_`) HANYA dari `.env.local`. Verifikasi aman: `& "scripts/supabase-with-token.ps1" --DryRun functions deploy keep-alive`.
````

Tidak buat `AGENTS.md`/`CLAUDE.md` baru — repo ini tidak punya keduanya (sibling mendokumentasikan di `bikinstiker/AGENTS.md:207-215` / `bagistruk/CLAUDE.md:29-31`); cukup README agar minimal.

### Task 4 detail — Verifikasi

Jalankan dari repo root (`C:\Works\github.com\alamaby\kopiyantea-pos`), tanpa mencetak nilai token:

1. `Test-Path -LiteralPath "scripts/supabase-with-token.ps1"` → True.
2. `& "scripts/supabase-with-token.ps1" --DryRun functions deploy keep-alive` → exit 0, output berisi `DRY-RUN: supabase functions deploy keep-alive` + `redacted`, TIDAK ada `sbp_` asli.
3. Uji file hilang: `& "scripts/supabase-with-token.ps1" -EnvFile ".env.does-not-exist" --DryRun db push` → exit 1, pesan error tanpa isi secret.
4. `git status --short` hanya menunjukkan `scripts/supabase-with-token.ps1`, `.env.example`, `README.md`, + plan file — tidak ada `.env.local`, tidak ada file temp.
5. Opsional: `pwsh -NoProfile -Command { $ErrorActionPreference='Stop'; . ./scripts/supabase-with-token.ps1 --DryRun db push }` sebagai smoke parse check.

Dilarang saat verifikasi: `Get-Content .env.local`, `cat .env.local`, `echo $env:SUPABASE_ACCESS_TOKEN`, `grep -r sbp_|sb_secret`, atau menempel nilai token ke chat/log.

## Risks

- PowerShell 7 only: user bash/Linux/CI tetap perlu `export SUPABASE_ACCESS_TOKEN` manual — sibling juga begitu, jadi diterima sebagai limitasi.
- Token plaintext di `.env.local`: proteksi hanya gitignore + tidak-print; jika workstation dikompromikan, token bocor. Mitigasi: instruksikan rotasi via Dashboard → Access Tokens.
- Salah workdir: CLI resolve `supabase/functions/<name>` relatif workdir — selalu panggil dari repo root, bukan dari `supabase/` (pelajaran `bagistruk/.memory/2026-09-22/235434-supabase-publishable-secret-key-migration.md:17`).
- `keep-alive` punya `verify_jwt = false` (`supabase/config.toml:3-4`): `functions deploy keep-alive` menghormati config, tidak perlu `--no-verify-jwt` eksplisit kecuali ingin override. Counter-argument: menambah flag eksplisit justru berisiko divergen dari config — jadi jangan tambah flag.
- Env Guard: jangan pernah `cat` file `.env*` atau print `sbp_*`/`sb_publishable_*`/`sb_secret_*` ke chat, log, komentar kode, atau markdown.

## Progress Log

- 2026-09-25 12:00:00 — Plan dibuat dari hasil investigasi sibling (`bagistruk/scripts/supabase-with-token.ps1`, `bikinstiker/scripts/supabase-with-token.ps1`, `bikinstiker/AGENTS.md:207-215`); belum ada implementasi.
- 2026-09-25 13:05:00 — Implementasi SELESAI (4/4 tasks). Script `scripts/supabase-with-token.ps1` jadi (164 baris, port 1:1 — `Compare-Object` vs bagistruk hanya tunjukkan 2 adaptasi: usage `keep-alive` + komentar security envied). `.env.example` +7 baris placeholder. `README.md` +9 baris doc CLI. Verifikasi: parse errors 0, DryRun exit 0 (`token loaded (39 chars, redacted)`, LEAK False), varian `export`/quoted/comment/key-lain lolos, missing-file exit 1 tanpa leak, temp fake env terhapus. `git status` hanya file baru/terencana — tidak ada `.env.local`. Tidak ada `db push`/`deploy` asli (sesuai scope). Memory entry: `.memory/2026-09-25/130519-supabase-cli-token-helper.md`.
- 2026-09-25 13:20:00 — REVIEW selesai. Temuan in-scope: F1 (wording `.env.example` EN vs plan ID — plan diselaraskan ke implementasi, konvensi file English), F2 (README fenced block vs plan indented — plan diselaraskan, nested fence diperbaiki pakai 4-backtick). Temuan lain: secret-grep bersih, `git diff --check` bersih, edge cases (args-consumed/no-args/empty/whitespace/`=`-in-value) semua exit code + pesan benar tanpa leak, `flutter analyze` 502 info-level baseline (nol file Dart tersentuh). Out-of-scope tidak disentuh: TD-001/TD-002, QA device matrix, secret rotation.

## Notes

- Referensi utama: `bagistruk/scripts/supabase-with-token.ps1:1-164`, `bikinstiker/scripts/supabase-with-token.ps1:1-164`, `bikinstiker/plans/2026-09-19-supabase-token-helper-plan.md:7-55`, `bagistruk/plans/2026-09-21-supabase-cli-token-helper-plan.md:7-47`.
- Perbedaan adaptasi kopiyantea-pos didokumentasikan di Task 1 (envied bake, bukan flutter_dotenv bundle) dan Task 3 (README, bukan AGENTS.md/CLAUDE.md).
- Standar arsitektur: pekerjaan ini routine bugfix/helper skala satu file; TOGAF/ODA tidak diberlakukan penuh secara proporsional (sesuai AGENTS.md §3). Tidak ada perubahan skema live DB — jika `db push` di masa depan butuh migrasi, ikuti strategi forward-only non-destruktif yang sudah ada di `supabase/migrations/`.
