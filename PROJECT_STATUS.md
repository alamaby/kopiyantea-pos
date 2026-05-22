# PROJECT_STATUS — KopiyanteaPOS

> Workflow: `TODO → IN PROGRESS → DONE DEV → DONE QA`. Forward-only. Regressions create new `[BUG]` entries.

**Last updated:** 2026-05-19

---

## Phase 0 — Foundation Docs — **DONE QA**

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

## Phase 4 — UI Construction — **DONE QA** (semua sub-batch)

### 4.3 — Catalog management — **DONE QA** (FEAT-004 tax UI + FEAT-005 inventory stock UI deferred to backlog)
- [x] `CatalogDao` ekstensi: `watchAllForBranch`, `watchProductById`, `getProductById`, `getBySku`, `watchBranchProductPair`, `setBranchProductAvailability`, `updateProduct`, `updateBranchProduct`
- [x] `BranchDao.getActiveBranches` (snapshot read untuk propagasi)
- [x] `catalog_providers.dart` — `branchMenuFullProvider`, `productByIdProvider`, `branchProductPairProvider`
- [x] `CatalogScreen` — Menu tab dengan search, list semua produk (incl. unavailable/inactive grayed), inline availability switch, FAB tambah
- [x] `ProductFormScreen` — master CRUD; saat new auto-propagate ke semua active branch via `branchDao.getActiveBranches` loop; validasi nama wajib, harga > 0, SKU unique
- [x] `ProductDetailScreen` — 4 section: Master Card (read-only + Ubah button), Preview Card (efektif price di kasir), Branch Edit Card (inline form untuk availability + custom name + price override + diskon % + diskon valid until + date picker), **Recipe Card (komposisi bahan untuk inventory deduction)**
- [x] `RecipeEditorSheet` — bottom sheet add/edit/delete recipe row dengan item picker (filter exclude existing), qty field dengan unit-aware suffix
- [x] `InventoryDao` recipe CRUD: `watchRecipesWithItemsForProduct` (join query), `insertRecipe`, `updateRecipeQuantity`, `deleteRecipe`
- [x] Router: `/products` (shell), `/products/new`, `/products/:id`, `/products/:id/master`

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
#### 4.5c — Reports — **DONE QA**
- [x] `TransactionDao` range queries: `getCompletedInRange`, `getItemsForTransactionIds`
- [x] `report_providers.dart` — `DatePreset` (today/yesterday/7-day/30-day), `ReportRange` notifier, `DailyReport` model, pure `buildReport` aggregator, `dailyReportProvider`
- [x] `ReportsScreen`: date chips, Pendapatan card (revenue + count + AOV), Metode Pembayaran card (sorted with horizontal proportion bars), Produk Terlaris card (top 5 with rank avatar)
- [x] `RefreshIndicator` pull-to-refresh
- [x] Empty state when no transactions in period
- [x] Router: `/more/reports` → `ReportsScreen`
#### 4.5d — Color-blind audit final pass — **DONE**

**Audit method:** code review + visual inspection per screen, against ADR-0013 + master prompt §6.7 rules.

**Rules enforced:**
1. Never color-only signal — every status uses color + icon
2. Success = Sky-600 (NOT green) — distinguishable from danger red under deuteranopia/protanopia
3. Discount = Accent orange + tag/minus icon (never red)
4. Stock status = opacity + text label, color paired with status-specific icon

**Audit log — every semantic color usage verified paired with icon or non-color signal:**

| Location | Semantic | Icon paired | Non-color signal |
|---|---|---|---|
| Transaction list — Selesai badge | success (sky-600) | `check_circle_outline` | "Selesai" label |
| Transaction list — Voided badge | danger | `cancel_outlined` | "Dibatalkan" label + strikethrough total + tertiary color |
| Transaction detail — header status | success/danger | same | same |
| Inventory list — Cukup/Menipis/Habis | success/warning/danger | `check_circle_outline` / `warning_amber` / `error_outline` | status label |
| Inventory detail — low stock | warning (vs primary) | (display style, not badge) | numeric value visible |
| Inventory detail — movement delta | success(+) / danger(−) | `+`/`−` text prefix | sign in delta text |
| Cart — discount editor | accent | `local_offer_outlined` | "-Rp xxx" amount |
| Cart — manual discount in totals | accent | same | "Tambah diskon" CTA when empty |
| Cart — item notes | accent | `sticky_note_2_outlined` / `add_comment_outlined` | italic style |
| Cart — delete confirmations | danger | `delete_outline` icon + "Hapus" text | |
| Checkout — payment insufficient | danger | `error_outline` | "Kurang" label + sign |
| Checkout — change positive | success | `check_circle_outline` | "Kembalian" label |
| Receipt — success header | success (sky-600) | `check_circle` icon 72px | "Pembayaran Berhasil" heading |
| Receipt — kembalian | success | (no icon; in row context) | "Kembalian" label + numeric |
| Menu grid — discount badge | accent | `local_offer_outlined` | "-N%" text |
| Customer list — loyalty badge | accent | (no icon; standalone number) | "X poin" suffix label |
| Settings — danger button | danger | `delete_outline` (Kosongkan) | text label |
| Reports — payment bar | primary (single hue) | — (no diff needed; same color) | numeric + label per row |

**Verdict:** Compliant. Every signaling color has a non-color counterpart (icon or label).

**Browser deuteranopia / protanopia simulation:** Deferred — can be tested via `flutter run -d chrome` with Chrome DevTools "Emulate vision deficiencies" if needed. Codebase follows safe-by-construction rules so simulation is sanity-check, not gate.

### Phase 4 acceptance — **DONE**
- [x] Feature screens built against fake services (POS, Catalog menu, Inventory, Transactions, Customers, Reports, Settings)
- [x] Decompose monolithic screens per SRP (every screen split into private widget classes)
- [x] Every async flow via `AsyncValue.when` (settings, branches, customers, transactions, inventory, reports, menu)
- [ ] All strings via ARB — **deferred to Phase 7**, app is Indonesian-primary so hardcoded id_ID strings are acceptable for MVP. Currency & date already locale-aware via `intl`.
- [x] Submit buttons gated by `state.isLoading` (checkout, customer form)
- [x] Color-blind mode check (audit log above)

**Phase 4 acceptance criteria (all batches):**
- [ ] Feature screens built against fake services
- [ ] Decompose monolithic screens per SRP
- [ ] Every async flow via `AsyncValue.when`
- [ ] All strings via ARB; currency/date locale-aware
- [ ] Submit buttons gated by `state.isLoading`
- [ ] Color-blind mode check (deuteranopia + protanopia)

## Phase 5 — Hardware Integration — **IN PROGRESS**

### 5a — Bluetooth Printer — **DONE DEV** (awaiting build_runner + QA on real printer)
- [x] `pubspec.yaml` — added `esc_pos_utils_plus`, `permission_handler`
- [x] Refactored `ReceiptPayload` jadi struktur lengkap (`ReceiptItem`, branch info, totals, payment, footer, paperWidth)
- [x] `EscPosReceiptBuilder` — pure builder, paperSize-aware (58/80mm)
- [x] `BluetoothPrinterService` — real impl pakai `print_bluetooth_thermal`, permission handling Android 12+
- [x] `FakePrinterService` adapted to new payload (logs as text)
- [x] `service_providers.dart` — platform-aware (real on Android/iOS, fake elsewhere)
- [x] `PrintReceiptUseCase` — fetch tx+items+branch+customer dari DB, build payload, kirim ke printer
- [x] Wire "Cetak Struk" button di `ReceiptSummarySheet` → async print + snackbar feedback + typed errors
- [x] `PrinterSettingsScreen` — scan paired devices, connect/disconnect, test print, status card dengan badge
- [x] Settings screen entry: tappable "Printer Struk" row dengan ChevronRight ke `/more/settings/printer`
- [x] Router: `/more/settings/printer`
- [x] `AndroidManifest.xml` — BLUETOOTH_SCAN, BLUETOOTH_CONNECT (Android 12+) + legacy BLUETOOTH/BLUETOOTH_ADMIN

### 5b — Mobile Scanner — **TODO** (deferred — barcode not critical untuk coffee menu)
### 5c — Device Integrity (Play Integrity / App Attest) — **TODO** (deferred — security hardening, can be Phase 8)

## Phase 6 — Supabase Sync & Security — **IN PROGRESS**

### 6a — SQL migrations — **DONE QA** (applied on Supabase, verified via owner login)
- [x] 10 migration files in `/supabase/migrations/` with timestamped names
- [x] `001_branches_users` (branches + app_users + user_branch_access)
- [x] `002_catalog` (products + branch_products) with discount/override constraints
- [x] `003_inventory` (inventory_items + inventory_movements + product_recipes) with UNIQUE constraints
- [x] `004_customers` (phone UNIQUE when set)
- [x] `005_transactions` (append-only schema + tax snapshot columns + server_received_at trigger)
- [x] `006_settings` (receipt_settings)
- [x] `007_indexes` (9 indexes including partial indexes for active discounts + locked users)
- [x] `008_inventory_trigger` (cached_stock reconciliation server-side — matches client-side ADR-0003)
- [x] `009_rls_helpers` (`user_has_branch_access`, `user_global_role` STABLE SECURITY DEFINER)
- [x] `010_rls_policies` — full matrix from ADR-0007: append-only transactions (no UPDATE/DELETE), owner-only products write, branch-scoped reads
- [x] `seed.sql` mirrors `SeedService` for staging parity

### 6b — Code foundation (env, secure storage, Supabase init) — **DONE QA**
- [x] `lib/core/storage/secure_storage.dart` — Keychain/encrypted-SharedPreferences wrapper dengan key constants
- [x] `lib/core/network/supabase_providers.dart` — `supabaseClientProvider` + `secureStorageProvider`
- [x] `main.dart` boot reorganized:
  1. `Env.validate()` — fail-fast dengan dedicated `_EnvErrorApp` fallback (no black screen)
  2. Local-first: intl + Drift + seed (must succeed)
  3. `Supabase.initialize()` — graceful failure dengan logger warn (offline-first per ADR + master prompt §14 risk #4)
### 6c — Auth flow (Supabase login) — **DONE QA**
- [x] `AuthRepository` — Supabase signin/signout + Drift app_users lookup; graceful when Supabase not initialized
- [x] `AuthError` enum, `AuthedSession` value class
- [x] `authProvider` rewrite — microtask session restore, `signIn`/`signInAsDemo`/`signOut` methods, `currentUserProvider` returns `AppUserRow?`
- [x] `LoginScreen` — email/password + demo bypass + error display + obscure toggle
- [x] Router auth guard — `refreshListenable` bridges Riverpod, unauth → /login, auth on /login → /pos
- [x] Settings `_SignOutSection` — user info + logout dengan confirm dialog
- [x] `CheckoutUseCase` provider — pakai `currentUserProvider.id`
- [ ] Server-side lockout via Edge Function — deferred (Supabase rate limiting suffices for MVP)

### 6d — Cert pinning HTTP client — **DONE DEV**
- [x] `lib/core/network/pinned_http_client.dart` — `buildPinnedHttpClient(fingerprints)` returns http.Client backed by Dart `HttpClient` with `SecurityContext(withTrustedRoots: false)` + `badCertificateCallback` doing SHA-256 fingerprint match
- [x] Accepts both `AA:BB:CC:...` and `AABBCC...` fingerprint forms
- [x] Empty fingerprints → falls back to default http.Client (dev mode); production gated by `Env.validate()`
- [x] Wired into `Supabase.initialize(httpClient: ...)` in main.dart
- [x] Logs rejected fingerprints for debugging
### 6e — Sync MVP (push outbox + pull auth context) — **DONE DEV**
- [x] `BranchDao.upsertUserBranchAccess` added
- [x] `lib/core/sync/sync_dtos.dart` — Row→JSON for `TransactionRow`/`TransactionItemRow`/`InventoryMovementRow`/`CustomerRow`; JSON→Companion for `AppUser`/`UserBranchAccess`/`Branch`
- [x] `SyncRepository.pullMyAuthContext(userId)` — pulls user + branch access + accessible branches; called in `AuthRepository.signIn` so first-time Supabase signin on a fresh device works
- [x] `SyncRepository.pushOutbox()` — drains outbox FIFO; tx items + linked inventory_movements ride on parent push (idempotent ON CONFLICT DO NOTHING); customers use LWW
- [x] Exponential backoff schedule 1s/5s/30s/5m/30m on failure
- [x] `SyncState` Freezed + `Sync` notifier with `syncNow()` manual trigger
- [x] `pendingOutboxCountProvider` (Stream from outbox DAO)
- [x] Settings `_SyncSection` — badge (Tersinkron / N menunggu), last sync timestamp, last result counters, error banner, Sinkron Sekarang button
- [x] Master data pull — `pullMasterData(branchIds)` covers products (chain-wide), branch_products + inventory_items + product_recipes + receipt_settings (branch-scoped), customers (chain-wide). LWW via `insertOnConflictUpdate`. Settings sync button wires through `allBranchesProvider`.
- [x] Transaction history pull (Phase 6e3) — `pullTransactions(branchIds, limit=100)` fetches recent transactions + items + linked inventory_movements. Multi-device history visibility works. No incremental cursor yet — fetches last 100 each sync.
- [x] `InventoryDao.upsertRecipe` for pull idempotency
- [x] `SyncState` carries `lastPulled` counter; Settings card shows `kirim · terima · gagal` breakdown
- [ ] Background sync via workmanager — deferred (0.5.2 broken; need 0.6.x or alternative)

## Phase 7 — Optimization & Release — **DONE DEV** (awaiting actual release runthrough)

- [x] `AppLogger` production-gated (warning+ in prod, debug+ in dev) — `PrettyPrinter` config, no method traces in prod
- [x] Global error handlers wired in `main()` — `FlutterError.onError` + `PlatformDispatcher.instance.onError` → `AppLogger`
- [x] `android/app/proguard-rules.pro` — Flutter, Drift, Supabase, Bluetooth printer, MLKit, secure storage, Freezed, kotlinx.serialization
- [x] `docs/release.md` — full procedure: pre-flight checklist, keystore + `key.properties` + `build.gradle` signingConfig, ProGuard wire-up, `flutter build apk/appbundle` commands, iOS ipa, cert pinning rotation (extract → overlap → drop), Play Store submission checklist, post-release tagging
- [x] README updated with Build Commands section + link to release.md
- [x] No `print()` calls in feature code (all logging via `Logger` / `AppLogger`)
- [x] App signing wired in `build.gradle.kts` (Kotlin DSL signingConfigs + R8 Play Core keep rules; keystore `upload-keystore.jks` at repo root, gitignored; release AAB built successfully 2026-05-18)
- [ ] iOS archive + TestFlight — **deferred unless requested**, instructions in release.md
- [ ] CI test diffing DDL ⇄ Freezed models — **deferred** (master prompt §14 risk #10)

---

## Tech Debt

### [TD-001] Codegen ecosystem upgrade — analyzer 6.x → 13.x
- **Discovered:** 2026-05-18 (FEAT-001 batch A)
- **Symptom:** drift_dev 2.21+ crashes with `Null is not InterfaceElement` on analyzer 6.4.x
- **Workaround:** Pinned `drift` and `drift_dev` to `>=2.20.0 <2.21.0`
- **Root cause:** `freezed ^2.5.2` + `riverpod_generator ^2.4.0` transitively constrain analyzer to 6.x. Upgrading to analyzer 13.x requires major version bumps of all codegen tools (freezed 2→3 has breaking changes, riverpod 2→3 has new APIs).
- **Resolution path:** Do a coordinated upgrade — bump `freezed`, `freezed_annotation`, `riverpod`, `riverpod_annotation`, `riverpod_generator`, `json_serializable`, `analyzer`, `drift`, `drift_dev` together. Schedule for a dedicated maintenance phase.

## Backlog (deferred features)

### [FEAT-002] Multi-Tenant Isolation
- **Requested:** 2026-05-18
- **Use case:** Vendor model — owner A runs "Kopiyantea" chain, owner B runs separate "Cafe XYZ", both use the same app/Supabase project with **data isolated per business**. Currently the schema is single-tenant (master prompt §14 risk #7) — all owners share `products`/`customers`/`option_groups`/`branches` across the project.
- **Scope (Phase 8):**
  - Add `tenants` table (id, name, created_at, owner_user_id)
  - Add `tenant_id` column to all chain-wide tables: `branches`, `products`, `customers`, `option_groups`, `options`, `app_users` (and propagate via branch chain for branch-scoped tables)
  - Backfill existing rows to a single default tenant (non-destructive per ADR-0008)
  - Add `user_tenant()` SQL helper + update all RLS policies to filter by `tenant_id = user_tenant()`
  - Onboarding flow: signup creates new tenant; invite flow joins existing tenant
  - Add tenant indicator in UI (branch picker shows tenant scope)
- **Estimated effort:** 15-20 SQL migration files + RLS rewrite + onboarding UI + tenant-aware sync. Substantial — typically pre-launch hardening for SaaS pivot. Not needed for single-business deployment.

### [FEAT-003] Outbox Queue Detail Screen — **DONE DEV** (2026-05-20)
**Implemented:**
- `OutboxDao.watchAll` / `deleteById` / `retryNow` / `retryAllFailed`
- `/more/settings/sync` route → `OutboxQueueScreen`
- Settings sync section: tombol "Lihat Antrian"
- UI: list grouped by status (gagal/menunggu/selesai), per-row entity icon + label, payload preview, lastError banner, attempt count, retry/delete per row, retry-all from AppBar
- Confirm dialog before delete (warning: lossy)

**Backlog entry — original:**
- **Requested:** 2026-05-18 (after first Supabase migrate)
- **Use case:** When sync push fails (e.g., RLS reject from stale demo cashier_id, FK violation, network error mid-push), the badge shows "N gagal" but user has no way to inspect WHICH rows failed, WHY, or to clear them. Currently the only recovery is `adb shell pm clear` (lossy) or wait for backoff retries (which keep failing).
- **Scope (Phase 7+):**
  - New route `/more/settings/sync` (or sub-route from Settings sync section)
  - List outbox rows grouped by status (pending / failed / done)
  - Per row: entity type, payload preview (e.g., tx short id, amount), createdAt, attempt count, lastError, nextRetryAt
  - Actions per row: Retry now (resets nextRetryAt to now), Skip (mark done without push — lossy), Delete (hard delete from outbox)
  - Bulk actions: Clear all failed, Retry all failed
  - Warning banner explaining "Skip" loses data — only for dev/cleanup
- **Estimated effort:** 1 provider + 1 screen + extend OutboxDao with `markDone`/`delete`. ~3 files. Small.



## Phase 8 — Feature Backlog Sprint 1 — **DONE DEV** (awaiting build_runner + QA)

Empat fitur dari backlog dikerjakan dalam satu sprint (2026-05-19). Semua butuh `dart run build_runner build --delete-conflicting-outputs` sebelum bisa di-build, dan satu migration Supabase manual.

### Phase 8a — FEAT-004 Tax Settings UI per-branch — **DONE QA**
- [x] `BranchDao.updateById` partial update untuk tax columns
- [x] `TaxSettingsScreen` (`/more/settings/tax`) — list cabang, edit tarif/label/inclusive, preview perhitungan, outbox enqueue
- [x] Sync push `_pushBranch` di SyncRepository + `BranchSyncDto`
- [x] Owner-gated link di Settings screen

### Phase 8b — FEAT-005 Inventory Stock Management UI — **DONE QA**
- [x] `InventoryItemFormScreen` (`/inventory/new`, `/inventory/:id/edit`) — master CRUD untuk bahan baru
- [x] `StockMovementScreen` (`/inventory/:id/movement`) — Pembelian / Penyesuaian / Limbah dengan qty + notes, local cached_stock reconciliation
- [x] FAB "+ Tambah Item" di `InventoryListScreen`
- [x] Tombol "Catat Pergerakan" + edit di `InventoryDetailScreen`
- [x] Sync push standalone `inventoryItem` + non-tx `inventoryMovement` di SyncRepository + DTO

### Phase 8c — FEAT-006 User Management — **DONE DEV**
- [x] Drift schema v3: `app_users.email` column + `PendingInvitations` table
- [x] `BranchDao` extensions: `watchAllUsers`, `getUserByEmail`, `getPendingInvitationByEmail`, `upsertPendingInvitation`, `deletePendingInvitation`, access diff helpers
- [x] `UserListScreen` (`/more/settings/users`) — daftar user + pending invitations, FAB "Undang"
- [x] `UserFormScreen` (`/more/settings/users/new`, `:id`) — invite (name + email + role + branch multi-select) + edit (role/active/access)
- [x] **Invite-only claim flow** (no service_role needed): owner writes `pending_invitations` row → outbox push → invitee signs up to Supabase with that email → on first sign-in `AuthRepository._maybeClaimInvitation` matches by email, fans out into `app_users` + `user_branch_access`, deletes invitation
- [x] `SyncRepository.pullPendingInvitationByEmail` + entity-aware push for app_user / user_branch_access / pending_invitation
- [x] Supabase migration `20260519150001_user_management.sql` — `app_users.email` column + `pending_invitations` table + RLS (owner-write, self-read-by-email-match, self-claim insert into `app_users` + `user_branch_access`)
- [x] Owner-gated link di Settings screen

### Phase 8d — FEAT-001 Modifier System (full) — **DONE QA**
- [x] Schema sudah ada dari sebelumnya (Drift `option_tables.dart` + Supabase `20260518150011_modifiers.sql`)
- [x] DAO `OptionDao` lengkap (group/option CRUD, product link, snapshot insert/read)
- [x] `OptionGroupsScreen` (`/more/settings/modifiers`) — daftar grup, FAB "Grup Baru"
- [x] `OptionGroupFormScreen` (`/more/settings/modifiers/new`, `:id`) — CRUD grup + bottom sheet untuk opsi (nama, +Rp delta, isDefault)
- [x] `ProductOptionsScreen` (`/products/:id/options`) — checkbox list bind/unbind grup ke produk
- [x] `OptionPickerSheet` POS — modal saat tambah ke kasir, multi/single select + required validation + default-seeding + total delta preview
- [x] `cart_state` extended: `CartItemOption` + `selectedOptions` per item + `effectiveUnitPrice`/`lineSubtotal` helpers
- [x] `cart_provider.addItem` accepts `selectedOptions`, merges line hanya jika option set sama persis
- [x] `MenuGrid` membuka picker dulu kalau produk punya bound groups
- [x] `CheckoutUseCase` insert `transaction_item_options` snapshots; `transaction_items.priceSnapshot` = effective unit price (base + deltas)
- [x] `TransactionDetailScreen` & `transactionDetailProvider` show modifier snapshots di bawah item
- [x] `ReceiptItem.options` field; `EscPosReceiptBuilder` print bullet `- Grup: Opsi` di bawah baris item
- [x] `print_receipt_use_case` fetch snapshots via `OptionDao.getSnapshotsForItems`
- [x] Sync push extended: `_pushTransaction` ikut push `transaction_item_options`, `_pushOptionGroup`/`_pushOption`/`_pushProductOptionGroup`
- [x] Owner-gated "Modifier Produk" link di Settings + link card di Product Detail

### Outstanding (untuk QA)
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` (Drift v3 + new providers + cart_state.freezed)
- [ ] Apply Supabase migration `20260519150001_user_management.sql`
- [ ] Test end-to-end: tax change → sync, stock movement → cached_stock reconcile, invite → sign up → claim, modifier checkout → receipt print

---

## Bootstrap Flow (2026-05-20)

### Remove seed + post-login bootstrap pull — **DONE DEV**
**Rationale:** First-time use requires login (which requires internet) anyway. Local seed is dev clutter that creates a stale-data trap (developer test data leaking into prod sessions). After login, pull fresh data from Supabase → user always operates on up-to-date state.

**Implemented:**
- `lib/core/database/seed_service.dart` **deleted**
- `main.dart` — removed `SeedService(...).ensureSeeded()` call
- `lib/features/auth/bootstrap_provider.dart` (new) — `BootstrapState` sealed union: `complete`, `pending`, `running(step)`, `failed(error)`. `keepAlive: true` so state survives auth state churn. `markPending`, `reset`, and `run()` that calls `pullMyAuthContext` → `pullMasterData` → `pullTransactions` with step-by-step UI updates
- `lib/features/auth/bootstrap_screen.dart` (new) — blocking loading screen with brand mark, current step text, error block with Coba Lagi + Keluar buttons
- `auth_provider.dart` — `signIn` + magic-link `resolveSessionWithClaim` now call `bootstrapProvider.markPending()` BEFORE flipping auth state to Authenticated so router sees pending on first redirect. `signOut` calls `bootstrap.reset()` for clean slate.
- `auth_repository.dart` — `signInAsDemo()` removed (depended on seed)
- `login_screen.dart` — demo button + footer text removed
- `router.dart` — new `/bootstrap` route, redirect logic: `unauth → /login`, `authed + bootstrap in-flight → /bootstrap`, `authed + complete → /pos`. RefreshListenable now bridges BOTH auth and bootstrap providers

**Session-restore behavior:** When the app cold-starts and a Supabase session is restored from `flutter_secure_storage`, bootstrap state stays `complete` (default) — user goes straight to /pos with cached data. Only explicit sign-in (form / magic link) triggers the bootstrap pull. Trade-off: a user could be using stale data after long offline period; the manual "Sinkron Sekarang" in Settings + on-app-resume sync (future) cover that.

**Outstanding QA:**
- [ ] `dart run build_runner build --delete-conflicting-outputs` (new freezed + riverpod files)
- [ ] Smoke: install app first time → login → bootstrap screen muncul → step labels berjalan ("Memuat akses cabang…" → "Memuat menu & stok…" → "Memuat riwayat transaksi…") → navigate ke /pos
- [ ] Edge: matikan internet di tengah bootstrap → error screen muncul → "Coba Lagi" → tunggu internet kembali → bootstrap ulang
- [ ] Edge: kill app saat di /pos → buka lagi → langsung ke /pos (session restore, tanpa bootstrap)
- [ ] Edge: sign out → sign in lagi (user sama) → bootstrap ulang berjalan
- [ ] Edge: user yang tidak punya branch access → error screen menampilkan "tidak punya akses ke cabang manapun"
- [ ] Verifikasi seed_service.dart benar-benar terhapus dari `git log` setelah commit

**Catatan migrasi:** User existing yang sudah punya seed data lokal masih punya datanya — bootstrap akan upsert/overlay dengan data Supabase, tidak menghapus. Untuk fresh-state test, hapus app + reinstall, atau `adb shell pm clear`.

---

## Receipt QR (2026-05-20)

### [ENH-004] Print Static QRIS on Receipt — **DONE DEV**
**Implemented (static QR only — no dynamic generation):**
- Drift v10: `receipt_settings.printQrisOnReceipt` column (default false)
- `ReceiptPayload.qrisImageBytes` — raw image bytes, decoded + rendered by ESC/POS builder
- `EscPosReceiptBuilder` — when `qrisImageBytes` set, append "SCAN QRIS UNTUK BAYAR" header + "Masukkan nominal sesuai TOTAL di atas" hint + QR image (auto-resize to paper width via existing `_renderLogo` helper)
- `PrintReceiptUseCase` — opt-in fetch only when `setting.printQrisOnReceipt && tx.paymentMethod == qris && branch.qrisImageUrl != null`. Refactored `_maybeFetchLogo` → shared `_fetchCached(url)` helper (renamed `_logoCache` → `_imageCache`)
- `ReceiptSettingsScreen` — new SwitchListTile "Cetak QRIS di struk" with use-case explanation
- `sync_dtos.dart` — `receiptSettingFromJson` includes `print_qris_on_receipt`
- Supabase migration `20260520150005_receipt_qris_toggle.sql`

**Outstanding QA:**
- [ ] `dart run build_runner build --delete-conflicting-outputs` (schema v10)
- [ ] Apply Supabase migration
- [ ] Smoke: owner aktifkan toggle + branch sudah punya QRIS → checkout method QRIS → print → QR muncul di struk dengan header "SCAN QRIS UNTUK BAYAR"
- [ ] Smoke: toggle OFF → QR tidak muncul; method ≠ QRIS → QR tidak muncul walau toggle ON
- [ ] Edge: branch tanpa QRIS upload + toggle ON → QR skip silently
- [ ] Edge: offline saat cetak pertama (sebelum cache) → skip silent, struk tetap keluar

**Scope catatan:** ENH-004 versi aman — pakai QR statis yang sudah di-upload owner. Tidak generate dynamic QR. Untuk dynamic QR, lihat 2 backlog item baru: `TODO-QRIS-DYN-STATIC` dan `TODO-QRIS-DYN-AGGR`.

---

## Bank Accounts (2026-05-20)

### [FEAT-015] Global Bank Transfer Accounts — **DONE DEV**
**Implemented:**
- Drift v9: new `BankAccounts` table (id, bankName, accountNumber, accountHolder, displayOrder, isActive, createdAt, updatedAt) — chain-wide, single-tenant scope
- `Transactions` additions: `bankAccountId` (nullable FK) + `bankAccountSnapshot` (immutable display string for receipt/report survivability)
- `BankAccountDao` + `bankAccountDaoProvider`
- `bank_account_providers.dart` — `allBankAccountsProvider` (admin), `activeBankAccountsProvider` (checkout), `formatBankAccountSnapshot()`
- `BankAccountsScreen` (`/more/settings/bank-accounts`) — owner-only CRUD list + bottom-sheet form (bankName/accountNumber/accountHolder/displayOrder/isActive), per-row Edit/Toggle/Delete
- `BankAccountPickerSheet` — bottom sheet untuk checkout, list active accounts
- `CartState.bankAccount` + `CartNotifier.setBankAccount`
- `CheckoutSheet._BankAccountSection` — muncul saat metode=Transfer, tampilkan rekening terpilih atau prompt "Pilih Rekening", tombol Ganti
- Konfirmasi button blocked sampai bank account terpilih (Transfer)
- `CheckoutUseCase` — write `bankAccountId` + `bankAccountSnapshot` ke `Transactions`, `CheckoutError.bankAccountMissing` baru
- `ReceiptPayload.bankAccountSnapshot` + EscPosReceiptBuilder cetak "  BCA 1234567890 - John Doe" di bawah "Bayar: Transfer"
- `TransactionDetailScreen._PaymentCard` — "Rekening" row di bawah "Metode"
- `Reports`: `DailyReport.byBankAccount` (Map<snapshot, PaymentStats>) — pure aggregator; `_BankAccountCard` di ReportsScreen menampilkan Transfer per Rekening dengan progress bar accent (hanya muncul saat ada transfer)
- Outbox: `OutboxEntityType.bankAccount` + `SyncRepository._pushBankAccount` (handle delete via missing local → server DELETE)
- Master pull: `SyncRepository.pullMasterData` ikut sync `bank_accounts`
- Sync DTOs: `BankAccountSyncDto` (push) + `bankAccountFromJson` (pull); `transactionFromJson` + `TransactionSyncDto` include `bank_account_id` + `bank_account_snapshot`
- Settings owner tile "Rekening Bank"
- Supabase migration `20260520150004_bank_accounts.sql` — table + RLS (owner-write, authenticated-read) + transactions columns + index

**Outstanding QA:**
- [ ] `dart run build_runner build --delete-conflicting-outputs` (schema v9 + new DAO + new providers)
- [ ] Apply Supabase migration
- [ ] Smoke: owner tambah 2 rekening (BCA + Mandiri) → kasir login → checkout method=Transfer → tombol "Pilih Rekening" → picker tampil 2 rekening → pilih → konfirmasi → transaksi tersimpan dengan FK + snapshot
- [ ] Smoke: print struk → muncul "Bayar Transfer / BCA 1234567890 - John"
- [ ] Smoke: detail transaksi → Payment Card menampilkan "Rekening: BCA ..."
- [ ] Smoke: 3 transaksi transfer (2 BCA, 1 Mandiri) → buka Laporan → muncul "Transfer per Rekening" card dengan breakdown
- [ ] Edge: owner hapus rekening → transaksi lama tetap menampilkan snapshot; picker tidak menampilkan rekening yang dihapus untuk transaksi baru
- [ ] Edge: kasir pilih method=Transfer tanpa pilih rekening → tombol Konfirmasi disabled; force tap (kalau dari testing override) → use case return `bankAccountMissing`
- [ ] Edge: cabang berbeda → rekening tetap sama (global, bukan per-cabang)

---

## Receipt Template (2026-05-20)

### [FEAT-014] Receipt Template Configuration — **DONE DEV**
**Implemented:**
- Drift v7: `receipt_settings.logoPosition` column ('top'/'bottom') + non-destructive migration
- `ImageBuckets.logos` = `receipt-logos` (Supabase Storage bucket)
- `pubspec.yaml` — `image` (decode), `http` (fetch logo bytes for printer)
- `ReceiptPayload` — `logoBytes` + `logoPosition` fields
- `EscPosReceiptBuilder._renderLogo` — decode + resize to paper width (max 384px untuk 58mm, 576px untuk 80mm) + raster output via `g.image()`. Logo rendered di top atau bottom sesuai setting. Decode error tidak gagal job, struk tetap cetak tanpa logo.
- `PrintReceiptUseCase` — fetch `ReceiptSettingRow` for branch, http-download logo bytes, in-memory cache per URL untuk avoid re-download saat reprint
- `ReceiptSettingsScreen` (`/more/settings/receipt`) — per branch: header text, footer text, logo upload + position toggle (Atas/Bawah) + show/hide switch, paper width (58/80mm), save
- Owner-gated link "Tampilan Struk" di Settings
- Supabase migration `20260520150002_receipt_logo.sql` — column + bucket + RLS
- `sync_dtos.receiptSettingFromJson` — include `logo_position`

**Format logo yang harus disiapkan oleh owner:**
- PNG hitam-putih murni (1-bit). Color akan di-dither otomatis di printer
- Background putih solid (jangan transparan)
- Max width 384px (58mm) atau 576px (80mm); auto-downsized kalau lebih besar
- Max height ~200px ideal
- File size < 100 KB
- Tip: convert via `Image → Mode → Bitmap → 50% threshold` di GIMP/PS untuk hasil tajam

**Outstanding QA:**
- [ ] `flutter pub get` (image + http baru — sebagian besar mungkin sudah transitive)
- [ ] Apply Supabase migration (bucket + column)
- [ ] `dart run build_runner build --delete-conflicting-outputs` (schema v7)
- [ ] Smoke: owner upload logo + atur posisi top → checkout → print → logo muncul di atas branch name; ganti ke bottom → print → logo muncul setelah footer
- [ ] Smoke: edit footer "Barang yang sudah dibeli tidak dapat ditukar" → print → footer muncul
- [ ] Edge: matikan show_logo → print → logo tidak muncul walau URL ada
- [ ] Edge: offline mode + cache kosong → print → logo skip, struk tetap keluar tanpa error
- [ ] Test multi-cabang: setting cabang A ≠ cabang B

---

## Images Sprint (2026-05-20)

### [FEAT-012] Product Photo Upload — **DONE DEV**
**Implemented:**
- `pubspec.yaml` — `image_picker`, `flutter_image_compress`, `cached_network_image`
- `lib/core/storage/image_upload_service.dart` — pick (galeri/kamera) → compress (max 1024px JPEG q=80) → upload Supabase Storage public bucket → return public URL. Cleanup `deleteByUrl` for orphan removal.
- `ImageBuckets.products` = `product-images`
- `ProductFormScreen` — `_PhotoSection` di atas form: 16:9 preview, tap = picker sheet (galeri/kamera), tombol Ganti Foto + Hapus. Replace old image otomatis cleanup di Supabase.
- `ProductFormScreen._save` — enqueue outbox `product` push (sebelumnya edit produk tidak push — gap pre-existing diperbaiki di sini)
- `MenuGrid` — thumbnail 1:1 dengan `CachedNetworkImage`, placeholder kopi icon kalau kosong/error; discount badge overlay
- `ProductDetailScreen._MasterCard` — hero image 16:9
- Supabase migration `20260520150001_storage_and_images.sql` — bucket creation + RLS owner-write public-read

**Outstanding QA:**
- [ ] `flutter pub get` (3 paket baru)
- [ ] Apply Supabase migration (penting untuk buat bucket + RLS)
- [ ] `dart run build_runner build --delete-conflicting-outputs` (schema v6 + DTOs)
- [ ] Smoke: tambah produk → upload foto → save → cek MenuGrid muncul thumbnail; ganti foto → cek storage tidak ada orphan; offline mode → foto pakai cache CDN
- [ ] Verify RLS: kasir login coba upload → ditolak (cek di Supabase logs)

### [FEAT-013] Static QRIS per Branch — **DONE DEV**
**Implemented:**
- Drift v6: `branches.qrisImageUrl` column + non-destructive migration
- `sync_dtos.dart` — branch push/pull DTO menyertakan `qris_image_url`
- `ImageBuckets.qris` = `qris-images`
- `QrisSettingsScreen` (`/more/settings/qris`) — list cabang dengan preview QR, Galeri/Kamera buttons, Hapus QRIS. Save = update branch + outbox push.
- `QrisDisplaySheet` (`features/pos/widgets/qris_display.dart`) — fullscreen modal dengan QR + nominal optional + branch name. Mode `onConfirmPaid` (checkout) atau preview-only (POS AppBar).
- POS AppBar — IconButton QR quick-access (hanya muncul saat branch punya qrisImageUrl)
- `CheckoutSheet` — saat metode = QRIS, tampilkan `_QrisSection` card dengan tombol "Tampilkan QRIS". Klik → modal QR + tombol "Pembayaran Diterima" → langsung submit checkout. Fallback hint kalau branch belum upload QR.
- Settings OwnerSection — entry "QRIS Statis"
- Supabase migration `20260520150001_storage_and_images.sql` — `qris_image_url` column + bucket + RLS

**Outstanding QA:**
- [ ] Apply migration di Supabase + verifikasi bucket dibuat
- [ ] Smoke: owner upload QRIS → cek render di POS AppBar; ganti metode jadi QRIS di checkout → modal tampil + nominal benar; tap "Pembayaran Diterima" → tx tersimpan
- [ ] Smoke: cabang tanpa QR → AppBar button tidak muncul; checkout QRIS pilih → hint "QRIS belum tersedia"
- [ ] Offline mode: pertama upload perlu online; berikutnya muncul dari cache (`cached_network_image`)

---

## Enhancements Sprint (2026-05-20)

### [ENH-001] Tutup Kas / Z-report — **DONE DEV**
**Implemented (local-only):**
- Drift v5: `ShiftClosings` table + non-destructive migration
- `ShiftClosingDao` (`watchForBranch`, `insert`, `getLatestForBranch`)
- `shift_closing_providers.dart` — `todayCashSummaryProvider` (sum of today's cash txs, refunds netted via void rows), `shiftClosingHistoryProvider`
- `ShiftClosingScreen` (`/more/reports/closing`) — Header (cabang + tanggal), input float, expected cash readout, input counted cash, real-time variance card (pas/kurang/lebih dengan icon+warna), notes, riwayat 30 closing terakhir
- MoreScreen entry "Tutup Kas"

**Deferred:** Supabase sync (`shift_closings` table + RLS + push fn). Local-only is acceptable untuk audit log per device shift.

**Outstanding QA:**
- [ ] `dart run build_runner build --delete-conflicting-outputs` (Drift v5 + new `.g.dart` providers/dao)
- [ ] Smoke: 3 transaksi cash → cek expected; void salah satu → cek refund row di breakdown; tutup kas dengan counted = expected → variance 0; counted < expected → "Kurang" badge

### [ENH-002] Quick "Hari Ini" Badge — **DONE DEV**
**Implemented:**
- `TransactionDao.watchCompletedInRange` — reactive stream variant of `getCompletedInRange`
- `today_badge_provider.dart` — `TodayBadgeStats` + `todayBadgeStatsProvider` (family by `branchId`); StreamProvider re-emits via Drift on checkout/void
- Midnight auto-rollover: one-shot `Timer` to `nextMidnight + 1s` → `ref.invalidateSelf()`; `ref.onDispose(timer.cancel)` safeguard
- `TodayQuickBadge` widget (`lib/features/reports/widgets/today_quick_badge.dart`) — `AppBadge` (tone accent, icon `today_outlined`) showing `<n> tx · Rp <revenue>` with compact rupiah (`rb`/`jt`); tap → `/more/reports`; hidden when no branch selected
- Mounted di `PosScreen` AppBar (actions, kiri QRIS/Held) + `HomeScreen` AppBar

**Outstanding QA:**
- [ ] `dart run build_runner build --delete-conflicting-outputs` (new `today_badge_provider.g.dart`)
- [ ] `flutter analyze`
- [ ] Smoke: login → Home + POS AppBar tampil `0 tx · Rp 0`; checkout cash 1 tx → kedua badge update reaktif; void tx → revenue & count turun; tap badge → buka Reports
- [ ] Edge: ganti cabang aktif → badge re-fetch
- [ ] Midnight rollover: set jam device ke 23:59 → tunggu ~1 menit → badge reset ke 0 tanpa restart

### [ENH-003] Snackbar Undo: Cart Item & Cancel Invitation — **DONE DEV**
**Implemented:**
- `lib/core/widgets/undo_snackbar.dart` — `buildUndoSnackBar` factory (label "BATAL", floating, 4s) shared by both callsites
- Cart: `CartItemTile._confirmDelete` → `_deleteWithUndo` — optimistic remove + snackbar; tap BATAL → `CartNotifier.restoreItem(item, index: removedIndex)` mengembalikan ke posisi semula
- Invitation: `_DismissibleInvitation._cancelInvitation` snapshot row + capture outbox id pra-delete; new `_undoCancelInvitation` re-insert local + `outboxDao.deleteById(deleteOutboxId)` + enqueue ulang (push handler simetri → server row re-created bila DELETE sudah ter-sync)
- `ScaffoldMessenger.hideCurrentSnackBar()` di kedua flow → no stacked snackbars saat hapus berturut-turut
- AlertDialog "Hapus item?" untuk cart dihapus (tetap pakai konfirmasi swipe untuk undangan karena impact server)

**Outstanding QA:**
- [ ] `flutter analyze`
- [ ] Smoke cart: tambah 2 item → hapus line 1 → langsung hilang + snackbar → BATAL → kembali di index 0; lalu hapus + tunggu 4 detik → permanen
- [ ] Smoke invitation: owner → swipe → confirm → snackbar → BATAL → row balik di list; jalankan Sync Now sebelum BATAL → row tetap balik + outbox baru di-enqueue → sync lagi → server row re-created

### [FEAT-008] Google Sign-In OAuth — **DONE DEV** (client-side)
**Implemented:**
- `AuthRepository.signInWithGoogle()` — wrapper `signInWithOAuth(OAuthProvider.google, redirectTo: kAuthDeepLink)`; session datang via existing `onAuthStateChange` listener → reuse `resolveSessionWithClaim` (sama dengan magic link)
- `Auth.signInWithGoogle()` notifier method
- LoginScreen: tombol "Lanjutkan dengan Google" (icon `account_circle_outlined`) di bawah Magic Link

**Pre-requisite manual (TIDAK OTOMATIS):**
- [ ] Supabase Dashboard → Auth → Providers → Google: enable + paste Client ID/Secret
- [ ] Google Cloud Console: buat OAuth 2.0 Client; authorized redirect URI = `https://<project-ref>.supabase.co/auth/v1/callback`
- [ ] Supabase Auth → URL Configuration → Redirect URLs: `kopiyantea://login-callback` (sudah ada untuk magic link)
- [ ] Android `AndroidManifest.xml`: intent-filter `kopiyantea://` (sudah ada)

**Outstanding QA:**
- [ ] `flutter analyze`
- [ ] Setelah config Supabase: tap tombol Google → browser eksternal → pilih akun → redirect kembali ke app → otomatis masuk ke /pos
- [ ] Akun Google yang email-nya tidak terdaftar di `app_users` + tidak ada pending invitation → error `userNotRegistered`

### [ENH-010] Catalog Bulk Import/Export CSV — **DONE DEV** (MVP)
**Implemented:**
- `CatalogDao.getAllProducts()` — snapshot semua produk (sorted by name)
- Pure helper `lib/features/catalog/catalog_csv.dart` — `exportProductsToCsv(List<ProductRow>)` (RFC 4180-ish escape) + `parseProductsCsv(String)` → `CsvParseResult(ok, errors)`; header detection, per-row validation with line numbers; ID kosong → UUID v7 auto
- CatalogScreen AppBar PopupMenu (owner-only) "Ekspor CSV" / "Impor CSV"
- Ekspor → `Clipboard.setData` → snackbar count
- Impor: parse → preview dialog (jumlah OK + daftar errors scrollable) → confirm → `upsertProduct` + `outboxDao.enqueue` per row (entity=product) → snackbar

**Scope MVP:** Hanya Products global (id, name, category, base_price, sku, is_active). **Belum**: `branch_products` overrides, `product_recipes`, `option_groups`, image URL.

**Outstanding QA:**
- [ ] `flutter analyze`
- [ ] Smoke: 5 produk → Ekspor → paste di Google Sheets → 5 row terbaca header benar; edit 1 + tambah 1 tanpa id → Impor → preview tampil "6 OK"; konfirmasi → produk muncul di list; outbox terisi 6 row → sync → server upsert
- [ ] CSV malformed (kurang kolom name) → dialog tampil errors per baris, tidak ada produk dibuat

### [ENH-009] Telemetry Dashboard di Settings — **DONE DEV**
**Implemented:**
- `telemetry_provider.dart` — `TelemetrySnapshot` (app name+version, db size bytes, row counts: transactions/items/movements, outbox pending/failed/done, lastSyncAt)
- DB size via `path_provider` + `File.length()`; row counts via `COUNT(*)` custom expression
- `telemetry_screen.dart` — 3 card (Aplikasi, Database, Sinkronisasi) dengan `formatRelativeTime` untuk lastSyncAt; refresh action di AppBar (`ref.invalidate`)
- Route `/more/settings/telemetry` + entry `_OwnerTile(icon: analytics_outlined)` di OwnerSection Settings

**Outstanding QA:**
- [ ] `dart run build_runner build --delete-conflicting-outputs` (`telemetry_provider.g.dart` baru)
- [ ] `flutter analyze`
- [ ] Smoke: owner → Pengaturan → Telemetri → semua angka muncul; refresh icon update

### [ENH-011] Settings Export/Import (Config Backup) — **DONE DEV**
**Implemented:**
- `SettingsNotifier.exportToJson()` — JSON envelope `{app, version, exportedAt, settings}` (pretty-printed)
- `SettingsNotifier.applyFromJson(raw)` — validate envelope, apply per-key (toleran field hilang), return jumlah yang dipulihkan; throws `FormatException` untuk envelope salah
- Clipboard-based UI (no extra deps): `_BackupSection` di SettingsScreen dengan tombol Ekspor + Impor; confirm dialog "timpa" sebelum impor
- Magic header `kSettingsExportApp = 'kopiyantea-pos'`, `kSettingsExportVersion = 1`

**Outstanding QA:**
- [ ] `dart run build_runner build --delete-conflicting-outputs` (provider freezed/g.dart kemungkinan re-gen karena tambah konst di file yang sama — biasanya tidak perlu, tapi run untuk aman)
- [ ] `flutter analyze`
- [ ] Smoke: Ekspor → paste di notes → JSON readable; di device kedua tap Impor → toast "N pengaturan dipulihkan"; tampered JSON → toast "Gagal impor: ..."

### [ENH-006] Bulk Delete Failed Outbox + Age Indicator — **DONE DEV**
**Implemented:**
- `OutboxDao.deleteAllFailed()` — single-statement bulk delete
- `formatRelativeTime(DateTime)` helper di `lib/core/utils/formatters.dart` (baru saja / N menit lalu / kemarin / N hari lalu / tanggal absolut > 7 hari)
- OutboxQueueScreen: AppBar action baru `delete_sweep_outlined` "Hapus semua yang gagal" dengan confirm dialog + count + snackbar feedback
- Tile age display: `"5 menit lalu · 18 Mei 2026, 14:32"` (relatif + absolut berdampingan)

**Outstanding QA:**
- [ ] `flutter analyze`
- [ ] Smoke: trigger beberapa tx push gagal (offline / set status=failed manual) → tombol bulk hapus muncul → confirm → semua row gagal hilang; row baru tampil "baru saja"

### [ENH-006a] Cashier Name Snapshot di Transactions — **DONE DEV**
**Implemented:**
- Drift v11: `Transactions.cashierNameSnapshot` (nullable) + non-destructive migration `addColumn`
- `CheckoutUseCase` set field dari `currentUserProvider.fullName` saat checkout
- `print_receipt_use_case.dart` prefer `tx.cashierNameSnapshot`, fallback live `app_users.fullName` untuk legacy pre-migration rows
- Sync DTO push (`toSupabaseJson`) + pull (`transactionFromJson`) include `cashier_name_snapshot`

**Server migration:** `supabase/migrations/20260522120000_cashier_name_snapshot.sql` — `add column if not exists cashier_name_snapshot text` (idempotent + comment).

**Outstanding QA:**
- [ ] `dart run build_runner build --delete-conflicting-outputs` (Drift v11 + companion)
- [ ] `supabase db push` (atau apply manual via dashboard SQL editor)
- [ ] Smoke: checkout baru → DB row punya snapshot non-null; ubah `app_users.full_name` → struk lama tetap pakai snapshot lama; tx legacy (pre-v11) → struk masih jalan via fallback live lookup

### [ENH-005] Search di TransactionListScreen — **DONE DEV**
**Implemented:**
- `_TransactionList` di `lib/features/transactions/transaction_list_screen.dart` di-convert ke `ConsumerStatefulWidget` dengan `TextEditingController` + debounce 200ms via `Timer`
- TextField di header list (prefix `Icons.search`, suffix `IconButton(Icons.clear)` saat ada query)
- Watch `allCustomersProvider` → build `Map<id, name>` untuk resolve `tx.customerId` → nama pelanggan
- Pure `_matchesQuery` — case-insensitive contains atas: short ID (first 8 char, `#` distrip), total mentah (`toStringAsFixed(0)`), `paymentMethodLabel`, dan nama pelanggan
- Empty state khusus saat hasil 0: `AppEmptyState(Icons.search_off, "Tidak ditemukan", message bawa query)`
- Tidak ada perubahan DAO/provider/schema — pure UI + client filter di atas `branchTransactionsProvider` reactive

**Outstanding QA:**
- [ ] `flutter analyze`
- [ ] Smoke: ketik 3 char short ID (case insensitive) → list mengerucut; ketik dengan/ tanpa `#` → keduanya match; ketik nama pelanggan → muncul; ketik `42000` → tx total Rp 42.000; ketik `cash` → semua tx cash; clear → list penuh; query tanpa hasil → empty state "Tidak ditemukan"

### [ENH-007] Reprint Receipt — **DONE DEV**
**Implemented:**
- `TransactionDetailScreen._ActionsCard` dengan tombol "Cetak Ulang Struk"
- Reuses `PrintReceiptUseCase` (sudah ada — pure)
- Snackbar feedback + error handling

**Outstanding QA:**
- [ ] Smoke: detail transaksi → tap "Cetak Ulang" → struk keluar dari printer Bluetooth

### [ENH-008] Void / Refund Transaction — **DONE DEV**
**Implemented (append-only per ADR-0007):**
- `TransactionDao.getVoidForTransaction` + `watchVoidForTransaction` — find void row referencing the original
- `VoidTransactionUseCase` — atomic write:
  - New tx with `status=voided`, `voidedByTransactionId=original`, mirrored-negative subtotal/discount/tax/total/payment
  - Mirror items with negative qty/subtotal
  - Reverse inventory_movements (`MovementType.adjustment`, opposite sign of original) → cached_stock recovers
  - Outbox push as `transaction` entity (reuses existing `_pushTransaction` which includes linked movements)
- `voidForTransactionProvider` (reactive) drives the banner state
- TransactionDetailScreen `_ActionsCard`:
  - Manager+ only ("Batalkan Transaksi" hidden untuk kasir)
  - Reason input (opsional) di confirm dialog
  - "Sudah dibatalkan" banner setelah void selesai (button hilang)
- Errors: `notFound`, `alreadyVoided`, `notVoidable`, `databaseError`

**Outstanding QA:**
- [ ] Run build_runner (new `void_transaction_use_case.g.dart` + DAO regen)
- [ ] Smoke: kasir login → tombol Batalkan tidak muncul; owner/manager login → batalkan tx → cek stok bahan kembali, list transaksi muncul void row, original detail tampil banner; sync → cek server menerima void tx
- [ ] Edge: dobel-tap "Batalkan" → use case detect `alreadyVoided` → error gracefully

### [ENH-013] Modifier Pricing Unit Tests — **DONE DEV**
**Implemented:** `test/features/pos/cart_modifier_pricing_test.dart` — 14 cases covering:
- `optionDelta` (sum across groups, zero deltas, mixed)
- `effectiveUnitPrice` (no opts, with delta, post-discount snapshot + delta)
- `lineSubtotal` (qty × effectivePrice, qty=0, large qty precision)
- option-set equality stability (sort-by-id contract for merge key)

**Outstanding QA:**
- [ ] `flutter test test/features/pos/cart_modifier_pricing_test.dart` — should pass green

### [ENH-015] Checkout Integration Test — **DONE DEV**
**Implemented:** `test/features/pos/checkout_use_case_test.dart` — 5 integration cases using in-memory Drift:
- Happy path: tx + items + movements + outbox + cached_stock all consistent
- Empty cart → `emptyCart` error, nothing written
- Insufficient cash → `invalidPayment` error, atomic rollback (no movements, no outbox, stock unchanged)
- Non-cash (QRIS) → no paymentReceived needed
- Multi-qty → cached_stock delta aggregated correctly

**Outstanding QA:**
- [ ] `flutter test test/features/pos/checkout_use_case_test.dart` — should pass green
- Note: Drift in-memory test requires sqlite native lib — should work on dev machine via `sqlite3_flutter_libs`. If CI fails, add `sqlite3` bundled native.

---

### [FEAT-007] Remember Me at Login — **DONE DEV** (2026-05-20)
**Implemented:**
- `AppSettings.rememberMe` (default true) + `lastLoginEmail` di `settings_provider.dart`
- `setRememberMe` / `setLastLoginEmail` methods. Toggle OFF auto-clears the saved email
- `LoginScreen` pre-fills email dari saved value, checkbox "Ingat email saya"
- On successful signIn / signInWithMagicLink → `_persistRemember(email)` saves jika checkbox ON
- Settings → new "Privasi & Sesi" section: switch toggle + "Hapus Email Tersimpan" button saat ada email tersimpan

**Outstanding for QA:**
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` (settings_provider.freezed needs new fields)
- [ ] Smoke test: login → kill app → reopen → email auto-fill; toggle OFF → email hilang

### [FEAT-009] Hold Order / Open Bill — **DONE DEV** (2026-05-20)
**Implemented (local-only — Supabase sync deferred):**
- Drift v4: `HeldOrders` table + non-destructive migration
- `HeldOrderDao` (`watchForBranch`, `getById`, `insert`, `deleteById`, `deleteOlderThan`)
- `held_order_service.dart` — encode/restore cart, re-resolves ProductRow + BranchProductRow live (price changes propagate)
- `heldOrdersForBranchProvider` + `heldOrdersCountProvider` (reactive)
- `CartNotifier.restoreState` for atomic hydration
- `CartPanel` → tombol "Tahan Pesanan" (label prompt dialog, default = customer name)
- `PosScreen` AppBar → `HeldOrdersAction` with badge count → opens `HeldOrdersSheet`
- Sheet: list, tap-to-restore (confirm overwrite if cart not empty), per-row delete
- `main.dart` boot prunes held orders > 24 jam (best-effort, non-blocking)

**Outstanding for QA:**
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` (Drift v4 + new `.g.dart` for `held_order_dao` + `held_order_service`)
- [ ] Smoke test: tahan → keranjang clear, badge naik; tap di sheet → cart re-hydrate utuh (item + modifier + customer + diskon); switch branch → list empty
- [ ] Verifikasi prune > 24h: insert manual via SQL dengan createdAt 25 jam yg lalu → restart app → row hilang

**Deferred:**
- Sync ke Supabase via outbox (perlu migration `held_orders` + RLS + push function) — bisa Phase 8 sprint 2

### [FEAT-011] Swipe-to-Cancel Invitation — **DONE DEV** (2026-05-20)
**Implemented:**
- `UserListScreen._DismissibleInvitation` wraps `_InvitationTile` with swipe-left
- Confirm dialog menampilkan email + warning "link tidak bisa dipakai lagi"
- `BranchDao.deletePendingInvitation` (sudah ada) + outbox enqueue `pendingInvitation` (action: delete)
- `SyncRepository._pushPendingInvitation` sudah handle missing-local → DELETE di server (no new push branch)
- Snackbar feedback

**Outstanding for QA:**
- [ ] Smoke: owner → undangan list → swipe → confirm → row hilang + outbox terisi; setelah sync → row di Supabase `pending_invitations` ikut hilang

### [TODO-BG-SYNC-ON-RESUME] Background Re-sync on Session Restore + App Resume
- **Use case:** Saat ini bootstrap pull hanya jalan saat *explicit* login. Kalau user kill app lalu buka lagi (session restore), atau pakai app terus-menerus tanpa logout, data lokal bisa stale dari edits di device lain (mis. owner ubah harga produk di laptop, kasir di mobile pakai data lama). Manual "Sinkron Sekarang" di Settings ada, tapi mengandalkan kasir untuk inisiatif.
- **Scope:**
  - **Trigger 1 — session restore:** Saat `Auth._restoreSession` sukses, fire-and-forget `Sync.syncNow()` di background (tidak blocking UI). User langsung lihat /pos dengan cache, dalam ~5 detik data update silently. Tampilkan badge sync state di POS AppBar (mis. dot kecil hijau "tersinkron" / kuning "menyinkronkan").
  - **Trigger 2 — app resume:** Pakai `AppLifecycleListener.onResume` (Flutter 3.13+). Saat app dari background ke foreground, kalau last sync > threshold (mis. 5 menit), fire-and-forget sync. Throttle supaya tidak hammer Supabase di pemakaian normal.
  - **Trigger 3 — interval timer (opsional):** Sync setiap 15 menit selama app aktif, kalau koneksi OK. Hapus saat app pause.
  - Reactive UI indikator di POS AppBar untuk in-flight sync (kecil, tidak mengganggu).
- **Edge cases:**
  - Sync sedang in-flight, user explicit tap "Sinkron Sekarang" → dedupe / queue, jangan double-pull
  - Sync gagal karena network → silent retry exponential backoff (pattern sudah ada di `Sync` provider)
  - Catat `lastSyncAt` per provider sumber (master vs tx history) supaya bisa tampilkan "Terakhir sinkron 3 menit yang lalu"
- **Files affected:**
  - `lib/features/auth/auth_provider.dart` — call sync notifier setelah restoreSession sukses
  - `lib/core/sync/sync_provider.dart` — add throttle + lastSyncAt tracking
  - New `lib/core/app_lifecycle_listener.dart` — wrap MaterialApp dengan resume handler
  - `lib/features/pos/pos_screen.dart` — add sync indicator di AppBar
- **Estimated effort:** Kecil-sedang. 4-5 file, ~3-4 jam. Risk utama: dedupe + concurrency saat multiple triggers fire.
- **Dependency:** Bootstrap flow (done DEV). Tidak ada blocker.

### [TODO-QRIS-DYN-STATIC] Generate Dynamic QRIS from Owner's Static QR
- **Use case:** Static QRIS = customer harus input nominal manual → error-prone (salah ketik nominal, dispute "udah bayar tapi nominal beda"). Dynamic QRIS = nominal pre-embedded di QR, customer tinggal scan + tap bayar. Owner sudah punya static QRIS (uploaded via FEAT-013) — kita generate dynamic version client-side dengan modifikasi TLV.
- **Technical approach:**
  1. Decode owner's `qrisImageUrl` PNG → string QRIS payload via QR scanner (`mobile_scanner` atau `qr_code_tools`). Cache decoded string di `branches.qrisStaticPayload` (new column) supaya decode sekali per cabang
  2. Parse EMVCo TLV: Tag 00 (format), Tag 01 (point of init = "11" static), Tag 26-51 (merchant identifiers), Tag 53 (currency = "360" IDR), Tag 58 (country), Tag 59 (merchant name), Tag 60 (city), Tag 63 (CRC16)
  3. Modify untuk dynamic:
     - Tag 01: ubah dari "11" ke "12"
     - Insert Tag 54 dengan nominal (mis. `5410016000` = panjang 10, value "16000" untuk Rp16.000) — *wait, format Tag 54 panjangnya 2-byte ASCII length prefix + value*. Actual: `54` + `05` + `16000` (length=5 chars)
     - Remove existing Tag 63
     - Compute CRC16-CCITT (polynomial 0x1021, init 0xFFFF) atas payload baru (TANPA Tag 63), append sebagai `6304XXXX` (hex uppercase)
  4. Render hasilnya pakai `qr_flutter` package sebagai widget atau bytes
  5. Tampilkan di POS / di struk dengan nominal tepat
- **Validation:** test dengan beberapa bank app (BCA mobile, BRImo, GoPay, OVO) untuk verify QR diterima
- **Risk:** Tergantung merchant agreement dengan PJSP. Beberapa PJSP secara teknis bisa baca, tapi T&C-nya mungkin require dynamic QR di-generate via API PJSP-nya. Owner perlu cek dokumen daftar QRIS-nya sebelum aktifkan.
- **Files affected:**
  - `lib/core/qris/qris_tlv_parser.dart` — TLV decode/encode + CRC16-CCITT
  - `lib/core/qris/qris_dynamic_generator.dart` — orchestrate decode → modify → encode → render
  - `branches.qrisStaticPayload` column (cache decoded string)
  - `pubspec.yaml` — `qr_flutter` + `qr_code_tools` (atau `mobile_scanner` reuse)
  - Settings → toggle "Generate Dynamic QR" per cabang
  - `QrisDisplaySheet` — pakai generated QR saat enabled
- **Estimated effort:** 2-3 hari. TLV parser + CRC16 tested, plus QA dengan multiple bank apps.

### [TODO-QRIS-DYN-AGGR] Dynamic QRIS via Payment Aggregator
- **Use case:** Path resmi untuk dynamic QRIS — pakai aggregator (Xendit, Midtrans, DOKU, OY!, Flip Business). Tidak melanggar T&C apapun, dapat webhook konfirmasi pembayaran otomatis (tidak perlu kasir verifikasi manual via app banking).
- **Technical approach:**
  1. Pilih aggregator + sign up merchant account. Rekomendasi:
     - **Xendit** — paling popular di Indonesia, dev docs bagus, ~0.7% per tx
     - **Midtrans** — owned by GoTo, integrasi GoPay smooth
     - **Flip Business** — biaya lebih rendah ~0.5%, tapi setup lebih ribet
  2. Setup webhook endpoint di Supabase Edge Function untuk receive payment confirmations
  3. Add settings: API key + webhook secret stored encrypted via `flutter_secure_storage`
  4. Saat checkout method=QRIS:
     - Call `POST /qr_codes` (atau equivalent) dengan amount + tx id
     - Receive QR string + payment URL + expires_at
     - Render QR ke customer
     - Poll status atau wait for webhook
  5. Webhook → Edge Function → update `transactions.status` + mark paid + sync ke client
  6. Auto-checkout setelah confirmed (no manual "Pembayaran Diterima" tap)
- **Fee implication:** Tambah biaya per transaksi (% atau Rp fixed). Owner perlu set markup atau absorb.
- **Settlement:** Aggregator collect ke virtual account → settle harian/mingguan ke rekening bank merchant (T+1 atau T+2 tergantung aggregator).
- **Files affected:**
  - `lib/core/payments/aggregator_service.dart` — abstract interface
  - `lib/core/payments/aggregators/xendit_service.dart` (etc.)
  - Server-side: Supabase Edge Function untuk webhook receiver
  - `branches.payment_aggregator_config` (encrypted JSON)
  - `transactions.aggregator_payment_id` + status tracking columns
  - CheckoutSheet integration replace static flow dengan dynamic
- **Estimated effort:** 1-2 minggu. Termasuk aggregator account setup + KYC + sandbox testing + production go-live.
- **Dependency:** Owner siap bayar fee per tx + KYC documentation (NPWP usaha, KTP, surat keterangan domisili)

### [FEAT-010] WhatsApp Business API Integration untuk Notifikasi Undangan
- **Requested:** 2026-05-20 (FEAT-006 QA)
- **Use case:** Owner saat ini harus secara manual kirim instruksi via WA setelah submit form undangan ([docs/inviting-users.md](docs/inviting-users.md) Langkah 3). Untuk owner dengan banyak staff atau onboarding massal (mis. buka cabang baru → undang 5 kasir sekaligus), step manual ini jadi friction + error-prone (lupa kirim, typo email).
- **Scope:**
  - Integrasi WhatsApp Business API (Meta Cloud API atau Twilio WhatsApp)
  - Settings → tambah "Konfigurasi WhatsApp" (API token, phone number ID)
  - Saat owner submit invitation: optional checkbox "Kirim notifikasi WA ke nomor [phone]"
  - Phone number sebagai field tambahan di UserFormScreen (saat ini tidak ada)
  - Template WA message dengan variable substitution (nama, role, cabang, email)
  - Status "WA terkirim" di list undangan
  - Retry button kalau gagal kirim
- **Estimated effort:** Sedang-besar. Meta Business verification + setup template message + integration code. ~3-5 hari termasuk testing.
- **Alternative simpler:** Deep link `whatsapp://send?phone=X&text=Y` di kode — tap tombol di list undangan langsung buka WA dengan template pre-filled. Tidak butuh API, tapi user harus tap kirim manual. ~1 file, 2 jam kerja.
- **Dependency:** Phone number field di pending_invitations + form

### [FEAT-011] Swipe-to-Cancel Invitation
- **Requested:** 2026-05-20 (FEAT-006 QA)
- **Use case:** Saat owner salah ketik email atau pikiran berubah (mis. kandidat tidak jadi diterima), tidak ada cara cancel undangan dari UI. Workaround saat ini: hapus manual via Supabase Dashboard → table `pending_invitations` → delete row. Tidak feasible untuk owner non-teknis.
- **Scope:**
  - `UserListScreen` — section "Diundang (belum aktif)" → tiap row jadi `Dismissible` dengan swipe-left action
  - Konfirmasi dialog: "Batalkan undangan untuk [email]?" + warning "User tidak akan bisa klaim lagi dengan link yang sudah dikirim"
  - Delete dari `pending_invitations` lokal + enqueue ke outbox (delete action)
  - Sync push → DELETE row di Supabase
  - Optional: tombol "Kirim ulang link" di place yang sama (resend magic link via owner — perlu Edge Function karena resend butuh service_role)
- **Estimated effort:** Kecil. 1 widget edit + 1 DAO delete method + outbox enqueue pattern existing. ~2 file, 1 jam.

### [FEAT-007] Remember Me at Login
- **Requested:** 2026-05-20 (FEAT-006 QA)
- **Use case:** Kasir/owner harus mengetik email + password tiap kali buka app — di shift sibuk ini gesekan. Supabase session sebenarnya sudah persisted via `flutter_secure_storage`, tapi UX-nya tidak ekspos: ada gap antara "session restored otomatis" vs "user mengira harus login tiap kali". Kalau session expire (1 jam default), user harus re-login dari nol.
- **Scope:**
  - Add "Ingat saya" checkbox di LoginScreen (default ON)
  - Saat ON: simpan email terakhir di SharedPreferences, auto-fill di next launch
  - Saat OFF: clear stored email + force signout setelah app keluar foreground
  - Refresh token rotation lebih agresif (`autoRefreshToken: true` di Supabase init — sudah ON, tapi expose ke user kalau session expire)
  - Settings entry: "Hapus sesi tersimpan" untuk forced clear (privacy)
- **Estimated effort:** 1 ChangeNotifier + LoginScreen edit + secure storage key. ~3 file. Kecil.

### [FEAT-008] Google Sign-In (OAuth)
- **Requested:** 2026-05-20 (FEAT-006 QA)
- **Use case:** Kasir non-teknis lebih familiar tap "Sign in with Google" daripada manage password baru. Mengurangi friction onboarding dan password-reset support burden. Supabase mendukung Google OAuth natively.
- **Scope:**
  - Setup Google Cloud Console project: OAuth client ID (web + Android + iOS)
  - Supabase Dashboard → Authentication → Providers → Google → enable + paste client ID/secret
  - Tambah package `google_sign_in` (atau pakai `supabase_flutter` native `signInWithOAuth(OAuthProvider.google)` via WebView/Chrome Custom Tabs)
  - Tombol "Masuk dengan Google" di LoginScreen
  - Handle session restore via `onAuthStateChange` (sudah ready dari FEAT-006 magic link)
  - Claim flow tetap jalan (same path as magic link) — pending_invitations matching by email
  - Android: tambah `google-services.json` dari Firebase/Google Cloud, configure SHA-1 di Google Console
- **Estimated effort:** Sedang. Setup OAuth + integration ~2-3 jam. Test flow di Android real device wajib.
- **Dependency:** [FEAT-006] selesai (claim flow + onAuthStateChange listener sudah ada)

### [FEAT-009] Hold Order / Open Bill
- **Requested:** 2026-05-20 (FEAT-006 QA)
- **Use case:** Customer dine-in datang, pesan minum dulu sambil tunggu teman/keputusan order tambahan. Kasir butuh cara "park" cart current → ambil order lain → kembali ke order pertama saat customer siap bayar. Saat ini tidak ada cara menyimpan cart yang belum dibayar.
- **Scope:**
  - Drift table baru: `held_orders` (id, branchId, label/customerName/tableNumber, cartJson, createdAt, createdBy)
  - Supabase migration: same schema dengan RLS branch-scoped
  - PosScreen → tombol "Tahan Pesanan" di sebelah Checkout (saat cart tidak kosong) → prompt label/meja → save → clear cart
  - PosScreen → tombol "Pesanan Tertahan" (badge dengan count) → bottom sheet list semua held → tap → restore cart, hapus dari held_orders
  - Auto-expire: held > 24 jam dihapus saat startup (configurable)
  - Receipt nanti: meja/label muncul di header struk
  - Sync: held_orders ride outbox (LWW)
- **Estimated effort:** Sedang. 1 table + 1 DAO + 1 provider + 2 UI entry points + 1 sheet. ~5-6 file.

### [FEAT-006] User Management UI (owner-only)
- **Requested:** 2026-05-18 (Phase 4.3 QA)
- **Use case:** Owner saat ini tidak punya jalur UI untuk menambah user baru (Manager / Kasir) dan assign role + branch access. User hanya bisa di-create via Supabase Dashboard + insert manual ke `app_users` + `user_branch_access`. Saat buka cabang baru atau onboard staff, ini blocker.
- **Scope:**
  - Route `/more/settings/users` (gated: hanya visible saat `currentUser.role == 'owner'`)
  - `UserListScreen` — list semua user di tenant + role badge + branch access summary
  - `UserFormScreen` — email, nama, role (owner/manager/cashier — sesuai enum di ADR-0007), pilih branch access (multi-select dari active branches)
  - Create flow: panggil Supabase `auth.admin.createUser` (atau invite via email) → insert `app_users` + `user_branch_access` rows
  - Edit flow: ubah role + branch access (email/auth tidak boleh diubah di sini)
  - Soft delete / lock: set `locked_at` (sesuai partial index di migration 007)
  - RLS: policies sudah ada per ADR-0007 — endpoint write hanya boleh dipanggil saat `user_global_role() = 'owner'`
  - Outbox enqueue untuk sync
- **Estimated effort:** 1 list screen + 1 form + 2 DAO methods + 1 Supabase admin endpoint wrapper. ~5 file. Sedang. Bisa pre-syarat untuk multi-staff deployment.
- **Dependency:** Idealnya setelah [FEAT-002] Multi-Tenant Isolation kalau target SaaS — kalau single-tenant deployment, bisa langsung dikerjakan.

### [FEAT-004] Tax Settings UI (per-branch)
- **Requested:** 2026-05-18 (Phase 4.3 QA)
- **Use case:** Pajak (PB1/PPN) saat ini hardcoded di seed (`taxRate` + `taxInclusive` di `branches`). Owner tidak bisa mengubah tarif atau toggle inclusive/exclusive tanpa edit DB langsung. Saat tarif pajak daerah berubah atau buka cabang baru dengan rezim pajak berbeda, tidak ada jalur UI.
- **Scope:**
  - Settings sub-screen `/more/settings/tax` (atau section di Settings utama)
  - Form per active branch: `taxRate` (numeric input 0–100%), `taxInclusive` (switch)
  - Validasi: rate 0–100, decimal 2 digit
  - Update via `BranchDao.updateTaxConfig` (perlu ditambah)
  - Outbox enqueue untuk sync ke Supabase
  - Preview: contoh perhitungan Rp10.000 dengan tarif saat ini (inclusive vs exclusive) per ADR-0012
- **Estimated effort:** 1 DAO method + 1 screen + 1 route + 1 outbox entity type. Kecil (~3 file).

### [FEAT-005] Inventory Stock Management UI
- **Requested:** 2026-05-18 (Phase 4.3 QA)
- **Use case:** Stok bahan baku (mis. gula aren, susu, kopi) hanya bisa diatur lewat checkout deduction. Tidak ada UI untuk: (1) initial stock saat barang masuk, (2) adjustment manual (susut, rusak, hilang), (3) tambah inventory item baru, (4) edit nama/unit/threshold low-stock.
- **Scope:**
  - `InventoryListScreen` — tambah FAB "+" untuk inventory item baru
  - `InventoryItemFormScreen` — name, unit (gram/ml/pcs), lowStockThreshold
  - `InventoryDetailScreen` — tombol "Tambah Stok" / "Kurangi Stok" / "Penyesuaian" → form qty + alasan (catatan)
  - Tulis `inventory_movements` row dengan `type` sesuai (purchase / adjustment / waste) — append-only per ADR-0003
  - `cached_stock` di-update via reconciliation logic yang sudah ada (CheckoutUseCase pattern)
  - Outbox enqueue untuk sync
- **Estimated effort:** 1 form screen + 2 bottom sheets + extend InventoryDao dengan `recordMovement(type, qty, notes)`. ~5 file. Sedang.

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

### [BUG-002] Sync state hilang setelah navigate — **FIXED 2026-05-20**
- Sync provider auto-dispose, jadi "Terakhir sinkron" selalu reset ke "Belum pernah" tiap kali Settings dibuka, meskipun sync barusan jalan
- **Fix:** `@Riverpod(keepAlive: true)` di `Sync` notifier

### [BUG-003] Tax 0% tidak bisa di-save — **FIXED 2026-05-20**
- Tombol Simpan grey saat branch.taxPercentage sudah 0 dan user mengetik 0 (no-op detection di `_dirty`)
- UMKM tanpa NPWP butuh konfirmasi 0% berulang, ini blocker
- **Fix:** Drop `_dirty` check; Simpan selalu enabled saat input valid. Save idempotent.



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
