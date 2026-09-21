# KopiyanteaPOS --- System Context

> Dokumen System Context (C4 Level 1) untuk aplikasi KopiyanteaPOS.
> Disusun dari README.md, PROJECT_STATUS.md, PROJECT_MEMORY.md, ADR-0001 s/d ADR-0014, dan MASTER_PROMPT_v5.md.
>
> Tujuan: memberikan satu sumber kebenaran tentang **siapa** yang menggunakan sistem, **apa** yang dilakukan sistem, **sistem eksternal** apa yang berinteraksi, dan **kendala/aturan** yang harus dihormati ketika merambah atau meng-integrasikan aplikasi.

---

## 1. Ringkasan Eksekutif

KopiyanteaPOS adalah aplikasi **mobile Point-of-Sale (POS) offline-first** berbasis Flutter yang dirancang untuk rantai coffee shop Indonesia. Aplikasi mengombinasikan:

- **Local-first reliability**: setiap transaksi tulis-baca berjalan dari SQLite lokal (Drift) sehingga kasir tidak pernah terganggu oleh masalah jaringan.
- **Sync ke cloud**: perubahan dimasukkan ke outbox dan dikirim ke Supabase secara opportunistik, dengan rollback/void flow audit-friendly.
- **Manajemen operasional multi-cabang**: katalog global + override per cabang, inventori event-sourced, pelanggan, laporan, tutup kas, dan manajemen pengguna.
- **Integrasi hardware**: printer thermal Bluetooth (ESC/POS) untuk cetak struk dan (di-backlog) scanner mobile.
- **Roadmap SaaS multi-tenant**: skema saat ini single-tenant, dengan migrasi bertahap ke model organizations + organization_members + subscription_plans (lihat ADR-0014).

Status per Juni 2026: aktif dikembangkan. Sebagian besar fitur MVP POS sudah **DONE QA**; pengerjaan bergeser ke i18n penuh (English default), hardening, dan migrasi multi-tenant SaaS.

---

## 2. System Overview (C4 Level 1)

```
+-------------------------------------------------------------------------+
|                          SYSTEM UNDER DESIGN                            |
|                                                                         |
|   +-----------------------------+      +-----------------------------+  |
|   |  KopiyanteaPOS Mobile App   | <--->|     Supabase Project        |  |
|   |  (Flutter, iOS & Android)   |      |   (Postgres + Auth + RLS    |  |
|   |                             |      |    + Storage + Edge Fn)     |  |
|   |  - Local Drift DB           |      |                             |  |
|   |  - Outbox sync              |      |  - Schema (migrations)      |  |
|   |  - Riverpod state           |      |  - RLS policies             |  |
|   |  - go_router shell          |      |  - Storage buckets          |  |
|   |  - Bluetooth ESC/POS        |      |  - Auth (email/magic/OAuth) |  |
|   +--------------+--------------+      +---------------+-------------+  |
|                  |                                     |                |
+------------------|-------------------------------------|----------------+
                   |                                     |
                   v                                     v
       +-----------------------+             +------------------------+
       |  Bluetooth Thermal    |             |   GitHub Actions CI    |
       |  Printer (per device) |             |   (build/test/backup)  |
       +-----------------------+             +------------------------+
                                                          |
                                                          v
                                            +-------------------------+
                                            |  Google Drive (backup)  |
                                            |  via rclone             |
                                            +-------------------------+
```

Sistem utama yang sedang dirancang adalah **KopiyanteaPOS Mobile App**; Supabase, printer, dan CI/CD adalah sistem eksternal yang dipakai bersama.

---

## 3. Actors

### 3.1 Primary Actors

| Actor | Deskripsi | Akses | Tujuan utama |
|---|---|---|---|
| **Owner** | Pemilik usaha/pengelola chain | Semua cabang, semua modul, manajemen user & subscription, settings global | Kelola master data, pantau performa, atur pengguna, kelola struk global & subscription |
| **Manager** | Manajer cabang | Cabang yang di-assign, laporan, tutup kas, operasional | Monitor penjualan, tutup kas, lihat laporan cabang, kelola staff di scope |
| **Cashier (Kasir)** | Operator depan meja | POS, cart, checkout, printer, hold order, input transaksi | Catat transaksi secepat mungkin (offline-first) |
| **Customer (Pelanggan)** | Bukan pengguna aplikasi, tapi data entity | Tercatat lewat fitur Customers, loyalty points, transaksi | Mendapat struk, kumpulkan poin (jika program loyalitas aktif) |

### 3.2 Secondary Actors

| Actor | Deskripsi |
|---|---|
| **Google OAuth Provider** | Login Google (jika diaktifkan) untuk user owner/manager/cashier |
| **Bluetooth Thermal Printer** | Hardware peripheral di setiap device kasir (ESC/POS) |
| **CI Operator / Release Manager** | Men-trigger tag SemVer dan memantau workflow GitHub Actions |

### 3.3 Out of Scope

- Konsumen akhir yang memesan via mobile/web; KopiyanteaPOS tidak memiliki customer-facing app.
- Integrasi dengan marketplace (GoFood, GrabFood, ShopeeFood).
- Payment gateway otomatis --- pembayaran QRIS memakai QR statis yang di-upload owner.

---

## 4. External Systems & Integrations

| Sistem | Arah | Tujuan | Kontrak |
|---|---|---|---|
| **Supabase Postgres** | Bidirectional | Single source of truth server-side, RLS-enforced reads/writes | SQL migrations non-destruktif (ADR-0008), DDL mirror Drift |
| **Supabase Auth** | App --> Supabase | Login email/password, magic link, Google OAuth | Email-based identity, auth.users mirror ke app_users lokal |
| **Supabase Storage** | App --> Supabase | Bucket product-images, qris-images, receipt-logos | Public read via URL, owner-write via RLS |
| **Bluetooth Thermal Printer** | App --> Device | Cetak struk ESC/POS 58mm/80mm | Pakai print_bluetooth_thermal + esc_pos_utils_plus |
| **GitHub Actions** | Repo --> CI | Build APK/AAB/IPA, backup Supabase harian, keep-alive ping | SemVer tag --> release, schedule cron untuk backup |
| **Google Drive** | CI --> Cloud | Backup harian database SQL + storage archive | rclone dengan token base64, retensi 30 hari |
| **Google Play Integrity / Apple App Attest** | (Backlog) | Verifikasi device integrity untuk anti-tamper | Hanya untuk operasi sensitif (saat ini deferred, ADR-0010) |
| **Mobile Scanner** | (Backlog) | Scan barcode/kode produk | mobile_scanner, belum dipakai untuk menu coffee |

---

## 5. Core Capabilities (Fungsional)

Capabilities berikut adalah yang sudah ada atau menjadi target MVP + backlog. Setiap kapabilitas dirujuk ke fase implementation di PROJECT_STATUS.md.

### 5.1 Point of Sale (POS)

- **Menu grid responsif** dengan pencarian, filter rekomendasi, dan view mode grid/list.
- **Cart panel** dengan qty controls, modifier picker, manual discount, customer attach, item notes, hold order, clear cart, dan undo delete item.
- **Checkout sheet** multi-payment: cash (dengan kalkulator quick amount + kembalian), QRIS statis (modal QR + tombol Pembayaran Diterima), transfer bank (pilih rekening tujuan).
- **Receipt summary** dengan aksi cetak/share (PNG) dan tombol Transaksi Baru.
- **Receipt printer** ESC/POS 58/80mm, support logo global owner, header/footer, QRIS image, paper width toggle.
- **Held orders**: tunda pesanan, restore dengan replace-cart dialog, hapus dengan konfirmasi.
- **Live tax preview** per cabang (PB1), inclusive vs exclusive.
- **Discount system dua-level**: branch override price + discount % dengan valid until (ADR-0009, ADR-0011).
- **Modifier system**: option groups, single/multi select, required validation, default seeding, harga delta (FEAT-001).
- **Tutup Kas / Shift Closing**: saldo awal, expected cash, hitungan fisik, variance (pas/kurang/lebih), riwayat 30 closing (ENH-001).
- **Quick "Hari Ini" badge** di POS AppBar & Home (transaksi + revenue hari ini, auto-reset tengah malam) (ENH-002).

### 5.2 Catalog & Master Data

- **Produk global + branch junction**: produk didefinisikan sekali, dioverride per cabang (nama, harga, diskon, availability).
- **Kategori produk** dengan warna, urutan, toggle aktif.
- **Modifier groups & options** dengan binding ke produk任凭.
- **Recipe editor** bahan baku (untuk pengurangan stok otomatis saat checkout).
- **CSV import/export** produk (MVP, belum termasuk override/recipe/option/image).
- **Image picker + crop + upload** untuk foto produk (FEAT-012) dengan kompresi 1024px JPEG.
- **Static QRIS per cabang** upload + preview (FEAT-013).

### 5.3 Inventory

- **Stok per cabang** dengan cached stock + event-sourced inventory movement.
- **Status badge** color-blind safe: Cukup / Menipis / Habis dengan icon + label (bukan warna saja).
- **Movement types**: Pembelian, Penyesuaian, Limbah (waste), otomatis turun saat checkout (recipe-driven deduction).
- **Inventory reconciliation** server-side trigger (matching dengan client-side cached_stock).

### 5.4 Customers

- **Customer list** dengan search (nama/phone), avatar inisial, loyalty points badge.
- **Customer form** dengan validasi email regex + phone uniqueness, partial update.
- **Customer picker** dari cart (POS) untuk attach transaksi ke pelanggan.
- **Loyalty points** otomatis dari total transaksi (saat ini manual accumulation, points tercetak di struk).

### 5.5 Transactions

- **Transaction list** dengan date grouping (Hari Ini / Kemarin / tanggal absolut), search, status badge.
- **Transaction detail** dengan header/items/totals/payment/customer cards, status badge, modifier snapshots, item notes.
- **Void flow** dengan dialog konfirmasi (append-only --- tidak delete, melainkan tulis void row + compensating ledger).
- **Share struk sebagai PNG** dengan renderer internal.
- **Print receipt** lewat PrintReceiptUseCase --> BluetoothPrinterService.

### 5.6 Reports

- **Date preset**: Hari Ini, Kemarin, 7 Hari, 30 Hari, custom range.
- **Pendapatan**: revenue, jumlah transaksi, AOV.
- **Metode Pembayaran**: breakdown per metode (cash, QRIS, transfer) dengan proporsi bar.
- **Transfer per Rekening**: breakdown snapshot rekening (FEAT-015).
- **Produk Terlaris**: top 5 dengan rank avatar.
- **Share laporan sebagai PNG** dengan renderer.

### 5.7 Settings

- **Cabang** (branch picker, override default), **tampilan** (theme system/light/dark, bahasa), **perangkat** (printer, scanner), **pajak** (per-cabang tax %), **QRIS statis**, **tampilan struk** (header/footer/logo/paper), **menu image** (template share), **rekening bank**, **pengguna** (user management + invitation), **antrian sinkronisasi** (outbox queue), **telemetry** (db size, row counts, sync status), **backup/import/export** (settings JSON), **tentang aplikasi**, **akun & keluar**.
- **Owner-only tiles**: Subscription, Struk Global, Manajemen User, Tutup Kas, Telemetry, Antrian, Rekening Bank, Pajak, QRIS, dll.
- **Language switcher**: English (default) & Indonesia, preferensi tersimpan lokal + ikut backup settings.

### 5.8 User Management & Auth

- **Login**: email/password, magic link, Google OAuth (FEAT-008).
- **Roles**: Owner, Manager, Cashier (GlobalRole enum, soon to be organization-scoped per ADR-0014).
- **Pending invitations**: invite-only claim flow; user yang diundang sign-up dengan email yang sama, otomatis diklaim saat sign-in pertama.
- **Bootstrap flow**: setelah login, blocking screen menarik auth context --> master data --> transaction history sebelum masuk POS.
- **Session restore**: cold-start dengan secure storage langsung ke /pos (default bootstrap = complete).

### 5.9 Sync & Offline

- **Outbox pattern**: setiap mutasi lokal (transaction, customer, inventory movement, product, branch, settings) di-enqueue ke outbox.
- **Push outbox** dengan exponential backoff 1s/5s/30s/5m/30m.
- **Pull**: master data per branch, transactions 100 terakhir, user & branch access.
- **Background sync** via workmanager (periodic best-effort).
- **Outbox queue UI**: list grouped by status (gagal/menunggu/selesai) dengan retry per row, retry-all, delete with warning.

### 5.10 Operational (CI/CD, Backup, Observability)

- **Release automation**: tag SemVer --> signed APK + AAB via GitHub Actions (keystore upload-keystore.jks di repo root, gitignored).
- **iOS IPA build** dengan modular headers fix untuk SQLite (workflow iOS).
- **Daily Supabase backup**: pg_dump (.sql.gz) + storage archive (.tar.gz) + SHA-256 checksum + manifest, retensi 30 hari di Google Drive.
- **Supabase keep-alive ping** agar free-tier project tidak pause.
- **Telemetry screen**: app version, db size, row counts, outbox counters, last sync timestamp.

---

## 6. Quality Attributes (Non-Fungsional)

| Atribut | Target | Bagaimana caranya |
|---|---|---|
| **Reliability / Offline-first** | Transaksi kasir harus berjalan tanpa internet | Drift SQLite lokal, outbox, idempotency key UUID v7 |
| **Auditability** | Tidak boleh delete data finansial | Append-only transactions, void = compensating rows, snapshot immutable di receipt/report |
| **Performance** | Responsif di mid-range Android | Drift watch() reactive, Riverpod autoDispose, lazy load, tidak ada N+1 |
| **Security** | RLS deny-by-default; cert pinning di prod; secure storage | ADR-0007 (RLS matrix), ADR-0010 (cert + integrity), flutter_secure_storage |
| **Type Safety** | Compile-time safety end-to-end | Freezed untuk semua model, Drift, typed go_router, hand-written DTOs Supabase matching DDL |
| **Accessibility** | Color-blind safe; touch target 44dp min | ADR-0013 design tokens, status selalu icon + label, AppTouchTarget |
| **i18n** | English (default) + Indonesia, ARB-only strings | flutter gen-l10n, default English per app_en.arb template, migrasi bertahap dari hardcoded id_ID |
| **Maintainability** | ADRs, PROJECT_MEMORY, PROJECT_STATUS, clean code | ADRs 0001-0014, workflow TODO-->IN PROGRESS-->DONE DEV-->DONE QA, fungsi <= 30 baris |
| **Resilience** | Sync gagal --> backoff + outbox queue | Exponential backoff, manual retry, idempotent push via UUID v7 ON CONFLICT |
| **Reversibility** | Tidak ada DROP destruktif | ADR-0008 expand-then-contract, setiap migration butuh ADR |
| **Observability** | Production-grade logging | AppLogger production-gated (warning+ prod, debug+ dev), global error handlers |

---

## 7. Technical Architecture Snapshot

### 7.1 Tech Stack

| Layer | Teknologi |
|---|---|
| App framework | Flutter (SDK >=3.32.0), Dart >=3.4.0 dengan Records & sealed classes |
| State management | Riverpod 2.5.x + riverpod_annotation 2.3.x (codegen) |
| Routing | go_router 14.x dengan StatefulShellRoute.indexedStack |
| Local DB | Drift 2.20.x + sqlite3_flutter_libs + path_provider |
| Models | Freezed 2.5.x + json_serializable 6.8.x |
| Backend | Supabase Flutter 2.5.x (Postgres, Auth, Storage) |
| Config | envied 0.5.x dengan fail-fast Env.validate() |
| Hardware | print_bluetooth_thermal, esc_pos_utils_plus, permission_handler, mobile_scanner |
| Background | workmanager 0.9.x (Android primary, iOS best-effort) |
| UI | lucide_icons_flutter, cupertino_icons, design tokens custom |
| Utils | uuid (v7), intl 0.20.x, logger, package_info_plus, share_plus |
| Networking | dio + http + http_certificate_pinning + crypto (SHA-256 fingerprint match) |
| CI/CD | GitHub Actions (release, iOS IPA, supabase-ping, supabase-backup) |

### 7.2 Lapisan Aplikasi

```
+--------------------------------------------------+
|  Presentation (features/*)                       |
|  - POS, Catalog, Inventory, Transactions, ...    |
|  - go_router shell + AdaptiveShell (mobile/tablet)|
+--------------------------------------------------+
|  State (Riverpod providers, notifiers)           |
|  - AsyncValue.when for every async flow          |
|  - autoDispose + family, keepAlive untuk session |
+--------------------------------------------------+
|  Domain (core/database, core/sync, core/utils)   |
|  - Drift DAOs, SyncRepository, pricing, intents  |
+--------------------------------------------------+
|  Infrastructure (core/network, core/storage)     |
|  - Supabase client, secure storage,               |
|    pinned HTTP client, image upload service,     |
|    service_providers (printer/scanner/integrity)|
+--------------------------------------------------+
|  Data                                            |
|  - Local: Drift SQLite (single-tenant)          |
|  - Remote: Supabase Postgres + Storage (RLS)     |
+--------------------------------------------------+
```

### 7.3 Key Architectural Decisions (ADRs)

- **ADR-0001**: UUID v7 untuk client-side IDs (sortable, time-ordered, idempotency key).
- **ADR-0002**: Drift untuk local DB (typed SQL, reactive streams, codegen).
- **ADR-0003**: Event-sourced inventory movements (append-only, reconciliation trigger).
- **ADR-0004**: Outbox pattern untuk offline sync.
- **ADR-0005**: Freezed untuk semua model (immutability, copyWith, sealed unions).
- **ADR-0006**: Global products + branch junction (master data + override per cabang).
- **ADR-0007**: RLS policy matrix (deny-by-default, branch-scoped reads, append-only tx).
- **ADR-0008**: Non-destructive migration policy (expand-then-contract, ADR wajib untuk destructive).
- **ADR-0009**: Two-level discount system (branch override + discount % dengan validUntil).
- **ADR-0010**: Cert pinning + Play Integrity (prod pinned, dev fallback).
- **ADR-0011**: Discount dari price override (bukan field terpisah).
- **ADR-0012**: Tax per-branch dengan inclusive flag.
- **ADR-0013**: Design tokens + Inter font (Teal/Amber palette, color-blind safe).
- **ADR-0014**: Multi-tenant SaaS architecture (organizations + members + subscription; migrasi bertahap).

---

## 8. Data Flow Overview

### 8.1 Transaksi Checkout (Happy Path)

```
[Kasir] -> tap "Bayar" di CartPanel
        -> CheckoutSheet (pilih metode, qris, transfer account, cash received)
        -> CheckoutUseCase (atomic db.transaction di Drift)
              - write Transactions row
              - write TransactionItems rows + TransactionItemOptions snapshots
              - write InventoryMovements rows (recipe-driven deduction)
              - enqueue Outbox rows (entity = transaction)
        -> ReceiptSummarySheet -> PrintReceiptUseCase (Bluetooth ESC/POS)
        -> SyncRepository.pushOutbox() (drain outbox ke Supabase)
              - POST transactions + items + options + movements (idempotent via UUID v7)
        -> Outbox: status = done
```

### 8.2 Login & Bootstrap

```
[User] -> LoginScreen (email/password | magic link | Google)
       -> AuthRepository.signIn()
              - Supabase signInWithPassword / signInWithIdToken
              - resolve session -> app_users lookup di Drift
              - if email matches pending_invitations -> claim (insert app_users + user_branch_access)
              - markPending() -> run() BootstrapProvider
       -> BootstrapScreen (blocking)
              step 1: pullMyAuthContext (user + branch access)
              step 2: pullMasterData (products, branch_products, recipes, customers, bank accounts, settings)
              step 3: pullTransactions (100 terakhir)
       -> redirect to /pos (POSScreen dengan data fresh)
```

### 8.3 Sinkronisasi Background

```
[workmanager periodic task] -> SyncRepository.pushOutbox()
                              -> SyncRepository.pullTransactions(branchIds, limit=100)
                            (best-effort, network-constrained)
[Settings > Sinkron Sekarang] -> SyncRepository.syncNow() (manual trigger)
```

---

## 9. Deployment & Operational Topology

### 9.1 Build Artifacts

- **Android**: signed APK per ABI + AAB (upload keystore di repo root, build.gradle.kts Kotlin DSL signingConfig + R8/ProGuard rules).
- **iOS**: IPA build (modular headers fix di Podfile untuk sqlite3_flutter_libs).
- **Release tag**: SemVer tag (vMAJOR.MINOR.PATCH) -> GitHub Actions release workflow.

### 9.2 CI/CD Workflows

| Workflow | Trigger | Fungsi |
|---|---|---|
| release.yml | Push SemVer tag | Build signed APK + AAB, upload artifact release |
| iOS-ipa.yml | Manual / tag | Build iOS IPA dengan modular headers untuk SQLite |
| supabase-ping.yml | Schedule | Ping Supabase agar free-tier project tidak pause |
| supabase-backup.yml | Schedule (daily) | pg_dump (.sql.gz) + storage archive (.tar.gz) + checksum + manifest --> Google Drive (rclone), retensi 30 hari |

### 9.3 Environments

| Environment | APP_ENV | Supabase Project | Catatan |
|---|---|---|---|
| Development | development | Local/Staging dev | Cert pinning opsional |
| Staging | staging | Staging Supabase (terpisah) | Untuk eksperimen multi-tenant (free-tier tidak punya branching) |
| Production | production | Production Supabase | Cert pinning WAJIB (SHA-256 fingerprints) |

.env files yang ada: .env, .env.dev, .env.stg, .env.example. Env dibaca via envied dan divalidasi saat startup.

### 9.4 Backup & DR

- Database backup harian via pg_dump (plain, no-owner, no-privileges) + .gz.
- Storage archive harian via S3-compatible Supabase Storage API untuk bucket product-images, qris-images, receipt-logos.
- SHA-256 checksum file + manifest JSON (timestamp, daftar bucket, jumlah file, ukuran per bucket).
- Google Drive: gdrive:kopiyantea-pos/supabase-backups/{database,storage,manifests} retensi 30 hari.
- Secrets di GitHub Actions: RCLONE_CONFIG_BASE64, SUPABASE_DB_*, SUPABASE_S3_*.

---

## 10. Constraints & Assumptions

### 10.1 Engineering Constraints (Non-Negotiable, dari MASTER_PROMPT_v5)

- **SOLID**, Database-as-Code, Non-Destructive Migrations, End-to-End Type Safety.
- **Strict RLS**, Environment Variable Validation, Documentation as Code.
- **Clean Code** (fungsi <= 30 baris, nama bermakna, no magic numbers).
- **State Feedback & Submission Prevention** (setiap async = loading/success/error, submit button disabled saat loading, idempotency via UUID v7).
- **Data Fetching Optimization** (local-first reads, no N+1, no SELECT *).
- **Internationalization** (semua string via ARB, default English).
- **First-Party Anti-Bot** (rate limiting Supabase, lockout 5x attempt, integritas device).

### 10.2 Business / Domain Constraints

- **Single currency**: Rupiah, format Rp 25.000.
- **Date locale**: default Indonesia (saat ini locale-aware via intl).
- **No DELETE on financial records**: append-only, void = compensating.
- **Multi-cabang** diasumsikan dalam satu negara (timezone sama, mata uang sama).
- **Owner** diasumsikan non-teknis: UI harus jelas, settings import/export harus robust.

### 10.3 Technical Assumptions

- Device target: Android 5+ (minSdk 21) & iOS modern.
- Hardware printer: ESC/POS-compatible Bluetooth thermal, 58mm atau 80mm.
- Jaringan: sering tidak stabil di lantai produksi -> offline-first adalah wajib, bukan nice-to-have.
- Free-tier Supabase: tidak mendukung database branching -> gunakan project staging terpisah untuk eksperimen schema.
- Drift analyzer constraint: pinned ke 2.20.x sampai coordinated upgrade codegen (lihat TD-001).

### 10.4 Out-of-Scope (Sekarang)

- Payment gateway otomatis / dynamic QRIS.
- Mobile scanner (barcode).
- Customer-facing app.
- Marketplace integration.
- Dynamic pricing / promo engine.
- Multi-currency.

---

## 11. Roadmap Snapshot

| Phase | Status | Ringkasan |
|---|---|---|
| 0 --- Foundation Docs | DONE QA | 13 ADR tertulis, README skeleton, .env.example lengkap |
| 1 --- Init, Env, i18n, Tokens | DONE QA | Flutter boot, env validation, design tokens, component primitives, ARB id_ID + en_US |
| 2 --- Data Layer & Hardware Interfaces | DONE QA | Drift schema 13 tabel, DAOs, pricing, abstract PrinterService/ScannerService/IntegrityService |
| 3 --- Responsive Navigation | DONE QA | AdaptiveShell (BottomNav <-> NavigationRail), StatefulShellRoute |
| 4 --- UI Construction | DONE QA | Catalog, Seed, POS, Inventory+Transactions, Customers+Reports, dark mode + color-blind audit |
| 5 --- Hardware Integration | IN PROGRESS | Bluetooth Printer DONE DEV (5a), Mobile Scanner TODO (5b), Play Integrity TODO (5c) |
| 6 --- Supabase Sync & Security | IN PROGRESS | 10 migrations DONE QA, env/secure storage DONE, auth DONE, cert pinning DONE DEV, sync MVP DONE DEV, background workmanager DONE DEV |
| 7 --- Optimization & Release | DONE DEV | AppLogger production-gated, ProGuard rules, release doc, AAB build sukses |
| 8 --- Feature Backlog Sprint 1 | DONE DEV | Tax UI, Inventory Stock UI, User Management, Modifier System |
| Post-Phase 8 (Incremental) | IN PROGRESS | Tutup Kas, Quick Today badge, Undo snackbar, Google Sign-In, CSV import/export, Telemetry, Receipt QR, Bank Accounts, Receipt Template, Product Photo, Static QRIS, Outbox Queue UI |
| i18n Migration | IN PROGRESS | Migrasi bertahap hardcoded id_ID --> ARB (Auth, Customers, Inventory, Categories, Catalog, Reports, Shift, Users, Held Orders, Checkout, Cart, POS, Receipt Summary, Bank, Tax/QRIS, Outbox/Telemetry, Menu Image, Receipt/Printer/About, Placeholders/Route/Env, Image Share Errors) |
| Multi-Tenant SaaS | IN PROGRESS | Tahap 1 (ADR) DONE, Tahap 2 (Expand migration) DONE DEV, Tahap 3+ TODO |

**Tech debt utama**: TD-001 (codegen analyzer 6.x -> 13.x butuh coordinated upgrade freezed 2-->3, riverpod 2-->3, drift 2.20-->2.21+).

---

## 12. Risks & Open Questions

| Risk | Dampak | Mitigasi / Status |
|---|---|---|
| Drift analyzer pinned ke 6.x menghambat upgrade | Build lambat, stuck di ecosystem lama | TD-001: coordinated upgrade terencana (freezed 3, riverpod 3, drift 2.21+) |
| Supabase free-tier tidak punya database branching | Eksperimen schema/RLS sulit | Pakai project staging terpisah, semua migrasi via SQL file versioned |
| Single-tenant schema bukan SaaS | Kalau pivot ke vendor model, perlu migrasi besar | ADR-0014 + multi-tenant TODO sudah ada, migrasi expand-then-contract |
| Cetak logo perlu bitmap 1-bit | Owner harus siapkan file dengan benar | Doc di docs/release.md / receipt_template notes, dan fallback skip logo tanpa fail |
| iOS background sync best-effort saja | iOS user bisa kehilangan sinkronisasi otomatis | Manual "Sinkron Sekarang" + on-resume sync (future) |
| Free-tier Supabase pause setelah inaktif | Production break | Workflow supabase-ping.yml keep-alive |
| Outbox bisa numpuk kalau sync gagal terus | Bisa jadi bottleneck | Outbox queue UI untuk retry/delete, retention policy perlu dijaga |
| Multi-device race condition pada transaksi | Bisa double-count kalau 2 device checkout bareng | Idempotency UUID v7 + ON CONFLICT DO NOTHING di server, LWW untuk settings/customer |

---

## 13. Glossary

- **ARB**: Application Resource Bundle, format file untuk i18n Flutter.
- **Bootstrap**: Pull data awal dari Supabase setelah login (auth context --> master data --> transactions).
- **Branch**: Cabang fisik toko.
- **Cashier (Kasir)**: Pengguna aplikasi di lini depan.
- **DR**: Disaster Recovery.
- **Drift**: ORM SQLite untuk Dart/Flutter dengan typed SQL & reactive streams.
- **ESC/POS**: Bahasa perintah standar untuk printer thermal.
- **LWW**: Last-Write-Wins (strategi sync untuk non-financial entities).
- **Manager**: Manajer cabang.
- **Modifier**: Option/extra pada produk (mis. less sugar, extra shot).
- **Organization**: Tenant boundary (future, ADR-0014).
- **Outbox**: Antrian perubahan lokal yang akan disinkronkan ke server.
- **Owner**: Pemilik usaha.
- **POS**: Point of Sale.
- **RBAC**: Role-Based Access Control.
- **RLS**: Row Level Security (Postgres).
- **SaaS**: Software as a Service.
- **Shift Closing**: Tutup Kas / Z-Report.
- **Subscription Plan**: Paket langganan (free/plus) --- future, ADR-0014.
- **UUID v7**: Time-ordered UUID yang dipakai sebagai client-side ID & idempotency key.

---

## 14. Referensi Lintas Dokumen

- **README.md** --- overview & getting started.
- **PROJECT_STATUS.md** --- implementasi tracker (workflow TODO --> DONE QA).
- **PROJECT_MEMORY.md** --- kronologis perubahan harian + keputusan teknis.
- **MASTER_PROMPT_v5.md** --- master build prompt dengan engineering principles non-negotiable.
- **docs/adr/NNNN-*.md** --- Architecture Decision Records (14 ADRs saat ini).
- **docs/release.md** --- prosedur build & signing (Android/iOS).
- **docs/multi-tenant-saas-todo.md** --- TODO migrasi SaaS multi-tenant.
- **docs/inviting-users.md** --- flow invite user (FEAT-006).
- **docs/PHASE_1_SETUP.md** --- catatan setup phase 1.
- **supabase/migrations/** --- semua migration Supabase (forward-only, non-destruktif).

---

*Dokumen ini hidup berdampingan dengan PROJECT_MEMORY.md (kronologis harian) dan PROJECT_STATUS.md (status fase). Update dokumen ini ketika terjadi perubahan besar: ADR baru, perpindahan fase, perubahan actor/capability, atau pivot strategi seperti migrasi multi-tenant.*
