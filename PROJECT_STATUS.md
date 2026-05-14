# PROJECT_STATUS — KopiyanteaPOS

> Workflow: `TODO → IN PROGRESS → DONE DEV → DONE QA`. Forward-only. Regressions create new `[BUG]` entries.

**Last updated:** 2026-05-14

---

## Phase 0 — Foundation Docs — **DONE DEV** (awaiting QA review)

- [x] Write full body for ADR-0001 (UUID v7 for client IDs)
- [x] Write full body for ADR-0002 (Drift for local DB)
- [x] Write full body for ADR-0003 (Event-sourced inventory)
- [x] Write full body for ADR-0004 (Outbox pattern for offline sync)
- [x] Write full body for ADR-0005 (Freezed for all models)
- [x] Write full body for ADR-0006 (Global products with branch junction)
- [x] Write full body for ADR-0007 (RLS policy matrix)
- [x] Write full body for ADR-0008 (Non-destructive migration policy)
- [x] Write full body for ADR-0009 (Two-level discount system)
- [x] Write full body for ADR-0010 (Cert pinning + Play Integrity)
- [x] Write full body for ADR-0011 (Discount from price_override)
- [x] Write full body for ADR-0012 (Tax per branch with inclusive flag)
- [x] Write full body for ADR-0013 (Design tokens + Inter font)
- [x] Initialize `README.md` content (skeleton in place; expanded in Phase 1)
- [x] Verify `.env.example` complete

## Phase 1 — Project Init, Env, i18n, Design Tokens — **DONE QA**

- [x] `flutter create` in repo root (verified: app boots to Beranda on Android emulator)
- [x] `pubspec.yaml` with locked deps + Inter font assets
- [x] `analysis_options.yaml` strict
- [x] `envied` + `Env` class with fail-fast validation (`Env.validate()`)
- [x] `flutter_localizations` + initial ARB (`id_ID` primary, `en_US` fallback) + `l10n.yaml`
- [x] `/lib/core/theme/colors.dart`
- [x] `/lib/core/theme/typography.dart`
- [x] `/lib/core/theme/spacing.dart`
- [x] `/lib/core/theme/radius.dart` (+ `AppTouchTarget`)
- [x] `/lib/core/theme/app_theme.dart` (ThemeData light + dark)
- [x] Component primitives in `/lib/core/widgets/` (AppButton, AppTextField, AppCard, AppBadge, AppBottomSheet, AppEmptyState, AppLoadingIndicator, AppNumericKeypad) + barrel
- [x] Typed `go_router` shell routes (placeholders) in `lib/router.dart`
- [x] `lib/main.dart` wires theme + localization + router
- [x] Inter font assets in `/assets/fonts/` (verified: Inter loaded on device)

## Phase 2 — Data Layer & Hardware Interfaces — **DONE QA**

- [x] Drift schema mirroring Section 7 DDL (13 tables, FK + enum converters)
- [x] DAOs with reactive `watch()` (BranchDao, CatalogDao, InventoryDao, TransactionDao, CustomerDao, OutboxDao)
- [x] Outbox table + OutboxDao (enqueue/markDone/markFailed/watchPendingCount)
- [x] Pricing module: `effectiveUnitPrice` + `computeTotals` (pure functions)
- [x] Pricing unit tests (13 cases, full coverage of ADR-0009/0011/0012)
- [x] Abstract `PrinterService` + `ReceiptPayload` + `PrinterDevice`
- [x] Abstract `ScannerService`
- [x] Abstract `DeviceIntegrityService` + `IntegrityVerdict`
- [x] Fake implementations for dev (FakePrinterService, FakeScannerService, FakeDeviceIntegrityService)
- [x] `service_providers.dart` — Riverpod overrideable service bindings
- [x] `CartNotifier` (addItem, updateQuantity, removeItem, discount, computed totals)
- [x] `SettingsNotifier` (SharedPreferences-backed, async)
- [x] `Auth` provider stub + derived currentUser/branchId/isAuthenticated
- [x] `databaseProvider` override wired in `main.dart`

## Phase 3 — Responsive Navigation — **TODO**

- [ ] `LayoutBuilder` adaptive shell: BottomNavigationBar (mobile) ↔ NavigationRail (tablet)
- [ ] Typed `go_router` shell routes wired
- [ ] Visual regression across 3 screen sizes

## Phase 4 — UI Construction — **TODO**

- [ ] Feature screens built against fake services
- [ ] Decompose monolithic screens per SRP
- [ ] Every async flow via `AsyncValue.when`
- [ ] All strings via ARB; currency/date locale-aware
- [ ] Submit buttons gated by `state.isLoading`
- [ ] Color-blind mode check (deuteranopia + protanopia)

## Phase 5 — Hardware Integration — **TODO**

- [ ] `AndroidManifest.xml` / `Info.plist` permissions
- [ ] Concrete `BluetoothThermalPrinterService` with PDF/share fallback
- [ ] Concrete `MobileScannerService` with permission flow
- [ ] Concrete `PlayIntegrityService` / `AppAttestService`
- [ ] Real-device testing

## Phase 6 — Supabase Sync & Security — **TODO**

- [ ] Migrations in `/supabase/migrations/` (Section 7 DDL split logically)
- [ ] RLS policies (Section 8)
- [ ] Cert pinning in HTTP client
- [ ] Auth flow with offline-cached session + lockout logic
- [ ] `SyncRepository`: pull master + push outbox
- [ ] `workmanager` background sync

## Phase 7 — Optimization & Release — **TODO**

- [ ] Replace prints with `logger` (prod-gated)
- [ ] Global error handlers wired
- [ ] ProGuard/R8 config
- [ ] App signing (debug + release flavors)
- [ ] `flutter build apk --split-per-abi` + `flutter build appbundle`
- [ ] iOS archive + TestFlight (if in scope)
- [ ] `/docs/release.md` documents cert rotation, version bump, store submission

---

## Bug Log

_None._
