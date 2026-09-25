# Agent Instructions — KopiyanteaPOS

## Rule Precedence

When rules conflict, apply this order (highest priority first):

1. An explicit, one-off instruction from the user in the current conversation.
2. Project-specific guidance in `.memory/README.md` (active memory). `PROJECT_MEMORY.md` is a read-only historical archive.
3. The standing rules in this document.

If a conflict is non-obvious or high-stakes, flag it to the user instead of silently picking one side.

## 1. Supabase CLI Helper

Untuk `supabase db push` / `supabase functions deploy <name>` SELALU pakai wrapper (tanpa `supabase login` interaktif):

```powershell
& "scripts/supabase-with-token.ps1" db push
& "scripts/supabase-with-token.ps1" functions deploy keep-alive
```

- Token `SUPABASE_ACCESS_TOKEN` (prefix `sbp_`) HANYA dari `.env.local`. Jangan pernah taruh di `.env` (`lib/core/config/env.dart:18` membake `.env` ke binary via envied).
- Dilarang: `Get-Content .env.local`, `cat .env.local`, `echo $env:SUPABASE_ACCESS_TOKEN`, `grep -r sbp_|sb_secret`, atau mencetak token ke chat/log. Log hanya boleh `token loaded (N chars, redacted)`.
- Verifikasi aman: `& "scripts/supabase-with-token.ps1" --DryRun functions deploy keep-alive`.
- Selalu panggil dari repo root (CLI resolve `supabase/functions/<name>` relatif terhadap workdir).
- `.env*` sudah gitignored; `supabase/.temp/` juga ignored. Placeholder token (`sbp_...placeholder...`) ada di `.env.example`.

## 2. Flutter Gates

Sebelum menganggap pekerjaan Dart selesai, verifikasi dengan:

```powershell
flutter pub get
flutter analyze
flutter test
```

Aturan version di `pubspec.yaml`: fitur baru → minor +1, patch reset 0, build +1; bugfix → patch +1, build +1.

## 3. Project Pointers

- Setup + env: [README.md](README.md), [docs/supabase-keep-alive.md](docs/supabase-keep-alive.md).
- Status implementasi: [PROJECT_STATUS.md](PROJECT_STATUS.md).
- Memori aktif: [.memory/README.md](.memory/README.md).
