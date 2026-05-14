# Phase 1 — Manual Setup Steps

Per global rule, no Flutter/Dart commands were executed automatically. Run these yourself; report back any failures and we adjust before Phase 2.

## 1. Generate platform folders

The repo currently has Dart sources but no `android/`, `ios/`, etc. Run `flutter create` in-place to scaffold them without touching existing files:

```powershell
flutter create . --project-name kopiyantea_pos --org com.alamaby --platforms=android,ios
```

This produces:
- Android `applicationId` = `com.alamaby.kopiyantea_pos`
- iOS `CFBundleIdentifier` = `com.alamaby.kopiyantea_pos`

`flutter create` is idempotent and will NOT overwrite `pubspec.yaml`, `lib/`, `analysis_options.yaml`, or anything we've already written. Verify with `git status` afterward.

## 2. Drop in font assets

Download Inter (rsms.me/inter, OFL license) and copy these four files to `assets/fonts/`:

- `Inter-Regular.ttf`
- `Inter-Medium.ttf`
- `Inter-SemiBold.ttf`
- `Inter-Bold.ttf`

Also copy `OFL.txt` next to them.

## 3. Create `.env`

```powershell
Copy-Item .env.example .env
```

For local dev fill at minimum:

```
SUPABASE_URL=https://placeholder.supabase.co
SUPABASE_ANON_KEY=placeholder-anon-key
APP_ENV=development
SUPABASE_CERT_FINGERPRINTS=
```

These are throwaway values — Supabase init is not yet wired (Phase 6). They exist only so `envied_generator` succeeds.

## 4. Resolve dependencies

```powershell
flutter pub get
```

## 5. Run code generation

This produces:
- `lib/core/config/env.g.dart` (envied)
- `lib/l10n/generated/app_localizations*.dart` (gen-l10n, auto-runs on next `flutter run` too)

```powershell
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

## 6. Verify

```powershell
flutter analyze
flutter run
```

Expected: app launches to the **Beranda** screen with a card of placeholder navigation buttons. Tapping each button opens its placeholder screen with a "Layar ini dibangun pada Phase 2–4" message. Tema light/dark mengikuti system setting.

## What ships in Phase 1

- `pubspec.yaml` with locked deps + Inter font bundle declaration
- `analysis_options.yaml` strict mode
- `lib/core/config/env.dart` — envied-typed, fail-fast `Env.validate()`
- `lib/core/theme/` — `colors.dart`, `typography.dart`, `spacing.dart`, `radius.dart`, `app_theme.dart`
- `lib/core/widgets/` — `AppButton`, `AppTextField`, `AppCard`, `AppBadge`, `AppBottomSheet`, `AppEmptyState`, `AppLoadingIndicator`, `AppNumericKeypad` + barrel
- `lib/l10n/arb/` — `app_id.arb` (primary), `app_en.arb` (fallback) + `l10n.yaml`
- `lib/router.dart` — typed `go_router` placeholder routes
- `lib/main.dart` — `MaterialApp.router` wiring theme + localization + router
- `lib/features/home/home_screen.dart` + `lib/features/placeholders/placeholder_screen.dart`

## Not in Phase 1 (intentional)

- Supabase init, Drift schema, secure storage init — **Phase 2 / Phase 6**
- `flutter_secure_storage`, cert pinning HTTP client — **Phase 6**
- Adaptive shell (BottomNav ↔ NavigationRail) — **Phase 3**
- Real screens — **Phase 4**
- `flutter_riverpod` providers beyond the router — **Phase 2**
