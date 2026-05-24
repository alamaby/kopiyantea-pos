# KopiyanteaPOS

<p align="center">
  <img src="assets/images/app_logo.png" alt="KopiyanteaPOS logo" width="128">
</p>

[![Release Build](https://github.com/alamaby/kopiyantea-pos/actions/workflows/release.yml/badge.svg)](https://github.com/alamaby/kopiyantea-pos/actions/workflows/release.yml)
[![Supabase Keep-Alive](https://github.com/alamaby/kopiyantea-pos/actions/workflows/supabase-ping.yml/badge.svg)](https://github.com/alamaby/kopiyantea-pos/actions/workflows/supabase-ping.yml)

KopiyanteaPOS is an offline-first Flutter point-of-sale app for an Indonesian coffee shop chain. It is designed for fast cashier workflows, local-first reliability, append-only financial records, event-sourced inventory, and secure synchronization to Supabase.

> Status: active development. See [PROJECT_STATUS.md](PROJECT_STATUS.md) for the implementation tracker.

## Highlights

- Offline-first POS powered by local Drift storage.
- Supabase sync with outbox pattern for reliable background delivery.
- Append-only transaction records and void flow for auditability.
- Event-sourced inventory movement with cached stock reconciliation.
- Multi-branch catalog, inventory, customers, reports, settings, and user management.
- Bluetooth receipt printer integration with ESC/POS formatting.
- Indonesian-first UX with `id_ID` formatting and `en_US` fallback localization.
- Responsive Flutter UI for compact phones and wider tablet layouts.
- Color-blind-safe design tokens with non-color status signals.
- Production hardening foundations: RLS-oriented Supabase schema, cert pinning, env validation, and release automation.

## Tech Stack

| Area | Technology |
|---|---|
| App | Flutter, Dart |
| State management | Riverpod |
| Routing | go_router |
| Local database | Drift, SQLite |
| Backend | Supabase |
| Config | envied |
| Hardware | Bluetooth thermal printer, ESC/POS |
| Localization | Flutter gen-l10n, intl |
| CI/CD | GitHub Actions |

## Repository Structure

```text
lib/
  core/                 Shared config, database, services, sync, theme, widgets
  features/             Feature modules: POS, catalog, inventory, reports, etc.
  l10n/                 Localization source files
supabase/
  migrations/           Forward-only Supabase SQL migrations
  seed.sql              Development seed data
docs/
  adr/                  Architecture Decision Records
  release.md            Release and signing guide
test/                   Unit and widget tests
android/, ios/          Platform projects
```

## Getting Started

### Prerequisites

- Flutter stable SDK, matching the project constraints in [pubspec.yaml](pubspec.yaml).
- Dart SDK bundled with Flutter.
- Android Studio or Xcode for platform builds.
- Supabase project for real sync/auth flows.

### 1. Clone

PowerShell:

```powershell
git clone https://github.com/alamaby/kopiyantea-pos.git
cd kopiyantea-pos
```

Bash:

```bash
git clone https://github.com/alamaby/kopiyantea-pos.git
cd kopiyantea-pos
```

### 2. Configure Environment

Copy the example env file and fill in real values.

PowerShell:

```powershell
Copy-Item .env.example .env
```

Bash:

```bash
cp .env.example .env
```

Required variables:

| Variable | Description |
|---|---|
| `SUPABASE_URL` | Supabase project URL, must use `https://`. |
| `SUPABASE_PUBLISHABLE_KEY` | Supabase publishable key. Legacy anon JWT also works. |
| `APP_ENV` | `development`, `staging`, or `production`. |
| `SUPABASE_CERT_FINGERPRINTS` | Comma-separated SHA-256 cert fingerprints. Required for production. |

Environment values are compiled by `envied` and validated at startup via `Env.validate()`.

### 3. Install Dependencies

PowerShell / Bash:

```powershell
flutter pub get
```

### 4. Generate Code

Run this after changing `.env`, Drift tables, Riverpod annotations, Freezed models, or JSON models.

PowerShell / Bash:

```powershell
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

### 5. Run

PowerShell / Bash:

```powershell
flutter run
```

## Useful Commands

PowerShell:

```powershell
# Analyze
flutter analyze

# Run all tests
flutter test

# Run a specific test file
flutter test test/core/pricing/pricing_test.dart

# Format changed Dart files
dart format lib test

# Android release builds
flutter build apk --split-per-abi --release
flutter build appbundle --release

# iOS release build
flutter build ipa --release
```

Bash:

```bash
# Analyze
flutter analyze

# Run all tests
flutter test

# Run a specific test file
flutter test test/core/pricing/pricing_test.dart

# Format changed Dart files
dart format lib test

# Android release builds
flutter build apk --split-per-abi --release
flutter build appbundle --release

# iOS release build
flutter build ipa --release
```

## Architecture

The app follows a local-first architecture:

1. User actions write to the local Drift database first.
2. Syncable changes are queued in an outbox table.
3. Background sync pushes outbox entries to Supabase.
4. Supabase RLS protects server-side data access.
5. Financial and inventory records are kept audit-friendly through append-only/event-style tables.

Important references:

- [Architecture Decision Records](docs/adr)
- [Release Guide](docs/release.md)
- [Project Status](PROJECT_STATUS.md)
- [Master Build Prompt](MASTER_PROMPT_v5.md)

## Database and Migrations

Supabase schema changes live in [supabase/migrations](supabase/migrations). Migrations are timestamped, forward-only, and should be non-destructive whenever possible.

Local database definitions live under [lib/core/database](lib/core/database). Keep Drift schema changes aligned with Supabase migrations and ADR decisions.

## Design System

The app uses a Teal/Amber design system with bundled Inter fonts and color-blind-safe status semantics.

| Token | Value |
|---|---|
| Primary | Teal-700 `#0F766E` |
| Accent | Orange-600 `#EA580C` |
| Success | Sky-600 `#0284C7` |
| Danger | Red-600 `#DC2626` |
| Font | Inter, bundled in `assets/fonts` |
| Spacing | 4pt scale |
| Radius | 4, 8, 12, 16, 999 |
| Locale | `id_ID` default, `en_US` fallback |

Status UI should never rely on color alone. Pair semantic colors with labels, icons, or numeric signs.

## Release

Android release builds are automated through GitHub Actions. Push a SemVer tag to create signed APK and AAB artifacts:

PowerShell / Bash:

```bash
git tag v1.2.3
git push origin v1.2.3
```

Required GitHub secrets and manual fallback steps are documented in [docs/release.md](docs/release.md).

## License

Proprietary. All rights reserved.

## Author

Created by Alam Aby Bashit.
