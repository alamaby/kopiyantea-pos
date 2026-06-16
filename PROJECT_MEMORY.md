# Project Memory

## 2026-06-16 - FEAT-002 Stage 5: Organization Integration & Onboarding + TD-001 Resolution

- Fitur/bug: Menyelesaikan integrasi organization scope ke seluruh aplikasi: onboarding flow, org card/settings, routing, dan drift codegen blocker (TD-001).
- File penting yang diubah:
  - `lib/features/auth/auth_provider.dart` — tambah `needsOnboarding` state, `completeOnboarding()`, derived org providers
  - `lib/features/onboarding/onboarding_screen.dart` — landing create/join (baru)
  - `lib/features/onboarding/create_org_screen.dart` — form create org + OrganizationDao persist (baru)
  - `lib/features/onboarding/join_org_screen.dart` — MVP placeholder (baru)
  - `lib/features/settings/organization_card.dart` — org card + org switcher bottom sheet (baru)
  - `lib/features/settings/settings_screen.dart` — integrasi OrganizationCard
  - `lib/router.dart` — routes `/onboarding/*` + redirect logic
  - `lib/core/widgets/app_text_field.dart` — TextField → TextFormField, tambah param `validator`
  - `lib/l10n/arb/app_id.arb` + `app_en.arb` — 25+ keys onboarding + org settings
  - `pubspec.yaml` + `pubspec.lock` — bump drift/drift_dev 2.20.x → 2.21.0
  - `lib/core/database/app_database.dart` — restore migration drift API v1–v20
  - `lib/core/database/app_database.g.dart` — regenerated (770 KB, 28+ tabel)
- Keputusan teknis:
  - Pendekatan Minimal untuk local DB: tidak menambah `organization_id` ke semua local table. Scope cukup di auth+sync level. Switch org = clear DB + re-sync (single-device single-org constraint).
  - `AuthState.needsOnboarding` adalah state transitional antara login dan autentikasi penuh, mencegah user tanpa org mengakses POS/Settings prematurely.
  - Router redirect: `needsOnboarding` → `/onboarding`; `Authenticated` + bootstrap complete → `/pos`.
  - `completeOnboarding()` memulai bootstrap setelah org dibuat, memicu sync org-scoped data.
  - `AppTextField` pindah ke `TextFormField` agar mendukung `validator` dan `Form` secara alami.
  - drift_dev 2.21.0 fixes `Null is not InterfaceElement` tanpa perlu upgrade major version echelon lain (freezed 2.x / riverpod 2.x tetap compatible).
- Command verifikasi yang disarankan:
  - `flutter pub run build_runner build --delete-conflicting-outputs` (regenerate freezed/riverpod + drift)
  - `flutter gen-l10n`
  - `flutter analyze`
  - Sign-in tanpa org → redirect ke onboarding → create org → submit → redirect bootstrap → sync → /pos
- Proposed commit message:
  - `feat(saas): Stage 5 — Organization integration & onboarding (FEAT-002)`

## 2026-06-15 - UI Polish: Badge Overlap and SegmentedButton Wrap Fixes

- Fitur/bug: Memperbaiki dua bug UI layout saat bahasa English.
- File penting yang diubah:
  - `lib/core/widgets/app_badge.dart`
  - `lib/features/transactions/transaction_list_screen.dart`
  - `lib/features/settings/settings_screen.dart`
- Keputusan teknis:
  - `AppBadge.label` Text ditambahkan `maxLines: 1` dan `overflow: TextOverflow.ellipsis` agar badge teks (misal "Completed") tidak wrap ke baris kedua saat space sempit.
  - `transaction_list_screen.dart` inner Row (nomor transaksi + badge status) tidak punya overflow handling. Nomor transaksi dan badge status masing-masing dibungkus `Flexible` dengan `maxLines: 1` + `overflow: TextOverflow.ellipsis`.
  - `SettingsScreen._ThemeSection` SegmentedButton label "System" ditambahkan `maxLines: 1` dan `overflow: TextOverflow.ellipsis` untuk mencegah wrap di Bahasa English.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Buka Settings > Display (Tampilan) dalam bahasa English; cek tab System/Light/Dark tetap satu baris.
  - Buka History dalam bahasa English; cek badge "Completed" tidak menumpuk ke nominal transaksi.
- Proposed commit message:
  - `fix: prevent badge and segmented button text wrapping in English`

## 2026-06-15 - SaaS Multi-Tenant Stage 2-3: Dev Database Script and RLS Rewrite

- Fitur/bug: Menyelesaikan database development multi-tenant dan rewrite RLS policies supaya tenant-aware.
- File penting yang diubah:
  - `supabase/migrations/20260613110000_multi_tenant_saas_expand.sql` (sudah ada sebelumnya)
  - `.kimchi/docs/dev_database_multitenant.sql` (script lengkap DDL + INSERT)
  - `.kimchi/docs/restore_order.md` (urutan restore tabel)
  - `supabase/migrations/20260615000000_rls_rewrite_multitenant.sql` (baru)
- Keputusan teknis:
  - Generate script dev database lengkap dari backup data single-tenant: CREATE TABLE 28 tabel dengan kolom SaaS inline, seed subscription_plans, default org backfill, dan INSERT semua data backup production.
  - Script dev database awalnya urutan DDL salah (organizations dibuat setelah tabel yang mereferensinya), lalu diperbaiki: organizations dibuat sebelum branches/products/categories dll.
  - Script dev database ditambahkan INSERT default organization, organization_members owner link, dan organization_subscriptions plus trial.
  - Menulis `.kimchi/docs/restore_order.md` mendokumentasikan dependency graph FK dan urutan restore tier 0-8.
  - Stage 3 RLS rewrite: 42 legacy policies di-drop, 2 helper functions lama di-rewrite jadi org-aware wrappers, 61 policies baru dibuat untuk 21 tabel.
  - Semua policies baru memakai helper functions dari expand migration (current_user_is_org_member, current_user_has_branch_access, current_user_can_manage_org, current_user_can_manage_branch).
  - 5 tabel baru di-enable RLS: transaction_item_options, option_groups, options, product_option_groups, pending_invitations.
- Command verifikasi yang disarankan:
  - Jalankan `supabase/migrations/20260615000000_rls_rewrite_multitenant.sql` di Supabase SQL Editor pilih "Run and enable RLS".
  - Cek `SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename;` — harus muncul 61+ policies.
  - Cek helper function `user_global_role()` dan `user_has_branch_access()` masih ada dan compatible (org-aware).
- Proposed commit message:
  - `feat: generate dev multitenant database script and rewrite rls policies`

## 2026-06-13 - Bottom Navigation English Transactions Label Fix

- Fitur/bug: Memperbaiki label bottom nav English untuk Transactions yang wrap menjadi dua baris di layar mobile.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/core/widgets/adaptive_shell.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambahkan key ARB `navTransactionsCompact`.
  - Bottom navigation memakai `compactLabel` khusus mobile; NavigationRail dan area lain tetap memakai label penuh `navTransactions`.
  - English compact label memakai `History` agar muat satu baris; Indonesia tetap `Transaksi`.
  - Menjalankan `flutter gen-l10n` dan `dart format lib/core/widgets/adaptive_shell.dart`.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Buka app dengan language English di layar mobile dan cek bottom nav label keempat tampil satu baris sebagai `History`.
- Proposed commit message:
  - `fix: use compact transactions label in bottom navigation`

## 2026-06-13 - Multi-Tenant SaaS Supabase Expand Migration

- Fitur/bug: Memulai tahap 2 migrasi SaaS multi-tenant dengan migration expand Supabase untuk tenant boundary dan subscription metadata.
- File penting yang diubah:
  - `supabase/migrations/20260613110000_multi_tenant_saas_expand.sql`
  - `docs/multi-tenant-saas-todo.md`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambahkan tabel `organizations`, `organization_members`, `subscription_plans`, `organization_subscriptions`, `branch_subscriptions`, `usage_counters`, dan `entitlement_events`.
  - Menambahkan `organization_id` nullable ke tabel bisnis global: `branches`, `products`, `categories`, `customers`, `option_groups`, `options`, `product_option_groups`, `bank_accounts`, `company_settings`, `pending_invitations`, dan `customer_point_ledger`.
  - Merelaksasi constraint singleton `company_settings_singleton` agar company settings bisa menjadi per-organization pada fase app migration berikutnya.
  - Backfill single-tenant existing data ke satu default organization, menandai branch pertama sebagai main branch, membuat organization membership dari `app_users.global_role`, dan memberi subscription plus trial 30 hari.
  - Menambahkan helper function organization-aware untuk persiapan rewrite RLS tahap 3 tanpa mengganti policy lama dulu.
  - Tidak menghapus unique constraint global lama pada tahap expand; scoped unique index baru ditambahkan dan contract dilakukan nanti setelah app organization-aware.
- Command verifikasi yang disarankan:
  - Jalankan migration `20260613110000_multi_tenant_saas_expand.sql` di Supabase staging dengan `APP_ENV=staging`.
  - Cek `organizations`, `organization_members`, `branches.organization_id`, dan `organization_subscriptions`.
  - Query validasi row global yang masih `organization_id is null` sebelum lanjut tahap 3.
- Proposed commit message:
  - `feat: add multi-tenant supabase expand migration`

## 2026-06-13 - Daily Supabase Database and Storage Backup Workflow

- Fitur/bug: Menambahkan GitHub Actions workflow backup harian untuk Supabase free tier agar database dan object storage tersalin ke Google Drive.
- File penting yang diubah:
  - `.github/workflows/supabase-backup.yml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Workflow mengikuti pola sibling repo Bagistruk untuk dump database memakai `postgres:17-alpine` + `pg_dump --format=plain --no-owner --no-privileges`, lalu mengunggah hasil `.sql.gz` ke Google Drive via `rclone`.
  - Backup storage ditambahkan sebagai archive `.tar.gz` terpisah memakai Supabase Storage S3-compatible API dan mencakup bucket `product-images`, `qris-images`, dan `receipt-logos`.
  - Menambahkan file checksum SHA-256 untuk backup database dan storage, serta manifest storage berisi timestamp, daftar bucket, jumlah file, dan ukuran tiap bucket.
  - Retention Google Drive diset 30 hari untuk database, storage archive, checksum, dan manifest.
  - Secrets yang dibutuhkan: `RCLONE_CONFIG_BASE64`, `SUPABASE_DB_HOST`, `SUPABASE_DB_PORT`, `SUPABASE_DB_NAME`, `SUPABASE_DB_USER`, `SUPABASE_DB_PASSWORD`, `SUPABASE_S3_ENDPOINT`, `SUPABASE_S3_REGION`, `SUPABASE_S3_ACCESS_KEY_ID`, dan `SUPABASE_S3_SECRET_ACCESS_KEY`.
- Command verifikasi yang disarankan:
  - Tambahkan semua GitHub Actions secrets di repository.
  - Jalankan workflow `Supabase Backup` secara manual dari tab Actions.
  - Cek Google Drive path `gdrive:kopiyantea-pos/supabase-backups/database`, `storage`, dan `manifests`.
  - Download salah satu `.sql.gz` dan `.tar.gz`, lalu validasi checksum dengan `sha256sum -c`.
- Proposed commit message:
  - `ci: add daily supabase database and storage backup workflow`

## 2026-06-13 - Multi-Tenant SaaS Architecture ADR

- Fitur/bug: Menambahkan TODO tahapan migrasi SaaS multi-tenant dan menyelesaikan tahap 1 berupa ADR desain arsitektur.
- File penting yang diubah:
  - `docs/multi-tenant-saas-todo.md`
  - `docs/adr/0014-multi-tenant-saas-architecture.md`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menetapkan `organizations` sebagai tenant boundary utama; data bisnis harus scoped langsung via `organization_id` atau tidak langsung via `branch_id`.
  - Authorization SaaS dipindah dari `app_users.global_role` global ke `organization_members` scoped per organization.
  - Signup organisasi harus dilakukan via backend function/RPC atomic yang membuat organization, owner membership, main branch, branch access, default settings, dan plus trial 30 hari.
  - Free/plus, trial, branch add-on, quota invite karyawan, dan limit transaksi/katalog dimodelkan sebagai subscription plus entitlement snapshot.
  - RLS harus organization-aware dan tidak boleh memakai `USING (TRUE)` untuk data bisnis tenant.
  - Migrasi wajib expand-then-contract sesuai ADR-0008 dan dikerjakan di Supabase staging project terpisah karena free tier tidak mendukung branching.
- Command verifikasi yang disarankan:
  - Review `docs/adr/0014-multi-tenant-saas-architecture.md`.
  - Review `docs/multi-tenant-saas-todo.md`.
  - Setelah implementasi schema dimulai: `dart run build_runner build --delete-conflicting-outputs`, `flutter gen-l10n`, `flutter analyze`, dan `flutter test`.
- Proposed commit message:
  - `docs: add multi-tenant saas architecture plan`

## 2026-06-13 - Guard Company Settings Owner RLS Helper

- Fitur/bug: Memperbaiki error Supabase migration `function user_global_role() does not exist` saat migration global receipt logo dijalankan di environment yang belum punya helper RLS.
- File penting yang diubah:
  - `supabase/migrations/20260612120000_global_receipt_logo.sql`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Policy read `company_settings` tetap dibuat karena tidak membutuhkan helper.
  - Policy owner insert/update/delete dibungkus `DO` block dengan guard `to_regprocedure('public.user_global_role()')`.
  - Jika helper belum ada, migration memberi notice dan tidak membuat write policy, sehingga RLS tetap deny-by-default untuk write daripada membuka akses.
- Command verifikasi yang disarankan:
  - Jalankan ulang migration Supabase `20260612120000_global_receipt_logo.sql`.
  - Pastikan base migration `20260518150009_rls_helpers.sql` sudah diterapkan sebelum aplikasi owner perlu menyimpan logo global.
- Proposed commit message:
  - `fix: guard company settings rls helper`

## 2026-06-13 - Guard Global Receipt Logo Migration Seed

- Fitur/bug: Memperbaiki error Supabase migration `relation "public.receipt_settings" does not exist` saat menjalankan migration global receipt logo di environment yang belum punya tabel legacy tersebut.
- File penting yang diubah:
  - `supabase/migrations/20260612120000_global_receipt_logo.sql`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Seed dari `receipt_settings` dibungkus `DO` block dengan guard `to_regclass('public.receipt_settings')`.
  - Seed legacy hanya dijalankan jika tabel lama ada; jika tidak ada, migration tetap membuat `company_settings` kosong untuk nanti diisi owner dari aplikasi.
  - Guard tambahan mengecek kolom `logo_position`; jika kolom belum ada, seed memakai default `'top'`.
- Command verifikasi yang disarankan:
  - Jalankan ulang migration Supabase `20260612120000_global_receipt_logo.sql` di environment yang gagal sebelumnya.
  - `flutter analyze`
- Proposed commit message:
  - `fix: guard global receipt logo migration seed`

## 2026-06-12 - Global Receipt Logo Setting

- Fitur/bug: Memindahkan logo coffee shop untuk struk dari pengaturan per cabang menjadi pengaturan global yang dikelola owner.
- File penting yang diubah:
  - `supabase/migrations/20260612120000_global_receipt_logo.sql`
  - `lib/core/database/app_database.dart`
  - `lib/core/database/daos/company_settings_dao.dart`
  - `lib/core/database/daos/dao_providers.dart`
  - `lib/core/domain/enums.dart`
  - `lib/core/sync/sync_repository.dart`
  - `lib/features/settings/receipt_settings_screen.dart`
  - `lib/features/pos/print_receipt_use_case.dart`
  - `lib/features/pos/share_receipt_use_case.dart`
  - `lib/features/catalog/share_menu_image_use_case.dart`
  - `lib/features/settings/outbox_queue_screen.dart`
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah tabel global `company_settings` dengan singleton `id = 'global'` untuk `receipt_logo_url`, `show_receipt_logo`, dan `receipt_logo_position`.
  - Migrasi lokal dan Supabase men-seed logo global dari logo receipt per cabang terbaru agar upgrade non-destruktif.
  - UI Receipt Display sekarang menampilkan kartu logo global owner-managed di atas daftar cabang; kartu cabang tetap mengatur header/footer, visibility toggles, QRIS, dan paper width.
  - Print receipt, share receipt image, dan share menu image membaca logo dari `company_settings`; logo per cabang lama hanya dipakai sebagai fallback legacy saat row global belum ada.
  - Sync pull/push mendukung entity outbox `companySetting`; RLS Supabase mengizinkan semua authenticated read dan owner-only write.
  - Menjalankan `dart format` untuk file Dart yang berubah; tidak menjalankan analyze/test/build_runner sesuai instruksi proyek.
- Command verifikasi yang disarankan:
  - `dart run build_runner build --delete-conflicting-outputs`
  - `flutter gen-l10n`
  - `flutter analyze`
  - Jalankan migrasi Supabase, upload logo global dari owner, sync device lain, lalu cetak/share struk di beberapa cabang untuk memastikan logo sama.
- Proposed commit message:
  - `feat: make receipt logo global`

## 2026-06-12 - ARB Migration for Internal Image Share Exceptions

- Fitur/bug: Menghapus sisa pesan exception internal hardcoded Indonesia pada renderer share image menu dan struk.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/catalog/share_menu_image_use_case.dart`
  - `lib/features/catalog/catalog_screen.dart`
  - `lib/features/pos/share_receipt_use_case.dart`
  - `lib/features/transactions/transaction_detail_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Renderer PNG sekarang melempar kode internal `share_menu_image_encode_failed` dan `share_receipt_image_encode_failed`, bukan teks user-facing.
  - UI Catalog dan Transaction Detail memetakan kode internal tersebut ke key ARB `catalogProductsCreateImageFailed` dan `receiptCreateImageFailed`.
  - Caller lain yang menampilkan pesan generic localized tetap aman karena tidak menampilkan isi exception mentah.
  - Menjalankan `flutter gen-l10n` setelah update ARB dan `dart format` untuk file yang disentuh.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Coba share menu PNG dan share receipt image dalam bahasa English dan Indonesia, termasuk skenario gagal render bila bisa direproduksi.
- Proposed commit message:
  - `feat: localize image share render errors`

## 2026-06-12 - Fix Analyze Errors After ARB Migration

- Fitur/bug: Memperbaiki dua error `flutter analyze` setelah migrasi ARB.
- File penting yang diubah:
  - `lib/features/settings/menu_image_settings_screen.dart`
  - `lib/features/pos/widgets/menu_grid.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menghapus `const` pada `Padding` preview menu image karena child memakai `menuLabel` dinamis dari localization.
  - Menambahkan `final l10n = AppL10n.of(context);` di `_MenuDetailRow.build` sebelum tooltip add memakai `l10n.posMenuAdd`.
  - Menjalankan `dart format` untuk dua file yang diperbaiki.
- Command verifikasi yang disarankan:
  - `flutter analyze`
- Proposed commit message:
  - `fix: resolve localization analyze errors`

## 2026-06-12 - ARB Migration Batch for Remaining Priority Hardcoded Copy

- Fitur/bug: Melanjutkan migrasi sisa hardcoded text prioritas ke ARB untuk placeholder screen, route/env error fallback, undo snackbar, settings import errors, held order preview fallback, dan image crop title.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/placeholders/placeholder_screen.dart`
  - `lib/router.dart`
  - `lib/main.dart`
  - `lib/core/widgets/undo_snackbar.dart`
  - `lib/features/pos/widgets/cart_panel.dart`
  - `lib/features/users/user_list_screen.dart`
  - `lib/features/settings/settings_provider.dart`
  - `lib/features/settings/settings_screen.dart`
  - `lib/core/storage/image_upload_service.dart`
  - `lib/features/catalog/product_form_screen.dart`
  - `lib/features/settings/receipt_settings_screen.dart`
  - `lib/features/settings/qris_settings_screen.dart`
  - `lib/features/pos/held_order_service.dart`
  - `lib/features/pos/widgets/held_orders_sheet.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key global `actionUndo`, `placeholderScreenMessage`, `routeNotFound`, `envConfig...`, dan `imageCropTitle`.
  - Menambah key `heldOrdersNoItems` dan `heldOrdersItemUnavailable`, lalu mengubah `HeldOrderService` agar tidak mengembalikan fallback copy user-facing; widget menerjemahkan fallback via ARB.
  - Mengubah `buildUndoSnackBar` agar menerima `undoLabel` dari caller yang memiliki `AppL10n`, sehingga helper core tidak menyimpan label Indonesia.
  - Mengubah `ImageUploadService.pickAndUpload` agar menerima `cropTitle` dari caller yang memiliki locale aktif.
  - Mengubah error import settings menjadi kode stabil (`invalid_json`, `wrong_app`, `version_mismatch`, `settings_field_invalid`), lalu mapping ke ARB di UI settings.
  - Env validation fallback diberi `localizationsDelegates`/`supportedLocales` sendiri karena tampil sebelum aplikasi utama terbentuk; title MaterialApp memakai English generated fallback tanpa hardcoded UI copy.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Cek placeholder route, route not found, env config error fallback, undo snackbar di cart/users, import settings error, crop product photo, dan held order preview fallback dalam bahasa English dan Indonesia.
- Proposed commit message:
  - `feat: migrate remaining priority copy to arb`

## 2026-06-12 - ARB Migration Batch for Receipt, Printer, and About Settings

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk Receipt Settings, Printer Settings, dan About App.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/settings/receipt_settings_screen.dart`
  - `lib/features/settings/printer_settings_screen.dart`
  - `lib/features/settings/about_app_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB `receiptSettings...` untuk label logo/header/footer, pesan bantuan, toggle tampilan struk, preview struk, QRIS preview, snackbar saved, dan sample copy preview.
  - Menambah key ARB `printer...` untuk scan printer, status/error koneksi Bluetooth, empty state, badge status, test print, dan payload test print yang tampil di struk.
  - Menambah key ARB `about...` untuk section/row/link label di About App.
  - Reuse key existing seperti `settingsReceiptDisplay`, `settingsReceiptPrinter`, `settingsAboutApp`, `settingsBranchesLoadFailed`, `settingsNoBranches`, `catalogProductChooseFromGallery`, `catalogProductTakeFromCamera`, `catalogProductUploadFailed`, `posSubtotal`, `posDiscount`, `posTax`, `posTotal`, `posPaymentReceived`, `posPaymentChange`, `paymentCash`, `receiptThankYou`, `statusSaving`, dan `actionSave`.
  - String teknis/dinamis seperti nama/alamat/telepon cabang, URL logo/link, route/path upload, value DB `top/bottom`, ukuran kertas `58mm/80mm`, brand `KopiyanteaPOS`, label pajak `PB1`, dan nominal preview tetap tidak dipindah ke ARB.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka Settings > Receipt Display dalam bahasa English dan Indonesia; cek branch empty/error, logo upload/delete, header/footer, semua toggle, lebar kertas, preview struk, QRIS preview, dan save snackbar.
  - Buka Settings > Receipt Printer dalam bahasa English dan Indonesia; cek scan printer, empty paired devices, status connected/disconnected, error Bluetooth, test print, dan disconnect.
  - Buka Settings > About App dalam bahasa English dan Indonesia; cek section aplikasi, pembuat, dan semua label tautan.
- Proposed commit message:
  - `feat: migrate receipt printer and about copy to arb`

## 2026-06-12 - ARB Migration Batch for Menu Image Settings

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk Settings > Menu Image.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/settings/menu_image_settings.dart`
  - `lib/features/settings/menu_image_settings_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB `menuImage...` untuk snackbar saved, validasi hex/width, switch show branch name/address/phone, label layout header, label layout stacked/split, jumlah card, image width, helper width, background color, hint warna, dan label preview Logo/Menu.
  - Mengubah extension `MenuImageHeaderLayoutX` agar label layout memakai `localizedLabel(AppL10n)` alih-alih string Indonesia hardcoded.
  - Reuse key existing `settingsMenuImage`, `settingsBranchesLoadFailed`, `settingsNoBranches`, `statusSaving`, dan `actionSave`.
  - String teknis/dinamis seperti nama/alamat/telepon cabang, warna hex swatch, angka kolom, ukuran pixel, nilai DB `stacked/split`, dan warna preview tetap tidak dipindah ke ARB kecuali hint field yang tampil ke user.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka Settings > Menu Image dalam bahasa English dan Indonesia; cek empty/error branch, switch branch info, layout header, jumlah card, width validation/helper, background color hex validation, swatch warna, preview, dan save snackbar.
- Proposed commit message:
  - `feat: migrate menu image settings copy to arb`

## 2026-06-12 - ARB Migration Batch for Outbox Queue and Telemetry

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk Settings > Sync Queue/Outbox dan Settings > Telemetry.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/settings/outbox_queue_screen.dart`
  - `lib/features/settings/telemetry_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB `outbox...` untuk title, tooltip retry/delete all failed, empty/error state, section failed/pending/done dengan count, snackbar retry/delete, dialog delete all/delete row, action retry, dan seluruh label entity outbox.
  - Menambah key ARB `telemetry...` untuk reload tooltip, error state, section application/database/sync, row labels app/version/db size/transaction items/stock movements/last sync/pending/failed/done.
  - Mengubah helper `_entityLabel` di outbox agar menerima `AppL10n` dan memetakan `OutboxEntityType` ke ARB, bukan string Indonesia hardcoded.
  - Reuse key existing seperti `settingsTelemetry`, `transactionsTitle`, `actionCancel`, dan `actionDelete`.
  - String dinamis seperti payload preview, lastError, attempt count, timestamp, ukuran file, jumlah row, dan raw JSON payload tetap tidak dipindah ke ARB.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka Settings > Telemetry dalam bahasa English dan Indonesia; cek title, reload tooltip, section, dan row labels.
  - Buka Settings > Sync Queue dalam bahasa English dan Indonesia; cek empty/error state, grouped section failed/pending/done, entity labels, retry/delete row, retry all failed, dan delete all failed.
- Proposed commit message:
  - `feat: migrate outbox and telemetry copy to arb`

## 2026-06-12 - ARB Migration Batch for Tax and Static QRIS Settings

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk Tax Settings dan Static QRIS Settings.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/settings/tax_settings_screen.dart`
  - `lib/features/settings/qris_settings_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB `settingsTax...` untuk snackbar saved, label/hint field pajak, validasi rate/label, switch inclusive, dan preview pajak zero/inclusive/exclusive dengan placeholder nominal/rate.
  - Menambah key ARB `settingsQris...` untuk snackbar update/delete, upload error, dialog hapus QRIS, empty image state, tombol gallery/camera/delete, dan label ganti gambar.
  - Menambah key `settingsBranchesLoadFailed` untuk error load daftar cabang tanpa placeholder, agar screen Settings subpage tidak meminjam key dari fitur lain.
  - Reuse key existing seperti `settingsTax`, `settingsStaticQris`, `settingsNoBranches`, `actionSave`, `statusSaving`, `actionCancel`, dan `actionDelete`.
  - String dinamis seperti nama/alamat cabang, nominal rupiah, rate pajak, label pajak tersimpan, error upload teknis, URL QRIS, dan payload sync tetap tidak dipindah ke ARB.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka Settings > Tax dalam bahasa English dan Indonesia; cek empty/error branch, validasi rate/label, switch inclusive, preview pajak, dan save.
  - Buka Settings > Static QRIS dalam bahasa English dan Indonesia; cek empty/error branch, empty image state, upload dari gallery/camera, upload error, hapus QRIS dialog, dan snackbar update/delete.
- Proposed commit message:
  - `feat: migrate tax and qris settings copy to arb`

## 2026-06-12 - ARB Migration Batch for POS Held Orders and Option Picker

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk held orders sheet dan modifier option picker di POS.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/pos/widgets/held_orders_sheet.dart`
  - `lib/features/pos/widgets/option_picker_sheet.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB `heldOrders...` untuk title/empty/error state, tooltip delete, dialog replace cart, branch missing snackbar, restore snackbar, dialog delete held order, tooltip app bar, dan loading preview item.
  - Menambah key ARB `modifiersPicker...` untuk error option picker, tombol add to cart, suffix required, dan suffix multi-select.
  - Menambah key global `actionSaveChanges` agar tombol simpan perubahan tidak meminjam key spesifik fitur lain.
  - Reuse key existing seperti `cartHoldOrder`, `actionCancel`, `actionDelete`, dan format rupiah/tanggal yang sudah ada.
  - String dinamis seperti label held order, nama produk, nama option/group modifier, nominal rupiah, jumlah badge, route, dan placeholder loading `...` tetap tidak dipindah ke ARB.
  - Membersihkan import `app_button.dart` yang tidak terpakai di `held_orders_sheet.dart`.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka POS dalam bahasa English dan Indonesia; cek held orders action, empty/error state, restore held order, replace cart dialog, delete held order dialog, dan modifier option picker add/save dengan required/multi group.
- Proposed commit message:
  - `feat: migrate pos held order copy to arb`

## 2026-06-12 - ARB Migration Batch for Users

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk user management, termasuk daftar pengguna, undangan tertunda, form undang/edit pengguna, dan pembatalan undangan.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/users/user_list_screen.dart`
  - `lib/features/users/user_form_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB `users...` untuk title, invite action, empty/error state, section pending/active users, cancel invitation dialog, undo snackbar message, form validation, field labels/hints, active toggle, branch access section, branch load error, save/invite actions, dan help text undangan.
  - Reuse key existing `authEmail`, `statusLoading`, `statusSaving`, `statusInactive`, serta `settingsRoleOwner/Manager/Cashier` agar label role tetap konsisten lintas Settings dan Users.
  - Mengubah helper role lokal dari string switch Indonesia menjadi `_roleLabel(AppL10n, GlobalRole)` berbasis enum dan ARB.
  - String dinamis seperti nama pengguna, email, nama/alamat cabang, route, payload sync, dan simbol required `*` tetap tidak dipindah ke ARB.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka Settings > Users dalam bahasa English dan Indonesia; cek empty/error state, daftar pending/active users, badge role/status inactive, undang user, edit user, branch access, validasi nama/email/duplikasi, cancel invitation, dan undo snackbar.
- Proposed commit message:
  - `feat: migrate users copy to arb`

## 2026-06-12 - ARB Migration Batch for Shift Closing

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk layar Tutup Kas/Shift Closing.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/shift/shift_closing_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB `shift...` untuk no-branch/error state, section riwayat, empty history, rekap kas harian, saldo awal, penjualan/refund tunai, expected/count cash, variance balanced/short/over, catatan, snackbar saved, dan summary riwayat.
  - Reuse key existing `navShiftClosing`, `statusSaving`, serta format dinamis `formatRupiah`/`formatDateTime`.
  - Menambah `shiftBalancedBadge` sebagai label pendek khusus badge riwayat agar tidak memakai pesan panjang `shiftBalanced` yang dipakai di panel variance.
  - String dinamis seperti nama cabang, tanggal, nominal rupiah, notes user, jumlah transaksi, dan prefix currency `Rp ` tetap tidak dipindah ke ARB.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka Shift Closing/Tutup Kas dalam bahasa English dan Indonesia; cek no-branch/error state, rekap kas, input saldo awal/hitungan fisik, variance pas/kurang/lebih, catatan, simpan tutup kas, dan riwayat.
- Proposed commit message:
  - `feat: migrate shift closing copy to arb`

## 2026-06-12 - ARB Migration Batch for Reports

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk layar Reports, quick today badge, dan gambar laporan yang dibagikan.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/reports/reports_screen.dart`
  - `lib/features/reports/report_providers.dart`
  - `lib/features/reports/share_report_image_use_case.dart`
  - `lib/features/reports/widgets/today_quick_badge.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB `reports...` untuk empty/error/no-branch state, date presets, tombol share image, section laporan, stat transaksi, label transfer per rekening, produk terlaris, tooltip quick badge, subject/text share, dan teks dalam PNG report.
  - Mengganti `DatePreset.label` hardcoded Indonesia dengan helper `localizedDatePresetLabel(AppL10n, DatePreset)` agar preset tanggal mengikuti locale aktif.
  - Mengganti `paymentMethodLabel` ke `localizedPaymentMethodLabel` di screen dan image renderer agar breakdown payment method mengikuti locale.
  - Mengubah fallback rekening transfer kosong dari teks `Tanpa rekening` menjadi token internal `missingBankAccountSnapshotKey`, lalu diterjemahkan di UI/image via ARB.
  - String dinamis seperti nama cabang, nama produk, snapshot rekening bank, nominal rupiah, persentase, tanggal, jumlah transaksi, route, nama file image, dan suffix teknis `tx` tetap diperlakukan sebagai data/format dinamis.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka Reports dalam bahasa English dan Indonesia; cek app bar, preset tanggal, start/end custom date, empty/no-branch/error state, revenue card, payment methods, transfer per rekening, top products, quick today badge tooltip, dan share report image.
- Proposed commit message:
  - `feat: migrate reports copy to arb`

## 2026-06-12 - ARB Migration Batch for Catalog Products and Recipes

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk layar daftar produk/menu, form produk, detail produk, pengaturan cabang produk, dan recipe editor.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/catalog/catalog_screen.dart`
  - `lib/features/catalog/product_form_screen.dart`
  - `lib/features/catalog/product_detail_screen.dart`
  - `lib/features/catalog/recipe_editor_sheet.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB `catalogProducts...`, `catalogProduct...`, dan `catalogRecipe...` untuk list menu, CSV import/export, share menu image, form produk, kategori picker, upload foto, detail produk, branch settings, modifier link subtitle, recipe card, dan bottom sheet bahan.
  - Menambah key global `statusInactive` agar badge nonaktif bisa dipakai lintas fitur tanpa meminjam label rekening bank.
  - Reuse key existing seperti `navProducts`, `modifiersTitle`, `actionSave`, `actionAdd`, `actionCancel`, `actionDelete`, `actionEdit`, `actionImport`, dan `statusLoading`.
  - String teknis/dinamis seperti nama produk/cabang/kategori/bahan, SKU value, route, payload sync, format rupiah, satuan stok, angka `0`, dan separator visual tetap tidak dipindah ke ARB.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka layar Menu dalam bahasa English dan Indonesia; cek search, empty/error/no branch state, share menu PNG, export/import CSV, toggle availability, dan badge inactive.
  - Buka tambah/ubah produk; cek validasi nama/harga/SKU, pilih/upload/hapus foto, kategori/no category/quick add kategori, switch active, dan tombol save.
  - Buka detail produk; cek master card, branch settings, validasi override price/discount, discount expiry, modifier link, recipe empty state, tambah/ubah/hapus bahan, picker bahan, dan quantity helper.
- Proposed commit message:
  - `feat: migrate catalog product copy to arb`

## 2026-06-12 - ARB Migration Batch for Categories and Modifier Groups

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk kategori produk dan modifier groups.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/catalog/categories_screen.dart`
  - `lib/features/modifiers/option_groups_screen.dart`
  - `lib/features/modifiers/option_group_form_screen.dart`
  - `lib/features/modifiers/product_options_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB `catalog...` untuk list/form kategori, empty/error state, dialog hapus kategori, validasi nama kategori, dan pilihan warna.
  - Menambah key ARB `modifiers...` untuk list modifier groups, form group, delete dialog, options section, option editor, default badge, dan screen binding modifier ke produk.
  - Menambah key global `actionEdit`, `actionActivate`, dan `actionDeactivate` agar tooltip/aksi umum tidak reuse key spesifik fitur lain.
  - Reuse key existing seperti `settingsProductCategories`, `settingsProductModifiers`, `actionAdd`, `actionSave`, `actionCancel`, `actionDelete`, dan `statusSaving`.
  - String dinamis seperti nama kategori, nama modifier group/option, nama produk, harga tambahan, route, dan payload sync tetap tidak dipindah ke ARB.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka Product Categories dalam bahasa English dan Indonesia; cek empty state, tambah/ubah kategori, validasi nama, warna, toggle aktif/nonaktif, reorder, dan dialog hapus kategori.
  - Buka Product Modifiers dalam bahasa English dan Indonesia; cek empty state, tambah/ubah/hapus group, toggle required/multi-select, tambah/ubah/hapus option, default option, dan binding modifier ke produk.
- Proposed commit message:
  - `feat: migrate category and modifier copy to arb`

## 2026-06-12 - ARB Migration Batch for Inventory

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk layar stok/inventory.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/core/utils/localized_labels.dart`
  - `lib/features/inventory/inventory_list_screen.dart`
  - `lib/features/inventory/inventory_detail_screen.dart`
  - `lib/features/inventory/inventory_item_form_screen.dart`
  - `lib/features/inventory/stock_movement_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB `inventory...` untuk list stok, detail stok, form item stok, status stok, riwayat movement, dan catat pergerakan stok.
  - Menambah helper `localizedMovementTypeLabel` di `localized_labels.dart` agar enum `MovementType` bisa ditampilkan sesuai locale aktif tanpa mengubah helper label lama yang masih dipakai area lain.
  - Menambah key global `statusSaving` untuk label loading save yang bisa dipakai lintas fitur.
  - Satuan stok teknis seperti `g`, `kg`, `ml`, `L`, `pcs`, nominal `Rp`, angka hint `0`, nama item, catatan movement, route, dan nilai stok dinamis tetap tidak dipindah ke ARB.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka Inventory dalam bahasa English dan Indonesia; cek no-branch state, empty/error state, badge status stok, detail stok, form tambah/ubah item, validasi nama kosong, dan catat pergerakan purchase/adjustment/waste.
- Proposed commit message:
  - `feat: migrate inventory copy to arb`

## 2026-06-12 - ARB Migration Batch for Auth and Customers

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk flow login/bootstrap dan customer management.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/auth/login_screen.dart`
  - `lib/features/auth/bootstrap_screen.dart`
  - `lib/features/auth/bootstrap_provider.dart`
  - `lib/features/customers/customer_list_screen.dart`
  - `lib/features/customers/customer_form_screen.dart`
  - `lib/features/customers/customer_picker_sheet.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB `auth...` untuk login, magic link dialog, error auth, bootstrap loading/error states, dan `customers...` untuk list, form, picker, validasi, transaksi pelanggan, sort/search, dan empty state.
  - Menambahkan key global `actionOk` untuk dialog confirmation sederhana.
  - `BootstrapState` sekarang menyimpan kode step/error internal, bukan kalimat Indonesia, agar UI menerjemahkan lewat `AppL10n` tanpa perlu mengubah model freezed atau menjalankan build_runner.
  - Reuse key existing seperti `navCustomers`, `actionAdd`, `actionRetry`, `actionSignOut`, `statusLoading`, `receiptPoints`, dan `transactionsPoints`.
  - String brand `KopiyanteaPOS`, nomor transaksi `#$number`, nama/email/telepon customer, dan error teknis dinamis tetap tidak dipindah ke ARB.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka login/bootstrap dalam bahasa English dan Indonesia; cek validasi email/password, error auth, magic link dialog, tombol Google, step bootstrap, retry, dan sign out.
  - Buka Customers dalam bahasa English dan Indonesia; cek list/search/sort, empty state, tambah/ubah customer, validasi form, transaksi customer, dan customer picker dari cart.
- Proposed commit message:
  - `feat: migrate auth and customer copy to arb`

## 2026-06-12 - ARB Migration Batch for Bank Accounts

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk layar rekening bank dan picker rekening tujuan transfer.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/bank_accounts/bank_accounts_screen.dart`
  - `lib/features/bank_accounts/bank_account_picker_sheet.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB `bankAccounts...` untuk empty/error state, status aktif/nonaktif, aksi edit/activate/deactivate, dialog hapus, title form, label/hint field, validasi wajib, dan loading save.
  - Reuse key global seperti `settingsBankAccounts`, `checkoutDestinationAccount`, `checkoutAccountHolderPrefix`, `actionAdd`, `actionSave`, `actionCancel`, dan `actionDelete`.
  - Nilai dinamis seperti nama bank, nomor rekening, nama pemilik rekening, dan contoh nomor rekening tidak dipindah ke ARB.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka Settings > Bank Accounts dalam bahasa English dan Indonesia; cek empty state, tambah/ubah rekening, validasi field kosong, toggle aktif/nonaktif, dialog hapus, dan picker rekening tujuan di checkout transfer.
- Proposed commit message:
  - `feat: migrate bank account copy to arb`

## 2026-06-12 - ARB Migration Batch for Receipt Summary and QRIS

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk ringkasan pembayaran selesai dan tampilan QRIS POS.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/pos/widgets/receipt_summary_sheet.dart`
  - `lib/features/pos/widgets/qris_display.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB untuk status pembayaran berhasil, cetak/share struk, transaksi baru, error share, error printer yang mengarahkan ke Settings, poin struk, serta semua copy tampilan QRIS.
  - `ReceiptSummarySheet` memakai `AppL10n` dan helper `localizedPaymentMethodLabel` agar label metode bayar mengikuti locale aktif tanpa mapping lokal di widget.
  - Reuse key yang sudah ada seperti `posSubtotal`, `posDiscount`, `posTax`, `posTotal`, `posPaymentReceived`, `posPaymentChange`, `transactionsPayment`, `actionCancel`, dan error printer umum dari cart.
  - String teknis/dinamis seperti nomor transaksi, amount rupiah, label pajak `PB1`, nama cabang, dan brand/payment `QRIS` tetap tidak dipindah ke ARB.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka flow checkout dalam bahasa English dan Indonesia; cek ringkasan pembayaran, tombol cetak/share/transaksi baru, snackbar printer/share, QRIS kosong, QRIS image error, tombol pembayaran diterima, batal, dan tutup.
- Proposed commit message:
  - `feat: migrate receipt summary and qris copy to arb`

## 2026-06-12 - ARB Migration Batch for Checkout Sheet

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk checkout/payment sheet POS.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/pos/widgets/checkout_sheet.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB untuk no-total fallback, title payment method, tombol confirm payment, error checkout, transfer destination account, QRIS payment instructions/unavailable state, dan label kurang/kembalian.
  - Checkout sheet memakai `localizedPaymentMethodLabel` agar pilihan payment method mengikuti locale aktif.
  - Reuse key global seperti `posCheckout`, `posPaymentReceived`, `posPaymentChange`, dan `posTotal`.
  - String brand/metode pembayaran `QRIS`, prefix currency `Rp `, dan data bank/account dinamis tetap tidak dipindah ke ARB.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka checkout dalam bahasa English dan Indonesia; cek payment methods, cash received/change/short label, transfer bank account section, QRIS section, confirm button, dan error state checkout.
- Proposed commit message:
  - `feat: migrate checkout copy to arb`

## 2026-06-12 - ARB Migration Batch for Cart Panel

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk panel keranjang POS.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/pos/widgets/cart_panel.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB untuk empty cart, tombol bayar dengan amount, cetak/bagikan tagihan, hold order, clear cart, manual discount, customer attach/detach, modifier label, undo delete item, catatan item, fallback total/tax, dan error printer.
  - Reuse key umum yang sudah ada seperti `posCart`, `posCheckout`, `posSubtotal`, `posDiscount`, `posTax`, `posTotal`, `actionCancel`, `actionDelete`, dan `actionSave` agar tidak duplikasi label global.
  - `CartPanel` sekarang mengambil `AppL10n` di widget/dialog/snackbar yang menampilkan copy user-facing.
  - String teknis/dinamis seperti `PB1`, prefix currency `Rp `, nama produk/customer, opsi modifier, dan angka qty tetap tidak dipindah ke ARB.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka POS dengan keranjang kosong dan berisi item dalam bahasa English/Indonesia; cek tombol bayar, cetak/share tagihan, hold order dialog, clear cart dialog, manual discount dialog, customer row, item notes dialog, undo delete, dan total/tax fallback.
- Proposed commit message:
  - `feat: migrate cart panel copy to arb`

## 2026-06-12 - ARB Migration Batch for POS Shell and Menu Grid

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk layar POS utama dan grid/list menu kasir.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/pos/pos_screen.dart`
  - `lib/features/pos/widgets/menu_grid.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB untuk POS branch state, sync tooltip, tombol buka Settings, floating cart pill, menu loading/empty/search/filter/view mode, filtered empty state, dan tooltip tambah menu.
  - POS title memakai `navPos` yang sudah ada agar label navigasi dan app bar tetap konsisten.
  - Empty state menu untuk filter `Rekomendasi` memakai display label lokal, bukan token internal `__recommended__`.
  - String `QRIS` dan badge diskon persen tidak dipindah ke ARB karena merupakan label produk/metode pembayaran dan nilai dinamis.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka layar POS dalam bahasa English dan Indonesia; cek app bar, sync tooltip, no-branch state, search menu, filter Semua/Rekomendasi, empty state filter, view mode tooltip, dan floating cart pill.
- Proposed commit message:
  - `feat: migrate pos menu copy to arb`

## 2026-06-12 - ARB Migration Batch for Transactions

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk layar daftar transaksi dan detail transaksi.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/core/utils/localized_labels.dart`
  - `lib/features/transactions/transaction_list_screen.dart`
  - `lib/features/transactions/transaction_detail_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB untuk title/error/empty/search transaksi, status completed/voided, label tanggal Today/Yesterday, aksi struk, dialog void, customer/points, ringkasan, pembayaran, dan metode bayar.
  - Menambahkan helper `localizedPaymentMethodLabel` dan `localizedTransactionStatusLabel` berbasis `AppL10n` agar enum display label bisa dipakai konsisten tanpa mapping Indonesia lama.
  - Daftar transaksi sekarang memakai label metode bayar lokal untuk tampilan dan pencarian client-side.
  - Detail transaksi sekarang memakai `AppL10n` untuk action card, customer card, status badge, ringkasan total, payment card, snackbar, dan dialog pembatalan.
  - Menjalankan `flutter gen-l10n` setelah update ARB; file generated localization tetap tidak dilacak Git di repo ini.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka daftar transaksi dalam bahasa English dan Indonesia; cek search, status badge, empty/error state, dan group header Today/Yesterday.
  - Buka detail transaksi; cek tombol share/reprint/void, dialog void, snackbar, customer points, summary, dan payment labels.
- Proposed commit message:
  - `feat: migrate transaction copy to arb`

## 2026-06-11 - ARB Migration Batch for Home More and Settings

- Fitur/bug: Melanjutkan migrasi bertahap hardcoded text ke ARB untuk area Home, Lainnya/More, dan Pengaturan/Settings.
- File penting yang diubah:
  - `lib/l10n/arb/app_en.arb`
  - `lib/l10n/arb/app_id.arb`
  - `lib/features/home/home_screen.dart`
  - `lib/features/more/more_screen.dart`
  - `lib/features/settings/settings_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambah key ARB untuk copy Home, label Tutup Kas/Shift Closing, section Settings, tile owner, cabang, tampilan, bahasa, perangkat, backup/import/export, tentang, akun, role, dan sinkronisasi.
  - Mengganti ternary locale manual di Home/More dengan `AppL10n` agar semua copy baru bersumber dari ARB.
  - Mengganti pesan dinamis Settings memakai placeholder ARB seperti error cabang, jumlah pengaturan dipulihkan, jumlah cabang, jumlah antrian, dan hasil sinkronisasi.
  - Menjalankan `flutter gen-l10n` sebagai code generation i18n setelah penambahan ARB; file generated localization tidak dilacak Git di repo ini, sehingga perubahan reviewable ada pada ARB dan pemakaian `AppL10n`.
  - Sisa string di tiga layar target yang terdeteksi adalah route/internal keys, label bahasa `English/Indonesia`, label provider auth `Email/Google`, dan interpolasi version/app name yang tidak perlu diterjemahkan.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka Home, More, dan Settings; ganti bahasa English/Indonesia lalu pastikan label section, tombol, snackbar/dialog backup, account, dan sync berubah sesuai bahasa.
- Proposed commit message:
  - `feat: migrate home more and settings copy to arb`

## 2026-06-11 - English Default App Locale and Language Switcher

- Fitur/bug: Mengaktifkan dukungan multi-language dasar untuk English dan Indonesia, dengan English sebagai default.
- File penting yang diubah:
  - `l10n.yaml`
  - `lib/l10n/arb/app_en.arb`
  - `lib/main.dart`
  - `lib/core/l10n/locale_provider.dart`
  - `lib/core/widgets/adaptive_shell.dart`
  - `lib/features/home/home_screen.dart`
  - `lib/features/more/more_screen.dart`
  - `lib/features/settings/settings_screen.dart`
  - `lib/features/settings/settings_provider.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - App sebelumnya belum benar-benar multi-language karena `MaterialApp.router` dipaksa memakai `Locale('id', 'ID')`.
  - Locale sekarang dikontrol oleh `LocaleController` berbasis `SharedPreferences`, default ke `en`, dan hanya menerima bahasa yang didukung (`en`, `id`).
  - `l10n.yaml` memakai `app_en.arb` sebagai template agar English menjadi sumber/default translation.
  - Pengaturan bahasa ditambahkan di layar Pengaturan sebagai preferensi device lokal, bukan data cabang/sync.
  - Preferensi bahasa ikut export/import backup pengaturan device.
  - Label navigasi utama, More, dan Home mulai memakai `AppL10n`; sebagian layar fitur masih memiliki teks hardcoded Indonesia dan perlu migrasi bertahap ke ARB untuk cakupan i18n penuh.
- Command verifikasi yang disarankan:
  - `flutter gen-l10n`
  - `flutter analyze`
  - Buka aplikasi pada install baru dan pastikan navigasi default tampil English.
  - Buka Settings > Language, pilih Indonesia, dan pastikan navigasi utama berubah ke Bahasa Indonesia.
- Proposed commit message:
  - `feat: add english default locale and language switcher`

## 2026-06-05 - iOS Modular Headers for SQLite

- Fitur/bug: Memperbaiki error CocoaPods `The Swift pod sqlite3_flutter_libs depends upon sqlite3, which does not define modules` pada workflow iOS IPA.
- File penting yang diubah:
  - `ios/Podfile`
  - `.github/workflows/ios-ipa.yml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambahkan `use_modular_headers!` pada target `Runner` agar pod dependency seperti `sqlite3` dibuatkan module map dan bisa dipakai oleh Swift pod saat integrated sebagai static library.
  - Menghapus step Tcl/Tk dari workflow iOS karena log terbaru menunjukkan SQLite source sudah berhasil dibangun sampai tahap install pod; kegagalan sebenarnya ada pada validasi modular headers CocoaPods.
- Command verifikasi yang disarankan:
  - Jalankan ulang workflow `iOS IPA Build` dari GitHub Actions.

## 2026-06-05 - Non-blocking Tcl Config in iOS Workflow

- Fitur/bug: Memperbaiki workflow iOS IPA yang berhenti di step setup Tcl/Tk karena `tclConfig.sh` tidak tersedia pada runner GitHub Actions meskipun `tcl-tk@8` sudah terinstall.
- File penting yang diubah:
  - `.github/workflows/ios-ipa.yml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Step Tcl/Tk tidak lagi gagal jika `tclConfig.sh` tidak ditemukan; workflow lanjut ke `flutter build ios` agar error build sebenarnya terlihat.
  - Pencarian `tclConfig.sh` diperluas ke lokasi SDK macOS/Xcode selain prefix Homebrew.
  - `TCL_CONFIG_SH` hanya diekspor jika path valid ditemukan; environment Tcl/Tk lain tetap diset sebagai bantuan build.
- Command verifikasi yang disarankan:
  - Jalankan ulang workflow `iOS IPA Build` dari GitHub Actions.
  - Jika gagal di step `Build iOS app without signing`, buka raw log dan ambil error pertama sebelum `Process completed with exit code 1`.

## 2026-06-05 - Robust Tcl Config Lookup in iOS Workflow

- Fitur/bug: Memperbaiki step setup Tcl/Tk workflow iOS IPA yang masih berhenti setelah `tcl-tk@8 is already installed` karena lookup `tclConfig.sh` bisa mengembalikan exit code non-zero saat path fallback tidak ada.
- File penting yang diubah:
  - `.github/workflows/ios-ipa.yml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Mengganti pencarian `find` multi-path menjadi loop yang hanya memanggil `find` pada direktori yang benar-benar ada.
  - Output pencarian dibatasi dengan `head -n 1` agar `TCL_CONFIG_SH` tetap satu path.
- Command verifikasi yang disarankan:
  - Jalankan ulang workflow `iOS IPA Build` dari GitHub Actions.

## 2026-06-04 - Idempotent Tcl/Tk Install in iOS Workflow

- Fitur/bug: Memperbaiki step setup Tcl/Tk workflow iOS IPA yang gagal saat `tcl-tk@8` sudah terinstall di runner GitHub Actions.
- File penting yang diubah:
  - `.github/workflows/ios-ipa.yml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Mengubah `brew install tcl-tk@8` menjadi cek `brew list` terlebih dahulu agar step idempotent.
  - Jika `tcl-tk@8` sudah tersedia, workflow langsung memakai prefix yang ada tanpa memicu exit code non-zero dari Homebrew.
- Command verifikasi yang disarankan:
  - Jalankan ulang workflow `iOS IPA Build` dari GitHub Actions.

## 2026-06-04 - Use Tcl/Tk 8 for iOS SQLite Build

- Fitur/bug: Memperbaiki step setup Tcl/Tk pada workflow iOS IPA yang gagal karena Homebrew `tcl-tk` 9.0.3 tidak menyediakan `tclConfig.sh` di runner GitHub Actions.
- File penting yang diubah:
  - `.github/workflows/ios-ipa.yml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Mengganti install Homebrew dari `tcl-tk` ke `tcl-tk@8` agar build SQLite native memakai Tcl/Tk 8.6 yang masih menyediakan layout config legacy.
  - Menambahkan export `TCLSH_CMD` ke `tclsh8.6` dan diagnosis file jika `tclConfig.sh` tetap tidak ditemukan.
- Command verifikasi yang disarankan:
  - Jalankan ulang workflow `iOS IPA Build` dari GitHub Actions.

## 2026-06-04 - iOS SQLite Tcl Build Dependency

- Fitur/bug: Menambahkan setup Tcl/Tk pada workflow iOS IPA untuk mengatasi kegagalan build SQLite native yang berhenti setelah `sqlite-check-tcl` tidak menemukan `tclConfig.sh`.
- File penting yang diubah:
  - `.github/workflows/ios-ipa.yml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Workflow iOS sekarang meng-install `tcl-tk` via Homebrew sebelum `flutter build ios`.
  - Path `tclConfig.sh`, `TCL_LIBRARY`, `PKG_CONFIG_PATH`, `LDFLAGS`, dan `CPPFLAGS` diekspos ke environment build agar konfigurasi SQLite native dapat menemukan development config Tcl.
  - Perubahan hanya diterapkan pada workflow iOS karena error berasal dari build pods/native iOS.
- Command verifikasi yang disarankan:
  - Jalankan ulang workflow `iOS IPA Build` dari GitHub Actions.
  - Jika masih gagal, buka full raw log pada step `Build iOS app without signing` dan cari baris error pertama sebelum `Process completed with exit code 1`.

## 2026-06-04 - iOS Deployment Target 14

- Fitur/bug: Memperbaiki error `pod install` pada workflow iOS IPA karena plugin `workmanager_apple` membutuhkan minimum iOS deployment target 14.0.
- File penting yang diubah:
  - `ios/Podfile`
  - `ios/Runner.xcodeproj/project.pbxproj`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambahkan `ios/Podfile` Flutter standar dengan `platform :ios, '14.0'` agar CocoaPods tidak otomatis fallback ke iOS 13.0.
  - Menyetel `IPHONEOS_DEPLOYMENT_TARGET` Runner menjadi `14.0` pada konfigurasi Xcode project.
  - Post-install CocoaPods juga memaksa deployment target pods ke `14.0` agar plugin native konsisten.
- Command verifikasi yang disarankan:
  - Jalankan ulang workflow `iOS IPA Build` dari GitHub Actions.

## 2026-06-04 - Flutter CI Minimum for Workmanager

- Fitur/bug: Memperbaiki error dependency resolution di workflow iOS IPA karena `workmanager 0.9.0+3` membutuhkan Flutter SDK minimal `3.32.0`.
- File penting yang diubah:
  - `.github/workflows/ios-ipa.yml`
  - `.github/workflows/release.yml`
  - `pubspec.yaml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menaikkan Flutter CI dari `3.24.5` ke `3.32.0` pada workflow iOS unsigned IPA dan Android release agar memenuhi constraint dependency yang sama.
  - Menaikkan minimum Flutter project di `pubspec.yaml` menjadi `>=3.32.0` supaya environment constraint selaras dengan dependency aktual.
  - Tetap memakai versi Flutter pinned, bukan `stable` floating, agar build CI lebih reproducible.
- Command verifikasi yang disarankan:
  - Jalankan ulang workflow `iOS IPA Build` dari GitHub Actions.
  - Jika build Android release diperlukan, jalankan workflow `Release Build`.

## 2026-06-03 - GitHub Actions Flutter Patch Bump

- Fitur/bug: Memperbaiki error `flutter pub get` di GitHub Actions karena Dart SDK `3.5.0` dari Flutter `3.24.0` belum memenuhi kebutuhan `http_certificate_pinning >=3.0.0`.
- File penting yang diubah:
  - `.github/workflows/ios-ipa.yml`
  - `.github/workflows/release.yml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menaikkan Flutter CI dari `3.24.0` ke `3.24.5` agar tetap berada di seri Flutter 3.24 tetapi memakai Dart patch yang memenuhi constraint dependency.
  - Workflow iOS unsigned IPA dan workflow Android release disamakan versinya agar tidak gagal pada tahap dependency resolution yang sama.
- Command verifikasi yang disarankan:
  - Jalankan ulang workflow `iOS IPA Build` dari GitHub Actions.
  - Untuk rilis Android berikutnya, jalankan workflow `Release Build`.

## 2026-06-03 - GitHub Actions iOS Unsigned IPA Build

- Fitur/bug: Menambahkan workflow GitHub Actions manual untuk build unsigned IPA iOS yang bisa di-download lalu di-sign/install lewat tool sideload seperti Sideloadly atau AltStore.
- File penting yang diubah:
  - `.github/workflows/ios-ipa.yml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Workflow memakai runner `macos-15`, Flutter `3.24.0`, dan trigger manual `workflow_dispatch` agar biaya/kuota GitHub Actions lebih terkontrol.
  - Build dibuat dengan `flutter build ios --release --no-codesign`, lalu `Runner.app` dipaketkan manual menjadi `.ipa` unsigned dalam folder `Payload`.
  - Secret `ENV_FILE_BASE64` dipakai bila tersedia; jika tidak, workflow fallback ke `.env.example` dengan warning agar build tetap bisa dicoba.
  - Workflow menjalankan codegen di CI karena generated files tidak selalu tersedia dari checkout bersih.
- Command verifikasi yang disarankan:
  - Jalankan workflow `iOS IPA Build` dari tab GitHub Actions.
  - Download artifact `ios-unsigned-ipa-*`, lalu coba install ke iPhone via Sideloadly/AltStore.

## 2026-05-31 - Transaction Sharing, Customer Sorting, and Reports Nav

- Fitur/bug: Menambahkan tombol share struk image di detail transaksi, memindahkan Laporan ke bottom navigation utama, memindahkan Stok ke Lainnya, menambahkan sorting pelanggan berdasarkan transaksi terbaru/poin, menampilkan transaksi pelanggan di detail pelanggan, dan membuat Produk Terlaris menampilkan semua item terjual > 0.
- File penting yang diubah:
  - `lib/router.dart`
  - `lib/core/widgets/adaptive_shell.dart`
  - `lib/features/more/more_screen.dart`
  - `lib/features/transactions/transaction_detail_screen.dart`
  - `lib/core/database/daos/transaction_dao.dart`
  - `lib/features/customers/customer_providers.dart`
  - `lib/features/customers/customer_providers.g.dart`
  - `lib/features/customers/customer_list_screen.dart`
  - `lib/features/customers/customer_form_screen.dart`
  - `lib/features/reports/report_providers.dart`
  - `lib/features/reports/widgets/today_quick_badge.dart`
  - `lib/features/home/home_screen.dart`
- Keputusan teknis:
  - Share struk detail transaksi memakai `ShareReceiptUseCase.sharePaymentReceiptImage` yang sudah dipakai flow pembayaran agar format PNG struk konsisten.
  - Tab bottom navigation ketiga sekarang membuka `/reports`; route lama `/more/reports` diarahkan ke tab laporan agar shortcut lama tetap hidup.
  - Stok tersedia dari Lainnya melalui `/more/inventory`, sementara route detail/form stok existing tetap dipakai agar alur edit dan catat pergerakan tidak berubah.
  - Sorting pelanggan memakai stream tanggal transaksi completed terakhir per pelanggan; pelanggan tanpa transaksi ditempatkan di bawah saat sort terbaru.
  - Detail pelanggan membaca transaksi completed pelanggan secara reaktif, urut transaksi terakhir, dan item membuka route detail transaksi existing.
  - Aggregator laporan tidak lagi membatasi produk terlaris ke top 5; semua item dengan total qty > 0 ditampilkan.
- Command verifikasi yang disarankan:
  - `dart run build_runner build --delete-conflicting-outputs`
  - `flutter analyze`
  - Buka detail transaksi lalu tap `Share Struk` dan pastikan yang dibagikan PNG.
  - Cek bottom navigation: tab ketiga membuka Laporan, menu Stok ada di Lainnya.
  - Buka Pelanggan, coba sort `Terbaru` dan `Poin`, lalu buka detail pelanggan dan klik salah satu transaksi.
  - Buka Laporan pada periode dengan lebih dari 5 produk terjual dan pastikan semuanya tampil.

## 2026-05-30 - Share Menu Split Header and Compact Cards

- Fitur/bug: Menambahkan opsi layout header share menu satu baris dan merapatkan teks nama/harga pada card menu.
- File penting yang diubah:
  - `lib/core/database/app_database.dart`
  - `lib/features/settings/menu_image_settings.dart`
  - `lib/features/settings/menu_image_settings_screen.dart`
  - `lib/features/catalog/share_menu_image_use_case.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menaikkan schema Drift lokal ke v19 dan menambahkan kolom `menu_image_settings.header_layout` secara non-destruktif dengan default `stacked`.
  - Pengaturan > Image Menu sekarang punya pilihan layout header `Atas-bawah` atau `Logo kiri`.
  - Renderer share menu memakai layout split hanya jika logo tersedia dan ada informasi cabang; jika tidak, fallback ke layout header lama agar tidak ada ruang kosong.
  - Pada card menu, nama menu dibuat satu baris dengan ellipsis, lalu harga dirender langsung di bawah nama agar jarak kosong di tengah card berkurang.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Buka Pengaturan > Image Menu, pilih `Logo kiri`, simpan, lalu share menu dan pastikan logo di kiri serta informasi cabang di kanan.
  - Cek item menu bernama panjang agar terpotong dengan ellipsis dan harga tampil rapat di bawah nama.

## 2026-05-30 - Share Menu Phone Label

- Fitur/bug: Mengganti teks `WhatsApp:` pada nomor cabang di share menu image menjadi simbol emoji agar header lebih ringkas.
- File penting yang diubah:
  - `lib/features/catalog/share_menu_image_use_case.dart`
  - `lib/features/settings/menu_image_settings_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menggunakan emoji phone pada hasil render share menu dan preview Pengaturan > Image Menu.
  - Tidak mengubah sumber data nomor cabang atau toggle visibility nomor cabang.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Share menu dan cek header nomor cabang tampil dengan emoji, bukan label `WhatsApp:`.

## 2026-05-30 - Share Menu Logo Scaling

- Fitur/bug: Memperbesar dan membuat area logo pada share menu image ikut proporsional terhadap lebar image yang dipilih.
- File penting yang diubah:
  - `lib/features/catalog/share_menu_image_use_case.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Area logo tidak lagi memakai ukuran kecil tetap `380x172` pada layout dasar.
  - Lebar logo sekarang dihitung dari lebar konten menu, lalu tetap ikut `canvas.scale` berdasarkan setting `image_width_px`.
  - Tinggi header dinaikkan saat logo dan teks cabang tampil bersama agar logo besar tidak menabrak nama/alamat/nomor cabang.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Share menu dengan lebar image `3240` dan `4096`, lalu pastikan logo terlihat lebih besar dan tetap tajam sesuai kualitas file logo sumber.

## 2026-05-30 - Configurable Share Menu Image Resolution

- Fitur/bug: Menambahkan pengaturan lebar pixel untuk share menu image agar hasil PNG bisa dibuat lebih tajam saat di-zoom.
- File penting yang diubah:
  - `lib/core/database/app_database.dart`
  - `lib/features/settings/menu_image_settings.dart`
  - `lib/features/settings/menu_image_settings_screen.dart`
  - `lib/features/catalog/share_menu_image_use_case.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menaikkan schema Drift lokal ke v18 dan menambahkan kolom `menu_image_settings.image_width_px` secara non-destruktif dengan default `3240`.
  - Input lebar image ditambahkan di Pengaturan > Image Menu, divalidasi pada rentang `1080-4096` px untuk menjaga kualitas tanpa membuat render terlalu berat.
  - Renderer tetap memakai layout logis 2160px, lalu menskalakan canvas ke `image_width_px` saat membuat PNG supaya teks/shape dirender ulang lebih tajam, bukan sekadar resize bitmap akhir.
  - Nama file share menu menyertakan resolusi width untuk memudahkan pengecekan hasil.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Buka Pengaturan > Image Menu, set lebar image ke `3240` atau `4096`, simpan, lalu share menu dan cek dimensi/ketajaman PNG.

## 2026-05-30 - Share Menu Image Settings

- Fitur/bug: Menambahkan pengaturan share menu image dan meningkatkan resolusi hasil PNG agar lebih jelas saat di-zoom.
- File penting yang diubah:
  - `lib/core/database/app_database.dart`
  - `lib/features/settings/menu_image_settings.dart`
  - `lib/features/settings/menu_image_settings_screen.dart`
  - `lib/features/settings/settings_screen.dart`
  - `lib/router.dart`
  - `lib/features/catalog/share_menu_image_use_case.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambahkan tabel lokal `menu_image_settings` via migrasi Drift schema v17 dengan `CREATE TABLE IF NOT EXISTS`, sehingga non-destruktif dan tidak membutuhkan generate file Drift.
  - Pengaturan disimpan per cabang: tampil/sembunyi nama cabang, alamat cabang, nomor cabang, jumlah card per baris 2/3, dan warna background hex `#RRGGBB`.
  - Layar `Image Menu` ditambahkan di menu Pengaturan dengan preview sederhana, preset warna, validasi hex, dan submit prevention saat menyimpan.
  - Share menu image membaca pengaturan per cabang sebelum render, lalu memakai canvas 2160px wide agar hasil PNG lebih tajam saat diperbesar.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Buka Pengaturan > Image Menu, ubah toggle/header/kolom/warna, simpan, lalu share menu dari layar Menu.
  - Zoom hasil PNG dan pastikan gambar lebih jelas serta setting yang tersimpan ikut diterapkan.

## 2026-05-30 - App Version Bump 0.10.0

- Fitur/bug: Menaikkan minor version dan build number untuk rilis berikutnya.
- File penting yang diubah:
  - `pubspec.yaml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Semantic minor version dinaikkan dari `0.9.1` ke `0.10.0`.
  - Build number dinaikkan dari `11` ke `12`.
- Command verifikasi yang disarankan:
  - `flutter build apk --release`

## 2026-05-30 - Share Available Menu Image

- Fitur/bug: Menambahkan fitur share semua menu tersedia dari layar Menu sebagai satu image PNG.
- File penting yang diubah:
  - `lib/features/catalog/catalog_screen.dart`
  - `lib/features/catalog/share_menu_image_use_case.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Tombol share PNG ditambahkan di AppBar layar Menu dan memakai loading state agar tidak bisa ditap berulang saat image sedang dibuat.
  - Data yang masuk image hanya menu available untuk cabang aktif (`branch_products.is_available = true`) dan produk aktif (`products.is_active = true`).
  - Header image memakai logo dari `receipt_settings.logo_url`, nama cabang, alamat cabang, dan nomor WhatsApp dari `branches.phone`.
  - Layout menu memakai grid 3 kolom per baris, berisi foto produk, nama produk, dan harga efektif cabang setelah override/diskon aktif.
  - Image produk dan logo diambil dari URL dengan cache in-memory; jika gambar gagal dimuat, item tetap dirender dengan placeholder.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Buka layar Menu, tap share PNG, lalu pastikan image berisi logo/header cabang dan semua menu available dalam grid 3 kolom.

## 2026-05-30 - POS Search Focus After Add Item

- Fitur/bug: Memastikan keyboard pencarian menu tidak muncul kembali otomatis setelah kasir menambahkan produk ke keranjang.
- File penting yang diubah:
  - `lib/features/pos/widgets/menu_grid.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Jalur tambah menu sekarang memakai helper `FocusManager.instance.primaryFocus?.unfocus()` agar tidak bergantung pada `BuildContext` tertentu.
  - Unfocus dipanggil sebelum proses tambah item, setelah bottom sheet modifier ditutup, dan post-frame setelah state cart berubah untuk menangani restore focus saat rebuild.
  - Query pencarian tidak dihapus; hanya fokus keyboard yang dilepas supaya kasir tetap bisa melanjutkan dari hasil filter yang sama.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Di layar kasir, tap field `Cari menu...`, tambahkan produk tanpa modifier dan dengan modifier, lalu pastikan keyboard tidak muncul kembali setelah produk masuk keranjang.

## 2026-05-30 - Share Receipt Image Layout Parity

- Fitur/bug: Merapikan tampilan image share struk agar lebih mirip hasil cetak struk, termasuk logo, teks header/footer center, baris item, total, dan pembayaran/tagihan.
- File penting yang diubah:
  - `lib/features/pos/share_receipt_use_case.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Share struk sekarang membangun `ReceiptPayload` yang sama bentuknya dengan cetak struk agar struktur data konsisten.
  - Logo struk ikut diambil dari receipt setting dengan cache in-memory dan dirender di posisi `top` atau `bottom` sesuai setting.
  - QRIS statis ikut dirender pada share struk pembayaran QRIS jika setting cetak QRIS aktif, mengikuti behavior cetak struk.
  - Renderer PNG dibuat layout-aware: header/footer center, key-value kanan-kiri, separator visual, item/modifier/catatan wrapped, total ditebalkan, dan baris pajak mengikuti hasil cetak struk.
  - Memperbaiki tipe hasil perhitungan ukuran image logo/QRIS agar lolos strict analyzer (`double`, bukan `num`).
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Share struk pembayaran dan tagihan dari device; pastikan logo muncul, header/footer center, item dan total rapi, serta tampilannya mendekati struk cetak.

## 2026-05-30 - App Version Bump 0.9.0

- Fitur/bug: Menaikkan minor version dan build number untuk rilis berikutnya.
- File penting yang diubah:
  - `pubspec.yaml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Semantic minor version dinaikkan dari `0.8.0` ke `0.9.0`.
  - Build number dinaikkan dari `9` ke `10`.
- Command verifikasi yang disarankan:
  - `flutter build apk --release`

## 2026-05-30 - Share Receipt as Image

- Fitur/bug: Share struk pembayaran sekarang membagikan PNG image, dan struk tagihan di keranjang punya tombol share.
- File penting yang diubah:
  - `lib/features/pos/share_receipt_use_case.dart`
  - `lib/features/pos/widgets/receipt_summary_sheet.dart`
  - `lib/features/pos/widgets/cart_panel.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Konten struk dirender ke PNG via `Canvas` lalu dibagikan memakai `Share.shareXFiles`.
  - Renderer image memakai format thermal receipt sederhana dengan wrapping teks agar item/modifier/catatan panjang tetap masuk gambar.
  - Share pembayaran membangun konten dari transaksi tersimpan, termasuk setting visibility, loyalty point, modifier default filtering, dan rekening transfer.
  - Share tagihan membangun konten dari cart aktif, memakai preview nomor transaksi yang sama polanya dengan cetak tagihan.
  - Tombol share tagihan dibuat icon-only di baris aksi keranjang agar tetap hemat ruang bersama `Cetak Tagihan` dan `Tahan Pesanan`.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Checkout transaksi lalu tap share struk; pastikan yang terkirim berupa PNG dan isinya sesuai struk.
  - Dari keranjang, tap share tagihan dan pastikan image tagihan berisi item, modifier non-default, total, dan footer tagihan.

## 2026-05-30 - App Version Bump 0.8.0

- Fitur/bug: Menaikkan minor version dan build number untuk rilis berikutnya.
- File penting yang diubah:
  - `pubspec.yaml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Semantic minor version dinaikkan dari `0.7.0` ke `0.8.0`.
  - Build number dinaikkan dari `8` ke `9`.
- Command verifikasi yang disarankan:
  - `flutter build apk --release`

## 2026-05-30 - Compact Cart Actions and Zero Tax

- Fitur/bug: Merapikan area bawah keranjang agar tombol `Cetak Tagihan` dan `Tahan Pesanan` berada dalam satu baris, serta menyembunyikan baris pajak saat nominal pajak 0.
- File penting yang diubah:
  - `lib/features/pos/widgets/cart_panel.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Dua tombol sekunder memakai `Row` + `Expanded` agar tetap responsif dan tidak menambah tinggi panel.
  - Baris `Pajak` hanya ditampilkan jika `TotalsResult.taxAmount > 0`; total tetap memakai hasil perhitungan yang sama.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Buka layar kasir dengan cabang pajak 0 dan pajak > 0, lalu pastikan baris pajak hanya tampil saat ada nominal pajak.
  - Cek layar keranjang di device sempit untuk memastikan tombol `Cetak Tagihan` dan `Tahan Pesanan` tetap muat satu baris.

## 2026-05-30 - Cart Modifier Edit Button

- Fitur/bug: Menambahkan tombol kecil modifier pada item keranjang untuk produk yang memiliki option group, termasuk saat belum ada modifier yang dipilih.
- File penting yang diubah:
  - `lib/features/pos/widgets/cart_panel.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - `_CartItemTile` dibuat sebagai `ConsumerWidget` agar bisa membaca `productOptionGroupsProvider(product.id)`.
  - Tombol tetap memakai area ringkas dengan ikon tune; jika belum ada pilihan tampil sebagai `Modifier`, jika sudah ada tetap menampilkan ringkasan pilihan.
  - Alur edit tetap memakai `OptionPickerSheet` dan `CartNotifier.updateOptions`, sehingga pricing cart tetap dihitung dari state yang sama.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Tambahkan produk yang punya option group ke keranjang tanpa mengubah modifier, lalu tap tombol `Modifier` dan pastikan pilihan bisa disimpan.

## 2026-05-30 - POS Search Keyboard Dismiss

- Fitur/bug: Keyboard pencarian menu kasir ditutup saat kasir memilih filter, mengganti mode tampilan, atau menambahkan menu.
- File penting yang diubah:
  - `lib/features/pos/widgets/menu_grid.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Memakai `FocusScope.of(context).unfocus()` pada interaksi di luar field cari agar layar menu kembali lega setelah pencarian.
  - Perubahan hanya menyentuh behavior fokus keyboard; state query, filter tersimpan, dan alur tambah modifier tetap sama.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Buka layar kasir di device, tap field `Cari menu...`, lalu tap filter/menu dan pastikan keyboard tertutup.

## 2026-05-30 - Hide Default Modifiers on Receipts

- Fitur/bug: Modifier yang merupakan pilihan default tidak lagi dicetak pada struk/tagihan/share struk.
- File penting yang diubah:
  - `lib/features/pos/receipt_modifier_filter.dart`
  - `lib/features/pos/print_receipt_use_case.dart`
  - `lib/features/pos/share_receipt_use_case.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Data transaksi tetap menyimpan semua modifier sebagai snapshot; penyaringan hanya dilakukan saat membangun output struk.
  - Default modifier dibaca dari master `options.is_default` dan dibandingkan berdasarkan nama grup + nama opsi yang dinormalisasi, agar snapshot lama yang belum menyimpan ID/default flag tetap bisa difilter.
  - Berlaku untuk cetak struk transaksi, cetak tagihan dari cart, dan teks share struk.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Buat produk dengan modifier default `Gula: Normal`, cetak tagihan/struk tanpa mengubah pilihan dan pastikan modifier tidak tampil.
  - Pilih `Gula: Less`, checkout, lalu cetak/share struk dan pastikan modifier tersebut tampil.

## 2026-05-27 - Supabase Seed Catalog Cleanup

- Fitur/bug: Update `supabase/seed.sql` untuk menghapus seed master catalog product dan branch product, lalu menambahkan seed kategori produk awal.
- File penting yang diubah:
  - `supabase/seed.sql`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Tidak lagi mengisi `products` dan `branch_products` dari seed Supabase agar master catalog production bisa dimigrasikan/import secara eksplisit.
  - Menambahkan kategori `Makanan` dan `Minuman` ke tabel `categories` dengan `ON CONFLICT (id) DO UPDATE` agar seed idempotent.
  - Mengisi `created_at` dan `updated_at` karena kolom kategori bersifat `NOT NULL`.
- Command verifikasi yang disarankan:
  - `supabase db reset`
  - Jalankan query `select id, name, sort_order from public.categories order by sort_order, name;`

## 2026-05-27 - Supabase Seed Makanan Products

- Fitur/bug: Menambahkan seed master product kategori `Makanan` berdasarkan screenshot POS lama.
- File penting yang diubah:
  - `supabase/seed.sql`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Seed produk dibuat idempotent dengan `ON CONFLICT (id) DO UPDATE`.
  - Produk kategori `Makanan` otomatis dimasukkan ke `branch_products` untuk semua branch aktif agar langsung tampil di menu POS yang membaca join `products` dan `branch_products`.
  - Item duplikat antar screenshot tidak diulang.
  - Nama `Gorengan Mix (Gehu Pedas, Tempe Mendoan)` diambil dari screenshot yang terpotong pada teks `Tem...` dan konteks item `Tempe Mendoan`.
- Command verifikasi yang disarankan:
  - `supabase db reset`
  - Jalankan query `select name, base_price from public.products where category = 'Makanan' order by name;`
  - Jalankan query `select count(*) from public.branch_products;`

## 2026-05-27 - Supabase Seed Minuman Products

- Fitur/bug: Menambahkan seed master product kategori `Minuman` berdasarkan screenshot POS lama.
- File penting yang diubah:
  - `supabase/seed.sql`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Seed produk `Minuman` menggunakan rentang UUID stabil `00000000-0000-0000-0000-000000000300` sampai `00000000-0000-0000-0000-000000000317`.
  - Produk `Minuman` dibuat idempotent dengan `ON CONFLICT (id) DO UPDATE`.
  - Insert `branch_products` diperluas agar produk kategori `Makanan` dan `Minuman` otomatis tersedia di semua branch aktif.
  - Item yang muncul ulang antar screenshot, seperti `Strawberry Shore` dan `Lychee Lust`, tidak diduplikasi.
- Command verifikasi yang disarankan:
  - `supabase db reset`
  - Jalankan query `select name, base_price from public.products where category = 'Minuman' order by name;`
  - Jalankan query `select category, count(*) from public.products group by category order by category;`

## 2026-05-27 - Supabase Seed Option Groups

- Fitur/bug: Menambahkan seed option group dan pilihan berdasarkan screenshot POS lama.
- File penting yang diubah:
  - `supabase/seed.sql`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambahkan option group `Bumbu Kentang Goreng`, `Gula`, `Espresso`, dan `Upsize`.
  - Menambahkan pilihan beserta `price_delta` sesuai screenshot.
  - Semua seed dibuat idempotent dengan `ON CONFLICT (id) DO UPDATE`.
  - `is_required`, `is_multi_select`, dan `is_default` diset `FALSE` karena screenshot hanya menunjukkan master varian/pilihan aktif, bukan aturan wajib pilih, multi-select, atau default di schema aplikasi ini.
  - Belum menambahkan mapping `product_option_groups` karena screenshot tidak menunjukkan produk mana yang memakai tiap option group.
- Command verifikasi yang disarankan:
  - `supabase db reset`
  - Jalankan query `select name, is_required, is_multi_select from public.option_groups order by sort_order, name;`
  - Jalankan query `select og.name as group_name, o.name, o.price_delta from public.options o join public.option_groups og on og.id = o.group_id order by og.sort_order, o.sort_order;`

## 2026-05-27 - Supabase Seed Option Group Adjustments

- Fitur/bug: Menyesuaikan seed option group untuk kebutuhan varian tambahan.
- File penting yang diubah:
  - `supabase/seed.sql`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambahkan option `None` harga `0` pada group `Gula`.
  - Melengkapi option group `Upsize` dengan pilihan `1000` sampai `9000`, masing-masing `price_delta` mengikuti nama nominal.
  - Menambahkan option group `Pedas` dengan pilihan `Normal`, `Extra`, `Less`, dan `None`.
  - `Extra` pada group `Pedas` mengikuti pola `Gula`, yaitu `price_delta = 2000`.
  - Seed tetap idempotent via `ON CONFLICT (id) DO UPDATE`; beberapa ID option pada rentang `000000000417` sampai `000000000420` sengaja di-update agar urutan baru konsisten.
- Command verifikasi yang disarankan:
  - `supabase db reset`
  - Jalankan query `select og.name as group_name, o.name, o.price_delta from public.options o join public.option_groups og on og.id = o.group_id where og.name in ('Gula', 'Upsize', 'Pedas') order by og.sort_order, o.sort_order;`

## 2026-05-27 - Receipt Customer Phone Masking

- Fitur/bug: Menambahkan nomor telepon pelanggan termasking pada label pelanggan di struk.
- File penting yang diubah:
  - `lib/features/pos/print_receipt_use_case.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Format label pelanggan dibuat di `PrintReceiptUseCase` agar berlaku untuk struk transaksi/reprint dan cetak tagihan.
  - Nomor telepon dibersihkan menjadi digit saja, lalu ditampilkan 3 digit pertama dan 3 digit terakhir; digit tengah diganti `*`.
  - Jika pelanggan tidak punya nomor telepon, struk tetap hanya menampilkan nama pelanggan.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - `flutter test`

## 2026-05-27 - Receipt Visibility Toggles

- Fitur/bug: Menambahkan toggle setting struk untuk mengatur apakah nama pelanggan dan nama cabang dicetak.
- File penting yang diubah:
  - `supabase/migrations/20260527100000_receipt_visibility_toggles.sql`
  - `lib/core/database/tables/settings_tables.dart`
  - `lib/core/database/app_database.dart`
  - `lib/core/database/app_database.g.dart`
  - `lib/core/sync/sync_dtos.dart`
  - `lib/core/services/printer_service.dart`
  - `lib/core/services/escpos_receipt_builder.dart`
  - `lib/features/pos/print_receipt_use_case.dart`
  - `lib/features/settings/receipt_settings_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambahkan kolom `show_customer_name` dan `show_branch_name` pada `receipt_settings` dengan default `true` agar output struk existing tetap sama.
  - Menaikkan schema Drift lokal ke versi 13 dan menambahkan migrasi non-destruktif untuk dua kolom baru.
  - Toggle disimpan per cabang dan ikut sync melalui DTO Supabase.
  - `show_customer_name = false` membuat baris `Pelanggan` tidak dicetak walaupun transaksi punya pelanggan.
  - `show_branch_name = false` hanya menyembunyikan nama cabang; alamat/telepon cabang tetap mengikuti konfigurasi struk saat ini.
- Command verifikasi yang disarankan:
  - `dart run build_runner build --delete-conflicting-outputs`
  - `flutter analyze`
  - `flutter test`

## 2026-05-27 - POS Menu Grid and Detail View Modes

- Fitur/bug: Menambahkan opsi tampilan menu kasir antara mode grid dan mode detail dengan foto kecil.
- File penting yang diubah:
  - `lib/features/pos/widgets/menu_grid.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Mode grid tetap menjadi default agar perilaku existing tidak berubah.
  - Mode detail memakai `ListView.separated` dengan tinggi row tetap `88` dan foto produk `64x64` agar lebih banyak produk tampil dalam satu layar.
  - Search dan kategori tetap memakai alur filtering yang sama untuk kedua mode.
  - Aksi tap/tambah produk diekstrak ke helper bersama agar flow modifier tetap konsisten antara grid dan detail.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - `flutter test`

## 2026-05-27 - Local Drift Seed Audit

- Fitur/bug: Audit seed lokal Drift untuk memastikan master product tidak diisi dari aplikasi.
- File penting yang diubah:
  - `lib/main.dart`
  - `supabase/seed.sql`
  - `lib/features/settings/branch_selection_provider.dart`
  - `lib/features/pos/checkout_use_case.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Tidak ada `SeedService`/`ensureSeeded` aktif di startup aplikasi; Drift dipakai sebagai local cache.
  - Data pertama setelah login dipull dari Supabase lewat `Bootstrap.run()` dan `SyncRepository.pullMasterData()`.
  - Komentar lama yang masih menyebut in-app seed dibersihkan agar tidak membingungkan saat production migration.
  - Seed yang tersisa hanya `supabase/seed.sql`, helper test, dan migrasi kategori lokal dari produk existing saat upgrade ke schema v12.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - `flutter test`

## 2026-05-27 - Android Network and Backup Settings

- Fitur/bug: Menambahkan permission internet pada manifest utama Android dan menonaktifkan Android app backup.
- File penting yang diubah:
  - `android/app/src/main/AndroidManifest.xml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - `INTERNET` dipasang di manifest utama agar build release bisa mengakses Supabase, tidak hanya debug/profile.
  - `android:allowBackup="false"` dan `android:fullBackupContent="false"` dipasang untuk mencegah restore otomatis database Drift/session lama setelah uninstall/install ulang.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Build APK release lalu install ulang di device setelah clear data/uninstall.

## 2026-05-28 - Sync Outbox Dependency Ordering

- Fitur/bug: Memperbaiki sync transaksi yang gagal saat transaksi baru mereferensikan customer baru yang belum terkirim ke Supabase.
- File penting yang diubah:
  - `lib/core/sync/sync_repository.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Push outbox sekarang diurutkan berdasarkan prioritas dependency sehingga record referensi seperti customer dan bank account diproses sebelum transaksi.
  - Batch pending outbox dinaikkan dari 20 ke 100 agar transaksi gagal yang menumpuk tidak mudah menahan record referensi yang lebih baru.
  - `_pushTransaction` tetap melakukan guard eksplisit dengan mengirim customer dan bank account terkait sebelum upsert transaksi, sehingga retry transaksi lama tetap bisa pulih walaupun urutan outbox sebelumnya sudah telanjur salah.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - `flutter test`

## 2026-05-28 - App Version Bump

- Fitur/bug: Menaikkan versi aplikasi untuk rilis berikutnya.
- File penting yang diubah:
  - `pubspec.yaml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Semantic minor version dinaikkan dari `0.1.0` ke `0.2.0`.
  - Build number dinaikkan dari `1` ke `2`.
- Command verifikasi yang disarankan:
  - `flutter build apk --release`

## 2026-05-28 - Held Order List Preview and Checkout Lifecycle

- Fitur/bug: Enhance daftar pesanan tertahan dan memperbaiki lifecycle hapus hold order.
- File penting yang diubah:
  - `lib/features/pos/held_order_service.dart`
  - `lib/features/pos/cart_provider.dart`
  - `lib/features/pos/widgets/held_orders_sheet.dart`
  - `lib/features/pos/widgets/checkout_sheet.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Daftar hold order sekarang menampilkan label, nama item pertama dengan ellipsis, waktu, dan total nominal transaksi.
  - Total preview dihitung dari snapshot payload hold order, termasuk modifier dan diskon manual, lalu memakai setting pajak cabang saat ini.
  - Payload hold order baru menyimpan `productName` sebagai snapshot agar preview lebih cepat; payload lama tetap didukung dengan fallback resolve produk dari Drift.
  - Restore hold order tidak lagi langsung menghapus row hold. Row ditandai sebagai active held order dan baru dihapus setelah checkout berhasil.
  - Penanda active held order dibersihkan saat keranjang dikosongkan agar cart baru tidak menghapus hold order lama secara keliru.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - `flutter test`

## 2026-05-28 - Runtime App Version Metadata

- Fitur/bug: Menghapus hardcode versi dan build number pada informasi aplikasi di Settings.
- File penting yang diubah:
  - `pubspec.yaml`
  - `pubspec.lock`
  - `lib/core/config/app_constants.dart`
  - `lib/features/settings/about_app_screen.dart`
  - `lib/features/settings/settings_screen.dart`
  - `lib/features/settings/telemetry_provider.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambahkan dependency `package_info_plus` agar versi dan build number dibaca dari metadata package runtime yang dihasilkan dari `pubspec.yaml` saat build.
  - Layar `Tentang Aplikasi`, ringkasan About di Settings, dan Telemetry sekarang membaca `PackageInfo.fromPlatform()`.
  - Konstanta `appVersion` dan `appBuildNumber` dihapus supaya tidak ada sumber versi kedua yang mudah stale.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --release`

## 2026-05-28 - Receipt Bottom Feed Trim

- Fitur/bug: Mengurangi space kosong di ujung bawah struk cetak, terutama saat nama cabang tidak dicetak.
- File penting yang diubah:
  - `lib/core/services/escpos_receipt_builder.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Feed sebelum perintah cut dikurangi dari 2 baris menjadi 1 baris agar panjang struk lebih mengikuti data yang dicetak.
  - Struktur konten struk tidak diubah; hanya margin bawah sebelum potong kertas yang dirapikan.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Cetak struk dengan toggle nama cabang ON dan OFF untuk membandingkan margin bawah.

## 2026-05-28 - Customer Picker Auto-Select New Customer

- Fitur/bug: Memperbaiki alur tambah pelanggan baru dari keranjang agar pelanggan yang baru dibuat langsung terpilih di cart.
- File penting yang diubah:
  - `lib/features/customers/customer_form_screen.dart`
  - `lib/features/customers/customer_picker_sheet.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Form pelanggan sekarang mengembalikan `CustomerRow` yang berhasil disimpan melalui `Navigator.pop(savedCustomer)`.
  - Customer picker membuka form pelanggan sebagai fullscreen dialog di atas bottom sheet, lalu menutup picker dengan `CustomerPick(created)` saat customer baru berhasil dibuat.
  - Alur tambah pelanggan dari daftar pelanggan tetap aman karena caller yang tidak menunggu result akan mengabaikan nilai balik tersebut.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - `flutter test`

## 2026-05-28 - Share Receipt Action

- Fitur/bug: Menambahkan tombol share struk pada ringkasan pembayaran agar struk bisa dibagikan lewat WhatsApp atau aplikasi chat lain.
- File penting yang diubah:
  - `pubspec.yaml`
  - `pubspec.lock`
  - `lib/features/pos/share_receipt_use_case.dart`
  - `lib/features/pos/widgets/receipt_summary_sheet.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambahkan dependency `share_plus` untuk membuka share sheet sistem.
  - Tombol share dibuat icon-only di sebelah kanan tombol `Cetak Struk`, sementara tombol `Transaksi Baru` dipindah ke baris bawah agar tombol cetak tetap lebih lebar.
  - Teks share dibangun ulang dari transaksi tersimpan di Drift, termasuk item, modifier, total, metode bayar, customer, kasir, serta setting visibility nama cabang/nama pelanggan.
  - Format share berupa teks plain agar kompatibel dengan WhatsApp dan aplikasi chat lain tanpa membutuhkan file gambar/PDF.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - `flutter test`
  - Coba share struk dari Android ke WhatsApp atau aplikasi chat lain.

## 2026-05-28 - App Version Bump 0.3.0

- Fitur/bug: Menaikkan versi aplikasi untuk rilis berikutnya.
- File penting yang diubah:
  - `pubspec.yaml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Semantic minor version dinaikkan dari `0.2.0` ke `0.3.0`.
  - Build number dinaikkan dari `2` ke `3`.
- Command verifikasi yang disarankan:
  - `flutter build apk --release`

## 2026-05-28 - Sync Timestamp Normalization and SQLite Lock Handling

- Fitur/bug: Memperbaiki risiko tanggal transaksi bergeser karena timestamp local dikirim ke Supabase tanpa offset, serta mengurangi error `database is locked` saat sync dan read berjalan bersamaan.
- File penting yang diubah:
  - `lib/core/sync/sync_dtos.dart`
  - `lib/core/database/app_database.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Semua timestamp yang dipush ke Supabase sekarang dikonversi ke UTC ISO-8601 eksplisit melalui helper `_toSupabaseTimestamp`.
  - Semua timestamp yang dipull dari Supabase diparse melalui `_fromSupabaseTimestamp` lalu dikembalikan ke local time perangkat sebelum disimpan/dipakai aplikasi.
  - Helper parse timestamp menerima `Object?` dengan guard null agar cocok dengan strict analyzer saat membaca `Map<String, dynamic>` dari Supabase.
  - Database SQLite production dibuka dengan `PRAGMA busy_timeout = 5000` dan `PRAGMA journal_mode = WAL` agar read/write lebih tahan terhadap lock singkat saat sync.
  - Tidak ada migrasi schema; data transaksi lama yang sudah terlanjur salah timestamp tetap perlu koreksi data terpisah jika ingin diperbaiki historinya.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - `flutter test`
  - Buat transaksi baru di device pada sore/malam hari, sinkronkan, lalu buka detail transaksi dan pastikan tanggal/jam tetap sesuai waktu lokal perangkat.

## 2026-05-28 - App Version Bump 0.3.1

- Fitur/bug: Menaikkan revision/patch version dan build number untuk rilis bugfix timestamp sync.
- File penting yang diubah:
  - `pubspec.yaml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Semantic patch version dinaikkan dari `0.3.0` ke `0.3.1`.
  - Build number dinaikkan dari `3` ke `4`.
- Command verifikasi yang disarankan:
  - `flutter build apk --release`

## 2026-05-28 - Human-Readable Transaction Number

- Fitur/bug: Menambahkan nomor transaksi bisnis yang lebih mudah dibaca owner/kasir.
- File penting yang diubah:
  - `supabase/migrations/20260528194000_transaction_number.sql`
  - `lib/core/database/tables/transaction_tables.dart`
  - `lib/core/database/app_database.dart`
  - `lib/core/sync/sync_dtos.dart`
  - `lib/features/pos/checkout_use_case.dart`
  - `lib/features/transactions/transaction_list_screen.dart`
  - `lib/features/transactions/transaction_detail_screen.dart`
  - `lib/features/pos/print_receipt_use_case.dart`
  - `lib/features/pos/share_receipt_use_case.dart`
  - `lib/features/pos/widgets/receipt_summary_sheet.dart`
  - `lib/core/services/printer_service.dart`
  - `lib/core/services/escpos_receipt_builder.dart`
  - `lib/core/services/fakes/fake_printer_service.dart`
  - `lib/core/utils/transaction_numbers.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - UUID v7 tetap menjadi primary key dan idempotency key sync.
  - Kolom baru `transaction_number` dibuat nullable agar data lama dan void transaction tetap aman dengan fallback ke short UUID.
  - Format nomor baru adalah `YYMMDDHHMI-XXX`, dengan `XXX` dihitung dari jumlah transaksi original pada cabang dan tanggal lokal yang sama + 1.
  - Supabase memakai unique partial index `(branch_id, transaction_number)` saat `transaction_number is not null`.
  - UI list/detail, struk print, fake printer, share receipt, dan receipt summary menampilkan `transaction_number` bila tersedia.
- Command verifikasi yang disarankan:
  - `dart run build_runner build --delete-conflicting-outputs`
  - `flutter analyze`
  - `flutter test`
  - Buat beberapa transaksi pada cabang yang sama dan pastikan nomor berurutan seperti `2605281930-001`, `2605281931-002`.

## 2026-05-29 - App Version Bump 0.4.0

- Fitur/bug: Menaikkan minor version dan build number untuk rilis berikutnya.
- File penting yang diubah:
  - `pubspec.yaml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Semantic minor version dinaikkan dari `0.3.1` ke `0.4.0`.
  - Build number dinaikkan dari `4` ke `5`.
- Command verifikasi yang disarankan:
  - `flutter build apk --release`

## 2026-05-29 - Loyalty Point Ledger

- Fitur/bug: Mengimplementasikan loyalty point pelanggan berbasis transaksi.
- File penting yang diubah:
  - `supabase/migrations/20260529090000_customer_point_ledger.sql`
  - `lib/core/database/tables/customer_point_ledger_table.dart`
  - `lib/core/database/daos/customer_point_ledger_dao.dart`
  - `lib/core/database/app_database.dart`
  - `lib/core/database/daos/dao_providers.dart`
  - `lib/core/domain/enums.dart`
  - `lib/core/sync/sync_dtos.dart`
  - `lib/core/sync/sync_repository.dart`
  - `lib/features/pos/checkout_use_case.dart`
  - `lib/features/transactions/void_transaction_use_case.dart`
  - `lib/features/transactions/transaction_providers.dart`
  - `lib/features/transactions/transaction_detail_screen.dart`
  - `lib/features/pos/print_receipt_use_case.dart`
  - `lib/features/pos/share_receipt_use_case.dart`
  - `lib/features/pos/widgets/receipt_summary_sheet.dart`
  - `lib/core/services/printer_service.dart`
  - `lib/core/services/escpos_receipt_builder.dart`
  - `lib/core/services/fakes/fake_printer_service.dart`
  - `lib/features/settings/outbox_queue_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Rule earn awal: `1 poin` per `Rp10.000` dari total transaksi, menggunakan pembulatan floor.
  - Transaksi tanpa pelanggan tidak mendapatkan poin.
  - Poin disimpan append-only di `customer_point_ledger`; `customers.loyalty_points` tetap menjadi cached balance untuk UI dan ikut sync.
  - Checkout menambah ledger `earn`, menaikkan saldo pelanggan lokal, dan mengirim ledger melalui outbox `customerPointLedger`.
  - Void transaksi membuat ledger `void_reversal`, menurunkan saldo pelanggan lokal sampai minimum 0, dan ikut sync.
  - Struk print, share receipt, receipt summary, dan detail transaksi menampilkan poin transaksi bila ada.
- Command verifikasi yang disarankan:
  - `dart run build_runner build --delete-conflicting-outputs`
  - `flutter analyze`
  - `flutter test`
  - Buat transaksi pelanggan `Rp9.999`, `Rp10.000`, dan `Rp25.000`; pastikan poin masing-masing `0`, `1`, dan `2`.
  - Void transaksi yang mendapatkan poin dan pastikan saldo pelanggan berkurang kembali.

## 2026-05-29 - Bill Receipt Transaction Number Preview

- Fitur/bug: Memperbaiki struk tagihan agar tidak lagi menampilkan short UUID sebagai nomor transaksi.
- File penting yang diubah:
  - `lib/features/pos/print_receipt_use_case.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Cetak tagihan sekarang mengisi `ReceiptPayload.transactionNumber` dengan format `YYMMDDHHMI-XXX`.
  - Nomor antrian tagihan dihitung sebagai preview dari jumlah transaksi original pada cabang dan tanggal lokal yang sama + 1.
  - `transactionId` sementara tetap UUID untuk kebutuhan payload internal, tetapi tidak lagi dipakai sebagai nomor display ketika `transactionNumber` tersedia.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Cetak tagihan dari keranjang dan pastikan baris `No:` memakai format seperti `2605291030-001`, bukan short UUID.

## 2026-05-29 - App Version Bump 0.5.0

- Fitur/bug: Menaikkan minor version dan build number untuk rilis berikutnya.
- File penting yang diubah:
  - `pubspec.yaml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Semantic minor version dinaikkan dari `0.4.0` ke `0.5.0`.
  - Build number dinaikkan dari `5` ke `6`.
- Command verifikasi yang disarankan:
  - `flutter build apk --release`

## 2026-05-29 - Receipt Loyalty Points Toggle

- Fitur/bug: Menambahkan toggle pengaturan struk untuk menampilkan atau menyembunyikan poin loyalti pelanggan.
- File penting yang diubah:
  - `supabase/migrations/20260529152000_receipt_loyalty_points_toggle.sql`
  - `lib/core/database/tables/settings_tables.dart`
  - `lib/core/database/app_database.dart`
  - `lib/core/database/app_database.g.dart`
  - `lib/core/sync/sync_dtos.dart`
  - `lib/features/pos/print_receipt_use_case.dart`
  - `lib/features/pos/share_receipt_use_case.dart`
  - `lib/features/settings/receipt_settings_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menambahkan kolom `receipt_settings.show_loyalty_points` dengan default `true` agar struk existing tetap menampilkan poin sampai owner mematikannya.
  - Menaikkan schema Drift lokal ke versi 16 dan menambahkan migrasi non-destruktif untuk kolom baru.
  - Toggle disimpan per cabang dan ikut sync melalui DTO Supabase.
  - Saat toggle off, baris poin loyalti tidak dicetak pada struk pembayaran dan tidak muncul pada teks share struk; ringkasan pembayaran internal tetap menampilkan poin sebagai feedback kasir.
- Command verifikasi yang disarankan:
  - `dart run build_runner build --delete-conflicting-outputs`
  - `flutter analyze`
  - `flutter test`
  - Cetak/share struk transaksi pelanggan dengan toggle poin loyalti ON dan OFF.

## 2026-05-29 - App Version Bump 0.6.0

- Fitur/bug: Menaikkan minor version dan build number untuk rilis berikutnya.
- File penting yang diubah:
  - `pubspec.yaml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Semantic minor version dinaikkan dari `0.5.0` ke `0.6.0`.
  - Build number dinaikkan dari `6` ke `7`.
- Command verifikasi yang disarankan:
  - `flutter build apk --release`

## 2026-05-29 - Cash Payment Quick Amounts

- Fitur/bug: Menyesuaikan pilihan cepat nominal uang diterima pada pembayaran tunai.
- File penting yang diubah:
  - `lib/features/pos/widgets/checkout_sheet.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Menghapus nominal cepat `Rp200.000`.
  - Menambahkan nominal cepat `Rp20.000` sebelum `Rp50.000`.
  - Pilihan tetap hanya menampilkan nominal yang cukup untuk total pembayaran agar tidak memicu pembayaran kurang.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Coba pembayaran tunai dengan total di bawah `Rp20.000`, antara `Rp20.000`-`Rp50.000`, dan di atas `Rp100.000`.

## 2026-05-30 - Held Order Replace By Label

- Fitur/bug: Memastikan hold order dengan nama/label yang sama akan mereplace isi hold order yang sudah ada.
- File penting yang diubah:
  - `lib/core/database/daos/held_order_dao.dart`
  - `lib/features/pos/held_order_service.dart`
  - `test/features/pos/held_order_service_test.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Label hold order dinormalisasi dengan trim dan collapse whitespace sebelum disimpan.
  - Pencarian hold order existing dibuat case-insensitive berdasarkan label yang sudah dinormalisasi.
  - Saat ditemukan label yang sama pada cabang yang sama, row terbaru di-update dengan payload cart baru; duplikat lama dengan label sama dibersihkan.
  - Menambahkan unit test untuk memastikan hold kedua dengan label sama menyisakan satu row dan payload cart terbaru.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - `flutter test test/features/pos/held_order_service_test.dart`

## 2026-05-30 - Persist POS Menu View Mode

- Fitur/bug: Menyimpan pilihan tampilan menu kasir terakhir antara card/grid view dan list/detail view di device.
- File penting yang diubah:
  - `lib/features/pos/widgets/menu_grid.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Pilihan disimpan lokal memakai `SharedPreferences` dengan key `posMenuViewMode` karena ini preferensi device, bukan data cabang/sync.
  - Default tetap `grid` agar perilaku awal untuk device baru tidak berubah.
  - Nilai tersimpan divalidasi lewat mapping enum; value tidak dikenal diabaikan dan fallback ke default.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Buka layar kasir, pilih list/detail view, keluar dari layar/app, lalu buka lagi dan pastikan pilihan terakhir tetap dipakai.

## 2026-05-30 - Sync Product Availability Toggle

- Fitur/bug: Membuat toggle ketersediaan produk per cabang di layar Menu ikut tersinkron ke Supabase.
- File penting yang diubah:
  - `lib/features/catalog/catalog_screen.dart`
  - `lib/features/catalog/product_detail_screen.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Setelah `branch_products.is_available` diubah dari switch cepat layar Menu, aplikasi sekarang enqueue `OutboxEntityType.branchProduct` dengan composite key `product_id` dan `branch_id`.
  - Save pengaturan cabang di detail produk juga enqueue `branchProduct`, sehingga availability, custom name, price override, diskon, dan masa berlaku diskon ikut masuk jalur sync yang sama.
  - Tidak menambah migrasi karena kolom `branch_products.is_available`, DTO, dan handler push `_pushBranchProduct` sudah tersedia.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Toggle produk tersedia/tidak tersedia, jalankan sync, lalu cek row `branch_products.is_available` di Supabase.

## 2026-05-30 - Reports Custom Date Range

- Fitur/bug: Menambahkan filter rentang tanggal mulai/selesai di layar Laporan dan menampilkan hari+tanggal pada card pendapatan.
- File penting yang diubah:
  - `lib/features/reports/report_providers.dart`
  - `lib/features/reports/report_providers.g.dart`
  - `lib/features/reports/reports_screen.dart`
  - `lib/core/utils/formatters.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - State range laporan diubah dari `DatePreset` menjadi `ReportRangeSelection` agar bisa menyimpan preset maupun custom range.
  - Preset Hari Ini/Kemarin/7 Hari/30 Hari tetap tersedia; tombol `Mulai` dan `Selesai` memakai `showDatePicker` untuk custom range.
  - Custom range dinormalisasi ke awal hari untuk start dan akhir hari untuk end supaya query transaksi tetap inklusif.
  - Card `Pendapatan` sekarang menampilkan label hari dan tanggal; untuk multi-day range menampilkan hari+tanggal awal sampai akhir.
  - File generated Riverpod disesuaikan manual karena project instruction tidak menjalankan build runner.
- Command verifikasi yang disarankan:
  - `dart run build_runner build --delete-conflicting-outputs`
  - `flutter analyze`
  - Buka Laporan, pilih preset dan custom range, lalu pastikan data dan label tanggal di card Pendapatan sesuai.

## 2026-05-30 - Share Report as Image

- Fitur/bug: Menambahkan aksi share laporan sebagai satu image PNG yang memuat ringkasan pendapatan, metode pembayaran, transfer per rekening, dan produk terlaris.
- File penting yang diubah:
  - `lib/features/reports/reports_screen.dart`
  - `lib/features/reports/share_report_image_use_case.dart`
  - `lib/core/utils/formatters.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Image laporan digenerate dari canvas khusus berukuran lebar tetap `1080px`, bukan screenshot viewport, agar seluruh section bisa masuk dalam satu gambar vertikal.
  - File PNG disimpan ke temporary directory lalu dibagikan menggunakan `Share.shareXFiles`.
  - Hasil image memuat nama cabang, periode laporan, pendapatan, metode pembayaran, transfer per rekening, produk terlaris, dan timestamp `Image dibuat` sampai jam-menit-detik.
  - Section `Transfer per Rekening` tetap dicetak di image walaupun tidak ada transaksi transfer, dengan pesan kosong yang eksplisit.
- Command verifikasi yang disarankan:
  - `flutter analyze`
  - Buka Laporan, pilih periode, tap share, lalu pastikan image yang dibagikan berisi semua section dan timestamp generate sampai detik.

## 2026-05-30 - POS Recommended Menu Filter

- Fitur/bug: Menambahkan filter dinamis `Rekomendasi` di layar kasir dan menyimpan filter kategori terakhir di device.
- File penting yang diubah:
  - `lib/core/database/daos/transaction_dao.dart`
  - `lib/features/pos/menu_provider.dart`
  - `lib/features/pos/menu_provider.g.dart`
  - `lib/features/pos/widgets/menu_grid.dart`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Filter `Rekomendasi` tetap menampilkan semua menu tersedia, tetapi mengurutkan berdasarkan total quantity terjual pada transaksi completed dalam 7 hari terakhir.
  - Produk yang belum terjual tetap tampil di bawah produk terjual, dengan fallback sort berdasarkan nama produk agar stabil.
  - Pilihan filter kategori disimpan lokal memakai `SharedPreferences` key `posMenuCategoryFilter`; nilai virtual rekomendasi memakai `__recommended__`.
  - Jika kategori tersimpan sudah tidak tersedia lagi, UI fallback sementara ke `Semua` tanpa menghapus preferensi tersimpan.
  - Provider Riverpod generated disesuaikan manual karena project instruction tidak menjalankan build runner.
- Command verifikasi yang disarankan:
  - `dart run build_runner build --delete-conflicting-outputs`
  - `flutter analyze`
  - Buat/cek transaksi 7 hari terakhir, buka kasir, pilih `Rekomendasi`, dan pastikan produk terlaris tampil lebih dulu.
  - Tutup/buka ulang layar kasir dan pastikan filter terakhir tetap terpilih.

## 2026-05-30 - App Version Bump 0.7.0

- Fitur/bug: Menaikkan minor version dan build number untuk rilis berikutnya.
- File penting yang diubah:
  - `pubspec.yaml`
  - `PROJECT_MEMORY.md`
- Keputusan teknis:
  - Semantic minor version dinaikkan dari `0.6.0` ke `0.7.0`.
  - Build number dinaikkan dari `7` ke `8`.
- Command verifikasi yang disarankan:
  - `flutter build apk --release`

## 2026-06-16 - FEAT-002 Stage 5: Onboarding UI Chunks 2-4

- Fitur/bug: Implementasi Chunks 2-4 onboarding multi-tenant (Chunk 1 auth providers sudah selesai).
- File penting yang diubah:
  - `lib/features/onboarding/onboarding_screen.dart` (baru)
  - `lib/features/onboarding/create_org_screen.dart` (baru)
  - `lib/features/onboarding/join_org_screen.dart` (baru)
  - `lib/features/settings/organization_card.dart` (baru)
  - `lib/features/settings/settings_screen.dart` (tambah OrganizationCard)
  - `lib/features/auth/auth_provider.dart` (tambah completeOnboarding)
  - `lib/router.dart` (tambah /onboarding routes + redirect logic)
  - `lib/l10n/arb/app_id.arb` (tambah onboarding keys)
  - `lib/l10n/arb/app_en.arb` (tambah onboarding keys)
  - `PROJECT_MEMORY.md` (ini)
- Keputusan teknis:
  - Onboarding entry screen dengan dua opsi: Buat Organisasi Baru + Gabung via Kode Undangan.
  - Create org form dengan fields: name, businessType (dropdown), phone, address.
  - Join org screen MVP menampilkan snackbar "Fitur undangan belum tersedia".
  - OrganizationDao menggunakan raw SQL karena Drift codegen blocked (TD-001).
  - Router redirect: needsOnboarding → /onboarding, unauthenticated → /login, authenticated → /pos/bootstrap.
  - completeOnboarding() transition auth state dari needsOnboarding ke authenticated dengan organizationId baru.
  - OrganizationCard di Settings menampilkan nama org + subscription tier badge (Free/Plus/Trial).
  - OrganizationSwitcherBottomSheet menampilkan daftar org user dengan opsi create new (MVP: switch belum available).
  - Sync scoping push payloads organization_id belum diimplementasi (future enhancement).
- Command verifikasi yang disarankan:
  - Jalankan `flutter pub run build_runner build --delete-conflicting-outputs`
  - Jalankan `flutter gen-l10n`
  - Jalankan `flutter analyze lib/features/onboarding/ lib/features/settings/settings_screen.dart lib/router.dart lib/core/sync/sync_repository.dart`
  - Test flow: login → redirect ke /onboarding → Buat Org → navigate ke /bootstrap
- Proposed commit message:
  - `feat: add onboarding UI and org selection for multi-tenant setup`
