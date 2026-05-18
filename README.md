# KopiyanteaPOS

Production-ready, **offline-first** Flutter mobile POS for an Indonesian coffee shop chain. Built around a local Drift database with an outbox-pattern sync to Supabase, append-only financial records, event-sourced inventory, and a Teal/Amber design system tuned for color-blind safety and one-handed cashier use.

---

## Setup

> Filled in during **Phase 1**. Until then, no Flutter project exists in this repo.

```sh
# placeholder
flutter pub get
```

---

## Environment Variables

All required env vars are declared in [`.env.example`](./.env.example). Copy it to `.env` and fill in real values before running the app.

- `SUPABASE_URL` — Supabase project URL
- `SUPABASE_PUBLISHABLE_KEY` — Supabase publishable key (`sb_publishable_...`); legacy JWT anon key also accepted
- `APP_ENV` — `development` | `staging` | `production`
- `SUPABASE_CERT_FINGERPRINTS` — SHA-256 fingerprints for cert pinning (prod)

Env vars are validated at startup via [`envied`](https://pub.dev/packages/envied); missing/malformed values fail fast.

---

## Build Commands

```sh
# Dev (hot reload)
flutter run

# Codegen (Drift, Freezed, Riverpod, envied)
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs   # continuous

# Tests
flutter test
flutter test test/core/pricing/pricing_test.dart           # specific file

# Lint
flutter analyze

# Android release (see docs/release.md for full procedure)
flutter build apk --split-per-abi --release
flutter build appbundle --release

# iOS release
flutter build ipa --release
```

Full release procedure incl. signing, cert rotation, store submission: [`docs/release.md`](docs/release.md).

---

## Architecture

- Architecture Decision Records (ADRs): [`/docs/adr/`](./docs/adr/)
- Diagrams: [`/docs/architecture/`](./docs/architecture/) (Mermaid, default theme)
- Database schema: see ADR-0006, ADR-0007, ADR-0008 and `/supabase/migrations/`
- Master prompt (source of truth for the build): [`MASTER_PROMPT_v5.md`](./MASTER_PROMPT_v5.md)
- Project status & phase tracking: [`PROJECT_STATUS.md`](./PROJECT_STATUS.md)

---

## Design System — Quick Reference

Full spec in Section 6 of the master prompt and [ADR-0013](./docs/adr/0013-design-tokens-and-inter-font.md).

| Token | Value |
|---|---|
| Primary | Teal-700 `#0F766E` |
| Accent | Orange-600 `#EA580C` |
| Success | **Sky-600** `#0284C7` (not green — color-blind safe) |
| Danger | Red-600 `#DC2626` |
| Surface (light / dark) | `#FFFFFF` / Stone-800 `#292524` |
| Font | **Inter** (bundled asset, 4 weights — not loaded from CDN) |
| Spacing | 4pt base: 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 |
| Radius | sm 4 · md 8 · lg 12 · xl 16 · full 999 |
| Touch targets | 44 min · 48 standard · 56 primary · 64 numeric keypad |
| Locale | `id_ID` default, `en_US` fallback |

**Color-blind safety:** never color-only signals — every status pairs color with an icon. Sky blue for success (distinct from danger red under deuteranopia/protanopia).
