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

## Phase 3 — Responsive Navigation — **DONE QA**

- [x] `LayoutBuilder` adaptive shell: BottomNavigationBar (< 600dp) ↔ NavigationRail (≥ 600dp) ↔ Extended Rail (≥ 840dp)
- [x] Typed `go_router` shell routes wired via `StatefulShellRoute.indexedStack` (state-preserving)
- [x] `MoreScreen` (Lainnya) hub for secondary destinations
- [x] `AppBreakpoint` constants (tablet 600, railExtended 840)
- [x] ARB updated with `navMore`
- [x] Visual regression across 3 screen sizes (verified: compact BottomNav + expanded Extended Rail; medium tier shares codepath)

## Phase 4 — UI Construction — **IN PROGRESS** (batch 4.1 DONE DEV)

### 4.1 — Seed data + Settings — **DONE QA** (BUG-001 deferred to 4.5)
- [x] `SeedService` populates 2 branches, 3 users, 8 products, branch_products with override+discount, 5 inventory items, recipes, 2 customers
- [x] Idempotent: skips when `branches` is non-empty
- [x] Auto-picks default branch on first run (writes to SharedPreferences)
- [x] `dao_providers.dart` exposes all DAOs via Riverpod
- [x] `allBranchesProvider` (reactive Stream) + `selectedBranchProvider` (Future)
- [x] `SettingsScreen`: branch picker (radio), theme (SegmentedButton system/light/dark), print toggle, about
- [x] `main.dart` reactive `themeMode` from settings (live theme switching)
- [x] Routed at `/more/settings` (replaces placeholder)

### 4.2 — POS / Kasir flow — **DONE QA** (FEAT-001 deferred to Phase 4.6/8)
- [x] `formatRupiah` + date formatters (intl, id_ID locale)
- [x] `cart_state.dart` moved to features/pos, uses Drift Row types
- [x] `CartNotifier` refactored (add/incr/decr/notes/discount/clear + computed totals)
- [x] `menu_provider.dart` → reactive `Stream<List<BranchProductWithProductRow>>`
- [x] `CheckoutUseCase`: atomic write of Transaction + items + inventory movements + outbox (one db.transaction)
- [x] UUID v7 idempotency key, recipe-driven inventory deduction, immutable tax snapshot
- [x] `PosScreen` responsive (mobile floating cart pill, tablet side-by-side)
- [x] `MenuGrid` with discount badge, price strikethrough, haptic feedback
- [x] `CartPanel` with qty controls, manual discount editor, live totals
- [x] `CheckoutSheet` with payment method picker, quick amounts, change calc, error states
- [x] `ReceiptSummarySheet` with derived discount + payment summary
- [x] Wired `/pos` route to real `PosScreen`
- [x] `main.dart` initializes intl date symbols for id_ID
### 4.3 — Catalog (Menu) management — **TODO**
### 4.4 — Inventory + Transactions history — **DONE QA**
- [x] Local `cached_stock` reconciliation in CheckoutUseCase — client-side delta application in the same db.transaction. Converges with the Supabase trigger at sync time (Phase 6).
- [x] `labels.dart` — paymentMethod/movementType/stockUnit/transactionStatus Indonesian mappers + `formatStock`
- [x] `InventoryDao.watchItemById` + `watchMovementsForItem` (reaktif)
- [x] Transactions: `branchTransactionsProvider` (Stream) + `transactionDetailProvider` (Future)
- [x] `TransactionListScreen` dengan date grouping (Hari ini / Kemarin / tanggal absolute)
- [x] `TransactionDetailScreen` dengan Header/Items/Totals/Payment cards + status badge + notes per item
- [x] Inventory: `branchInventoryProvider`, `inventoryItemProvider`, `inventoryMovementsProvider` (semua reaktif)
- [x] `InventoryListScreen` dengan stock status badge (Cukup/Menipis/Habis — semua color-blind safe dengan icon)
- [x] `InventoryDetailScreen` dengan summary + reactive movement history + per-type icons (+/− tone)
- [x] Router: `/transactions/:id`, `/inventory/:id` di luar shell (full-screen detail)
### 4.5 — Customers + Reports + Color-blind QA + BUG-001 — **IN PROGRESS**

#### 4.5a — Dark mode fix (BUG-001) — **DONE QA**
- [x] `AppPalette` + `BuildContext.colors` extension in `colors.dart`
- [x] 8 widget primitives refactored to context-aware colors
- [x] AppBadge dark-mode tone variants
- [x] 11 feature screens swept (static `AppColors.surface/border/textPrimary/etc.` → `context.colors.*`)
- [x] No const-constructor regressions

#### 4.5b — Customers — **DONE QA**
- [x] `CustomerDao` extras: `getById`, `watchById`, `updateById`
- [x] `customer_providers.dart` — `allCustomersProvider` (Stream) + `customerByIdProvider` (Stream)
- [x] `CustomerListScreen` — reactive list + search (name/phone) + FAB tambah + avatar initial + loyalty points badge
- [x] `CustomerFormScreen` — add/edit form, validasi nama wajib + email regex + phone uniqueness, partial-update via `updateById` (preserves createdAt + loyaltyPoints)
- [x] `CustomerPickerSheet` — bottom sheet dengan search, "Tanpa pelanggan" tile, "+" affordance ke form, picks return via `CustomerPick` wrapper
- [x] `CartPanel` integrasi: `_CustomerSection` di bawah header, tap → picker, clear button saat dipilih
- [x] `TransactionDetailScreen` — `_CustomerCard` muncul saat `tx.customerId != null` dengan avatar + phone + loyalty badge
- [x] Router: `/more/customers`, `/more/customers/new`, `/more/customers/:id`
#### 4.5c — Reports — **TODO**
#### 4.5d — Color-blind audit final pass — **TODO**

**Phase 4 acceptance criteria (all batches):**
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

## Backlog (deferred features)

### [FEAT-001] Product Modifier / Option System
- **Requested:** Phase 4.2 QA (2026-05-15)
- **Use case:** Customer minta "Latte less sugar, extra shot, less ice" — POS perlu cara terstruktur untuk record customization.
- **MVP workaround:** Free-text "Catatan" field per cart item (sudah diimplementasi di 4.2). Cashier ketik manual, dicetak di struk dan tampil ke barista.
- **Full solution requires:**
  - DB: `option_groups` (Sugar Level / Ice Level / Shot), `options` (Normal/Less/None, +Rp 0), `product_option_groups` (mapping), `transaction_item_options` (selected snapshot)
  - UI: option picker bottom sheet saat tap produk, multi-select vs single-select, required vs optional
  - Pricing: option price deltas masuk ke `priceSnapshot`
  - Receipt: bullet list options di bawah item name
- **Resolution timing:** Dedicated **Phase 4.6 — Modifier System**, setelah 4.3–4.5 selesai. Atau bisa juga jadi Phase 8 jika MVP-first prioritas.

## Bug Log

### [BUG-001] Dark mode tidak rendered correctly di widget primitives — **FIXED in Phase 4.5a**

**Fix landed 2026-05-15:**
- Introduced `AppPalette` interface + `_LightPalette` / `_DarkPalette` implementations in `lib/core/theme/colors.dart`
- Added `BuildContext.colors` extension returning the right palette based on `Theme.of(this).brightness`
- Refactored all 8 widget primitives (`app_card`, `app_button`, `app_badge`, `app_bottom_sheet`, `app_empty_state`, `app_loading_indicator`, `app_numeric_keypad`, `app_text_field`) + `adaptive_shell` to use `context.colors.*` for theme-adaptive surfaces/text
- AppBadge tones now have dark-mode variants (translucent overlays of brand hue + lighter foreground)
- Swept 11 feature screens (settings, transactions, inventory, POS widgets, pos_screen, more_screen) — replaced static `AppColors.surface/border/textPrimary/etc.` with `context.colors.*`
- Brand colors (primary, accent, success, warning, danger, info) remain static — they have proper contrast in both modes by design

---

### [BUG-001 — Original entry, archived]
- **Discovered:** Phase 4.1 QA (2026-05-14)
- **Severity:** Medium (cosmetic — fungsional tetap jalan)
- **Symptoms:** Di dark mode, `AppCard` tetap putih, teks tidak terbaca (hitam-on-putih atau putih-on-putih), SegmentedButton labels invisible
- **Root cause:** `AppColors` (radius.dart, app_button.dart, app_card.dart, app_badge.dart, dll.) hardcode warna light-mode. `AppTypography` styles tidak punya warna default — saat dipakai dengan `.copyWith(color: AppColors.textPrimary)` warna hitam dipaksa.
- **Fix direction:** Widget primitives harus konsumsi `Theme.of(context).colorScheme.surface/onSurface/outline` bukan `AppColors.*` langsung. Atau buat helper `AppColors.surfaceOf(context)` yang switch berdasarkan brightness.
- **Affected files:**
  - `lib/core/widgets/app_card.dart`
  - `lib/core/widgets/app_button.dart`
  - `lib/core/widgets/app_badge.dart`
  - `lib/core/widgets/app_bottom_sheet.dart`
  - `lib/core/widgets/app_empty_state.dart`
  - `lib/core/widgets/app_loading_indicator.dart`
  - `lib/core/widgets/app_numeric_keypad.dart`
  - `lib/features/settings/settings_screen.dart` (hardcoded textPrimary/textSecondary di section headers, about rows)
- **Resolution timing:** Defer ke akhir Phase 4 (sebelum color-blind QA di 4.5) — saat itu kita audit semua warna sekalian.
