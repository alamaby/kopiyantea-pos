# Multi-Tenant SaaS Migration TODO

Dokumen ini melacak pekerjaan rombak aplikasi menjadi SaaS multi-tenant. Gunakan Supabase project staging terpisah untuk seluruh tahap sampai RLS, migrasi, sync, dan billing stabil.

## Status Tahapan

- [x] 1. Desain/ADR multi-tenant
  - Buat ADR model organization, membership, branch, subscription, entitlement, onboarding, RLS, dan strategi migrasi non-destruktif.
  - Output: `docs/adr/0014-multi-tenant-saas-architecture.md`.
- [x] 2. Migrasi tenant boundary di Supabase
  - [x] Buat migration expand untuk `organizations`, `organization_members`, subscription tables, usage counters, dan entitlement events.
  - [x] Tambah `organization_id` nullable ke data bisnis global dan backfill data lama ke satu organization default.
  - [x] Tambah helper function organization-aware untuk persiapan rewrite RLS.
  - [ ] Jalankan migration di Supabase staging `APP_ENV=staging`.
  - [ ] Validasi backfill di staging: semua row bisnis existing punya `organization_id`, main branch terset, dan owner menjadi organization member.
  - [ ] Setelah app sudah organization-aware, enforce `NOT NULL` dan cabut unique constraint global lama di migration terpisah.
- [x] 3. Rewrite RLS
  - [x] Ganti helper role/branch global menjadi helper organization-scoped.
  - [x] Pastikan semua data tenant memakai policy deny-by-default dan tidak ada `USING (TRUE)` untuk data bisnis tenant.
- [x] 4. Migrasi Drift lokal + DTO sync
  - [x] Tambah table/column lokal, DTO, DAO, outbox payload, dan pull/push organization-aware.
  - [x] Update `AuthedSession` agar membawa `organizationId`, dan `AuthState` menangani `needsOnboarding`.
  - [x] Fix blocker TD-001: upgrade drift/drift_dev 2.21.0, regenerate `app_database.g.dart` penuh.
- [x] 5. Onboarding signup
  - [x] Setelah user daftar, frontend onboarding (`CreateOrgScreen`) membuat organization, owner membership, dan trial plus 30 hari lokal + sync.
  - [ ] Backend RPC/transaksi atomik Supabase untuk create org + owner + main branch + default settings (opsional, bisa handle di app lalu sync).
- [ ] 6. Entitlement free/plus
  - Implement plan limit untuk transaksi, produk/menu, fitur plus, trial, downgrade, dan over-limit handling non-destruktif.
- [ ] 7. Subscription cabang tambahan + quota karyawan
  - Plus user bisa subscribe cabang tambahan.
  - Tiap cabang tambahan aktif memberi quota invite 2 karyawan.
- [x] 8. Rebrand agar tidak F&B-only
  - [x] Tambah `business_type` (fnb, retail, service, generic) ke model organization.
  - [ ] Generalisasi copy/UI dari Kopiyantea/coffee/menu menjadi usaha/katalog/produk (partial, UI masih coffee-centric).
- [ ] 9. Hardening dan QA
  - Audit RLS lintas tenant, sync offline-first, downgrade/over-limit, invite, transaksi, dan billing edge cases.

## Catatan Operasional

- Jangan jalankan eksperimen schema/RLS di Supabase production.
- Gunakan `.env` terpisah untuk staging Supabase URL dan anon key.
- Semua migration harus non-destruktif dan idempotent jika memungkinkan.
- Transaksi tetap append-only; limit/billing tidak boleh menghapus transaksi historis.
- Jika trial/subscription habis, blok create/fitur baru secara terukur, bukan menghapus data.

## Command Verifikasi Yang Disarankan

- `dart run build_runner build --delete-conflicting-outputs`
- `flutter gen-l10n`
- `flutter analyze`
- `flutter test`
- Uji manual RLS dengan minimal 2 organization, 2 owner, beberapa branch, produk, customer, dan transaksi.
