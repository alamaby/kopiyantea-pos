# SaaS Multi-Tenant Server-First — Implementation Plan

Created: 2026-09-25 15:00:00

## Objective

Membawa backend Supabase prod (`snidupbkvmhsqzlvmsqa`) + aplikasi Flutter ke arsitektur multi-tenant SaaS yang berfungsi, dengan urutan **server dulu, app belakangan**. Tenant pertama (`Kopiyantea Kamarasan`: 1 owner, 2 branch, 44 produk, 109 customer, 134 transaksi — terverifikasi via MCP 2026-09-25) harus tetap normal selama dan sesudah migrasi. Item 16 (RLS rewrite) disiapkan patch-nya sekarang tetapi **dilarang di-apply sebelum Fase App hijau**.

Keputusan user yang mengikat plan ini: server langsung prod (tanpa project dev/staging); diasumsikan 1 user prod adalah owner (Anda); billing/limit tahap 6–7 ditunda.

## Scope

In-scope findings (semua dari audit review + sesi migrasi 2026-09-25):

- F-SRV-01: `20260925000002` (kolom org + `updated_at` invitation) belum di-apply; prasyarat item 17.
- F-SRV-02: `20260617_invite_code_expand.sql` mengandung sintaks invalid (`ADD CONSTRAINT IF NOT EXISTS`) + butuh `updated_at` yang belum ada.
- F-SRV-03: `20260702000000_keep_alive_rpc.sql` belum di-apply (risiko ~nol).
- F-SRV-04: `20260925000003_rls_hardening.sql` wajib apply SEBELUM 16 (menyasar nama policy pra-16).
- F-SRV-05: `20260925000001_org_parity_minimal.sql` redundan (dicakup no.15) dan bagian RLS-terbukanya berbahaya bila jalan → repair-sebagai-applied dengan dokumentasi, tanpa menjalankan isinya.
- F-SRV-06: `20260925000004_perf_indexes.sql` belum di-apply.
- F-SRV-07: Item 16 merusak app bila di-apply sekarang (3 bukti + gap push org).
- F-SRV-08: Patch file 16 yang wajib sebelum apply (jwt fix, self-claim, koeksistensi 000001).
- F-SRV-09: Butuh cek versi Postgres untuk `NULLS NOT DISTINCT` (item 17, butuh PG15+).
- F-SRV-10: Snapshot `pg_policies` + helper wajib sebelum tiap perubahan kebijakan (satu-satunya rollback tanpa staging).
- F-SRV-11: Kual policy lama `app_users_insert` belum diketahui → verifikasi read-only sebelum patch 16.
- F-APP-01: Tabel Drift bisnis lokal tanpa `organization_id` → schemaVersion 24 + backfill lokal.
- F-APP-02: DTO push tidak mengirim `organization_id` → stamp dari `currentOrganizationIdProvider`.
- F-APP-03: Baris org/member/subscription lokal tidak pernah ter-push (tidak ada entity outbox + tidak ada INSERT policy) → RPC signup atomik per ADR-0014.
- F-APP-04: Pembuatan branch/produk/kategori baru harus otomatis isi org aktif.

Out-of-scope (dilarang dalam plan ini): billing/limit tahap 6–7, rewrite RLS selain yang dispesifikasi, upgrade freezed/riverpod (TD-001 true fix), perubahan UI selain stamp org otomatis, `supabase db push` massal (hanya `db query --file` per item + `repair`), apply ke project selain prod.

## Requirement Traceability

| Finding | ADR / Requirement | Step |
|---|---|---|
| F-SRV-10 snapshot rollback | Operasional tanpa staging | S-01 |
| F-SRV-11 old insert qual | Koreksi patch 16 | S-02 |
| F-SRV-09 versi Postgres | Prasyarat item 17 | S-03 |
| F-SRV-01 kolom invitation | Prasyarat item 17 | S-04 |
| F-SRV-02 sintaks + claim RPC | Invite kode org kedua+ | S-05 |
| F-SRV-03 keep-alive | Operasional | S-06 |
| F-SRV-04 hardening pra-16 | ADR-0007 | S-07 |
| F-SRV-05 000001 redundan | Kebersihan riwayat | S-08 |
| F-SRV-06 index | Perf advisor | S-09 |
| F-SRV-08 patch file 16 | Syarat apply 16 | S-10 |
| F-APP-01 kolom lokal | Tahap 4 todo (sisa) | S-11 |
| F-APP-02 stamp DTO | Smoke Cek 1 (org_id wajib) | S-12 |
| F-APP-03 RPC signup | ADR-0014 | S-13 |
| F-APP-04 stamp pembuatan baru | Konsistensi tenant | S-14 |
| F-SRV-07 apply 16 (gated) | Tenant pertama normal | S-15 |
| Semua di atas | Verifikasi akhir | S-16 |

## Milestones

1. M1 — Server aman (S-01 s.d. S-09, kecuali apply 16).
2. M2 — Patch 16 siap, belum di-apply (S-10).
3. M3 — App org-aware + smoke pra-16 (S-11 s.d. S-14).
4. M4 — 16 live + tenant pertama dinyatakan normal (S-15, S-16).

## Tasks

- [x] S-01 Snapshot pg_policies + helper (rollback baseline)
- [x] S-02 Verifikasi kual `app_users_insert` lama (read-only)
- [x] S-03 Cek versi Postgres (syarat NULLS NOT DISTINCT)
- [x] S-04 Apply 000002 → verifikasi → repair
- [x] S-05 Perbaiki + apply 17 → verifikasi → repair
- [x] S-06 Apply 18 → verifikasi → repair
- [x] S-07 Apply 000003 → verifikasi → repair
- [x] S-08 Repair 000001 sebagai digantikan (tanpa menjalankan isi)
- [x] S-09 Apply 000004 → verifikasi → repair
- [x] S-10 Patch file 16 (tanpa efek DB)
- [x] S-11 Schema Drift 24: kolom org lokal + backfill
- [x] S-12 Stamp organization_id di DTO push
- [x] S-13 RPC signup atomik + onboarding pakai RPC
- [x] S-14 Stamp org pada pembuatan data baru
- [ ] S-15 Apply 16 — **BLOCKED** (lihat Progress Log 17:15): butuh APK baru terpasang dulu
- [x] S-16 Regresi akhir (gate dijalankan; handoff ada di Progress Log)

---

## S-01 Snapshot pg_policies + helper

- Tujuan: memiliki bahan rollback manual sebelum tiap perubahan kebijakan (pengganti staging yang tidak ada).
- Finding: F-SRV-10.
- Dependency: none.
- File yang harus dibaca: none (-query read-only).
- File yang harus diubah: baru `docs/saas-rls-snapshot-2026-09-25.sql` (satu file, via output query — bukan migrasi, jangan taruh di `supabase/migrations/`).
- Simbol: `pg_policies`, `pg_proc` (`user_global_role`, `user_has_branch_access`, `reconcile_cached_stock`, `stamp_server_received_at`, `current_user_*`, `branch_org_id`).
- Kondisi saat ini: riwayat 26 migrasi; policy pra-16 + helper org dari no.15 live di prod.
- Perubahan konkret (urutan): (1) via MCP `execute_sql` (read-only) ambil `SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check FROM pg_policies WHERE schemaname IN ('public','storage') ORDER BY 1,2,3`; (2) ambil `pg_get_functiondef(oid)` untuk 8 helper di atas; (3) simpan mentah ke file snapshot dengan header tanggal + versi CLI.
- Behavior yang dipertahankan: semua (read-only).
- Error handling: jika query MCP gagal, JANGAN lanjut ke S-04 s.d. S-10; ulangi sampai snapshot lengkap.
- Test: tidak ada (artefak, bukan kode).
- Command verifikasi: `git status --porcelain` menunjukkan tepat 1 file baru; isi file mengandung string `branches_select` dan `user_global_role`.
- Hasil yang diharapkan: file ada, lengkap, tidak ada secret di dalamnya (hanya DDL/policy).
- Completion criteria: file snapshot ada + bisa dipakai mereka ulang policy secara manual bila rollback dibutuhkan.
- Tidak boleh diubah: file migrasi, kode Dart, riwayat migrasi remote.

## S-02 Verifikasi kual app_users_insert lama

- Tujuan: memastikan patch 16 benar (apakah self-claim pra-16 mengandalkan policy permissive yang harus dipertahankan).
- Finding: F-SRV-11.
- Dependency: S-01.
- File yang harus dibaca: `supabase/migrations/20260518150010_rls_policies.sql` (cari blok `app_users_insert`), `supabase/migrations/20260519150001_user_management.sql` baris 77-87.
- File yang harus diubah: none.
- Simbol: policy `app_users_insert`, `app_users_self_claim_insert` di tabel `app_users`.
- Kondisi saat ini: dua policy INSERT coexist di prod (terverifikasi ada via MCP 2026-09-25); qual `app_users_insert` lama belum dibaca.
- Perubahan konkret: via MCP `execute_sql`: `SELECT policyname, with_check FROM pg_policies WHERE schemaname='public' AND tablename='app_users' AND cmd='INSERT'`. Catat kedua `with_check` ke Progress Log file plan.
- Behavior yang dipertahankan: semua (read-only).
- Error handling: bila salah satu policy hilang vs ekspektasi, STOP dan flag sebagai blocker (asumsi koeksistensi patch goyah).
- Test: tidak ada.
- Command verifikasi: query mengembalikan tepat 2 baris (`app_users_insert`, `app_users_self_claim_insert`).
- Hasil yang diharapkan: qual lama terdokumentasi; menjadi input literal untuk S-10 butir 3.
- Completion criteria: hasil query tercatat di Progress Log.
- Tidak boleh diubah: semua file + remote.

## S-03 Cek versi Postgres

- Tujuan: memastikan `UNIQUE NULLS NOT DISTINCT` (item 17) didukung.
- Finding: F-SRV-09.
- Dependency: none (boleh paralel dengan S-01/S-02).
- File yang harus dibaca: `supabase/.temp/postgres-version` (file lokal, berisi versi saja — bukan secret).
- File yang harus diubah: none.
- Simbol: constraint `pending_invitations_org_code_uq` di file 17.
- Kondisi saat ini: file 17 menuntut PG15+ (komentar di file).
- Perubahan konkret: baca file versi; bila MAJOR >= 15 lanjut; bila < 15, STOP dan flag blocker (item 17 harus ditulis ulang tanpa NULLS NOT DISTINCT).
- Behavior yang dipertahankan: semua.
- Error handling: bila file tidak ada, tanyakan versi via MCP `SELECT version()` (read-only, bukan data user).
- Test: tidak ada.
- Command verifikasi: tampilkan angka versi di Progress Log.
- Hasil yang diharapkan: `15.x` atau lebih (Supabase default sejak 2024).
- Completion criteria: versi tercatat + keputusan lanjut/tunda untuk S-05 eksplisit.
- Tidak boleh diubah: semua file + remote.

## S-04 Apply 000002

- Tujuan: lengkapi kolom invitation yang diasumsikan item 17 (`organization_id`, `updated_at`).
- Finding: F-SRV-01.
- Dependency: S-01 (snapshot ada).
- File yang harus dibaca: `supabase/migrations/20260925000002_pending_invitations_org.sql` (21 baris).
- File yang harus diubah: none (file sudah benar).
- Simbol: `pending_invitations.organization_id`, `pending_invitations.updated_at`, index `pending_invitations_organization_idx`.
- Kondisi saat ini: `pending_invitations` 7 kolom; belum ada keduanya (terverifikasi MCP).
- Perubahan konkret (urutan): (1) `& "scripts/supabase-with-token.ps1" db query --linked -f supabase/migrations/20260925000002_pending_invitations_org.sql` dari repo root; (2) verifikasi MCP: kedua kolom ada + index ada; (3) `migration repair --status applied --linked 20260925000002`.
- Behavior yang dipertahankan: baris invitation existing (bila ada) tak tersentuh nilai (kolom baru nullable/default).
- Error handling: bila query gagal, JANGAN repair; baca pesan error, perbaiki file (file ini milik sendiri, boleh edit pre-apply), ulangi. Jangan lanjut ke S-05 bila kolom belum ada.
- Test: tidak ada (DDL).
- Input/expected: file 21 baris tidak berubah; ekspektasi kolom `organization_id(uuid,nullable)`, `updated_at(timestamptz,not null,default now())`.
- Command verifikasi: MCP `SELECT column_name ... WHERE table_name='pending_invitations'` memuat keduanya; `list_migrations` memuat `20260925000002` setelah repair.
- Hasil yang diharapkan: 9 kolom invitation; riwayat 27 entri.
- Completion criteria: kolom + index terverifikasi ADA di prod dan riwayat tercatat.
- Tidak boleh diubah: file migrasi lain, kode Dart, policy existing.

## S-05 Perbaiki + apply item 17

- Tujuan: aktifkan code-invite + claim RPC untuk organisasi kedua dan seterusnya.
- Finding: F-SRV-02.
- Dependency: S-04 (kolom ada), S-03 (versi PG OK).
- File yang harus dibaca: `supabase/migrations/20260617_invite_code_expand.sql` (184 baris, khususnya baris 35-47 constraint + index, 60-184 fungsi + grant).
- File yang harus diubah: `supabase/migrations/20260617_invite_code_expand.sql` (diizinkan: belum pernah di-apply).
- Simbol: kolom `join_code/invite_type/max_uses/used_count/status/expires_at`, constraint `pending_invitations_org_code_uq`, index `pending_invitations_code_idx`, fungsi `claim_invitation_code(text,uuid)`.
- Kondisi saat ini: belum ada satupun di prod.
- Perubahan konkret (urutan di file): (1) ganti blok baris 35-37 `ALTER TABLE ... ADD CONSTRAINT IF NOT EXISTS ...` menjadi blok DO ber-guard:
  ```sql
  do $$ begin
    if not exists (select 1 from pg_constraint where conname = 'pending_invitations_org_code_uq') then
      alter table public.pending_invitations
        add constraint pending_invitations_org_code_uq
        unique nulls not distinct (organization_id, join_code);
    end if;
  end $$;
  ```
  (2) sisanya JANGAN diubah (kolom ADD COLUMN IF NOT EXISTS, index, fungsi, grant, comment); (3) `db query --linked -f` file tersebut; (4) verifikasi MCP: 6 kolom ada, constraint ada (`pg_constraint`), fungsi ada (`pg_proc`), grant ke authenticated ada (`has_function_privilege('authenticated', ...)` atau cek `information_schema.role_routine_grants`); (5) repair `20260617`.
- Behavior yang dipertahankan: baris invitation lama valid (default `email/active/1/0`).
- Error handling: bila gagal di fungsi (mis. referensi kolom), JANGAN repair; error claim-RPC diuji di S-16, bukan di sini. Bila `NULLS NOT DISTINCT` ditolak (S-03 gagal), ganti constraint menjadi unique index biasa `CREATE UNIQUE INDEX IF NOT EXISTS ... ON pending_invitations(organization_id, join_code)` + catat deviasi (NULL ganda diizinkan — boleh karena invite email ber-`join_code` NULL banyak).
- Test: tidak ada (DDL); uji perilaku claim di S-16.
- Command verifikasi: query MCP di atas + `list_migrations` memuat `20260617`.
- Hasil yang diharapkan: RPC callable; riwayat 28 entri.
- Completion criteria: semua objek terverifikasi ADA + riwayat tercatat.
- Tidak boleh diubah: file migrasi lain, kode Dart.

## S-06 Apply item 18 (keep-alive RPC)

- Tujuan: RPC probe read-only untuk workflow keep-alive.
- Finding: F-SRV-03.
- Dependency: S-01.
- File yang harus dibaca: `supabase/migrations/20260702000000_keep_alive_rpc.sql`.
- File yang harus diubah: none (kecuali verifikasi gagal — lihat edge).
- Simbol: fungsi `keep_alive_ping()`.
- Kondisi saat ini: belum ada di prod (asumsi; verifikasi dulu).
- Perubahan konkret: (1) verifikasi MCP `SELECT proname FROM pg_proc ... WHERE proname='keep_alive_ping'` — bila SUDAH ada, langsung repair + catat (jangan jalankan ulang); (2) bila belum: `db query --linked -f` file; verifikasi ada + grant anon/authenticated; repair `20260702000000`.
- Behavior yang dipertahankan: read-only; tidak menyentuh data bisnis.
- Error handling: bila file mengandung selain fungsi probe (baca dulu seluruh file!), STOP dan flag.
- Test: manual `curl POST /rest/v1/rpc/keep_alive_ping` dengan publishable key → 2xx (boleh setelah apply).
- Command verifikasi: MCP + `list_migrations`.
- Hasil yang diharapkan: fungsi ada; riwayat 29 entri.
- Completion criteria: sama.
- Tidak boleh diubah: selain yang dinyatakan.

## S-07 Apply 000003 (RLS hardening)

- Tujuan: tutup temuan linter security tanpa mengubah matriks akses (pin search_path, revoke anon, policy owner ke authenticated).
- Finding: F-SRV-04.
- Dependency: S-01. WAJIB sebelum S-15 (menyasar nama policy pra-16).
- File yang harus dibaca: `supabase/migrations/20260925000003_rls_hardening.sql` (66 baris).
- File yang harus diubah: none.
- Simbol: `reconcile_cached_stock()`, `stamp_server_received_at()`, `user_global_role()`, `user_has_branch_access(uuid)`, 6 policy owner bank/categories.
- Kondisi saat ini: trigger tanpa search_path; anon bisa EXECUTE helper; 6 policy ber-role `{public}` (terverifikasi MCP pra-kerja).
- Perubahan konkret: `db query --linked -f` file; verifikasi MCP: `pg_proc.proconfig` kedua trigger memuat `search_path=public`, `has_function_privilege('anon', ...)` = false untuk kedua helper (tetap true untuk authenticated), `pg_policies.roles` 6 policy = `{authenticated}`; repair `20260925000003`.
- Behavior yang dipertahankan: matriks ADR-0007 identik (predikat USING/WITH CHECK tak berubah); logika trigger identik.
- Error handling: bila app memanggil helper sebagai anon (sudah dicek: satu-satunya `sb.rpc` adalah `claim_invitation_code` authenticated — aman), tetap verifikasi ulang via grep `\.rpc\(` di `lib/` sebelum apply.
- Test: existing `flutter test` (tidak ada test RLS baru; smoke RLS manual di S-16).
- Command verifikasi: query MCP di atas + `get_advisors(security)` (ekspektasi `anon_security_definer` berkurang; `function_search_path_mutable` untuk 2 trigger hilang).
- Hasil yang diharapkan: linter membaik; riwayat 30 entri.
- Completion criteria: semua cek MCP lolos + riwayat tercatat.
- Tidak boleh diubah: policy transaksi/uba/invite, file lain.

## S-08 Repair 000001 sebagai digantikan

- Tujuan: jaga kebersihan riwayat tanpa menjalankan isi berbahaya (bagian RLS-terbuka).
- Finding: F-SRV-05.
- Dependency: S-07 (atau kapan pun; tanpa efek DB).
- File yang harus dibaca: `supabase/migrations/20260925000001_org_parity_minimal.sql` (bagian RLS `USING (true)`).
- File yang harus diubah: none.
- Simbol: policy `organizations_read_auth`, `organization_members_read_auth`, `organization_subscriptions_read_auth`, `usage_counters_read_auth`, `company_settings_read_auth`.
- Kondisi saat ini: seluruh DDL-nya sudah dicakup no.15 (7 tabel, 16 kolom, index); bagian RLS-nya justru melemahkan no.15 bila dijalankan.
- Perubahan konkret: `migration repair --status applied --linked 20260925000001` TANPA `db query`; tulis alasan di Progress Log ("superseded by 20260613110000; open-RLS section intentionally never executed").
- Behavior yang dipertahankan: RLS SaaS no.15 tetap deny-by-default.
- Error handling: bila `db push` di masa depan mengeluh checksum (konten tak pernah jalan tapi tercatat — repair tidak cek konten, aman), catat saja.
- Test: tidak ada.
- Command verifikasi: `list_migrations` memuat `20260925000001`; MCP `SELECT count(*) FROM pg_policies WHERE policyname LIKE '%_read_auth'` = 0 (policy terbuka tak pernah tercipta).
- Hasil yang diharapkan: riwayat 31 entri; tidak ada policy `USING(true)` baru.
- Completion criteria: keduanya terverifikasi.
- Tidak boleh diubah: semua konten DB; file 000001 dibiarkan apa adanya sebagai dokumen.

## S-09 Apply 000004 (index performa)

- Tujuan: tutup 10 temuan `unindexed_foreign_keys`.
- Finding: F-SRV-06.
- Dependency: S-01.
- File yang harus dibaca: `supabase/migrations/20260925000004_perf_indexes.sql` (48 baris; bagian initplan hanya TODO comment).
- File yang harus diubah: none.
- Simbol: 10 index `*_idx` (lihat daftar di file).
- Kondisi saat ini: 10 FK tanpa covering index (linter 2026-09-25).
- Perubahan konkret: `db query --linked -f` file; verifikasi MCP `SELECT indexname FROM pg_indexes WHERE indexname IN (...)` = 10 baris; repair `20260925000004`.
- Behavior yang dipertahankan: hanya tambah index; tidak ada DROP.
- Error handling: JANGAN pakai CONCURRENTLY (file sudah benar tanpa itu); bila satu index gagal (nama bentrok), perbaiki nama di file (milik sendiri, pre-apply) lalu ulangi file penuh (idempotent).
- Test: tidak ada.
- Command verifikasi: query index + `get_advisors(performance)` (`unindexed_foreign_keys` → 0).
- Hasil yang diharapkan: riwayat 32 entri.
- Completion criteria: 10/10 index ada + riwayat tercatat.
- Tidak boleh diubah: index existing (`007`), kode Dart.

## S-10 Patch file 16 (tanpa efek DB)

- Tujuan: siapkan versi 16 yang aman di-apply (tidak merusak klaim + invite + visibilitas tenant pertama).
- Finding: F-SRV-08.
- Dependency: S-02 (input qual lama), S-07 (selesai).
- File yang harus dibaca: SELURUH `supabase/migrations/20260615000000_rls_rewrite_multitenant.sql` (481 baris; fokus baris 144-148, 190-193, 458-473).
- File yang harus diubah: file 16 itu sendiri (diizinkan: belum pernah di-apply) — JANGAN buat file patch terpisah agar riwayat satu-versi-satu-file.
- Simbol: policy `app_users_insert`, `uba_write`, `pending_invitations_delete`, helper `auth.jwt()`.
- Kondisi saat ini: (1) `app_users_insert` referensi `auth.users` → 42501; (2) `uba_write`/`pending_invitations_delete` baru manage-only mematikan self-claim via semantik AND; (3) policy terbuka 000001 tidak dibahas file ini (000001 tak pernah jalan — catat di header file bahwa tidak ada yang perlu dicabut).
- Perubahan konkret (urutan di file, tepat 1 edit wajib + 1 header): (1) WAJIB di `app_users_insert`: ganti `(select email from auth.users where id = auth.uid())` menjadi `(auth.jwt() ->> 'email')` — referensi `auth.users` melempar 42501 (bukan false) dan membunuh SEMUA insert `app_users`; (2) EDIT uba_write/pending_delete DIBATALKAN — terbukti tidak perlu: policy PERMISSIVE digabung OR, dan policy self-claim lama (`uba_self_claim_insert`, `pending_invitations_self_claim`/`self_read`) survive karena Section 1 file 16 tidak me-drop mereka (terverifikasi baca baris 54-71); invitee lolos via cabang OR lama; (3) tambah header comment `-- PATCH 2026-09-25: jwt-fix app_users_insert; uba/invite self-claim dipertahankan via policy lama (OR) — belum di-apply`.
- Behavior yang dipertahankan: deny-by-default tenant; owner manage penuh; selebihnya identik dengan file asli.
- Error handling: setelah edit, JANGAN apply (itu S-15); verifikasi sintaks hanya dengan membaca ulang diff (`git diff` file tersebut) — tidak ada-II lint SQL lokal yang tersedia.
- Test: tidak ada di langkah ini (smoke klaim di S-15/S-16).
- Command verifikasi: `git diff --stat` menunjukkan tepat 1 file berubah; `grep -c "auth.users" <file>` = 0; `grep -c "auth.jwt" <file>` >= 3.
- Hasil yang diharapkan: file siap-apply, terdokumentasi.
- Completion criteria: 3 edit + header ada; file BELUM tercatat di riwayat remote.
- Tidak boleh diubah: file migrasi lain, kode Dart, remote.

## S-11 Schema Drift 24 (kolom org lokal + backfill)

- Tujuan: aplikasi mampu menyimpan + mengirim `organization_id` per baris bisnis.
- Finding: F-APP-01.
- Dependency: none sisi DB (lokal saja); harus hijau SEBELUM S-15.
- File yang harus dibaca: `lib/core/database/app_database.dart` (onCreate/onUpgrade/`_createUsageCountersTable` pola), `lib/core/database/tables/branch_tables.dart`, `catalog_tables.dart`, `customer_tables.dart`, `inventory_tables.dart`, `option_tables.dart`, `bank_account_table.dart`, `settings_tables.dart`.
- File yang harus diubah: file-file tabel di atas + `app_database.dart` (`schemaVersion` 23→24, blok `if (from < 24)`).
- Simbol: kolom `organizationId` (nullable `text()`) pada `Branches, Products, BranchProducts?, Categories, Customers, InventoryItems, ProductRecipes?, OptionGroups, MenuOptions, ProductOptionGroups?, BankAccounts, ReceiptSettings, CustomerPointLedgers?`. Catatan deterministik: tambah HANYA pada tabel ber-PK sendiri (bukan junction murni `BranchProducts`/`ProductOptionGroups` yang org-nya derivatif via parent — tiru pola server: server menambahkannya juga di sana; untuk determinisme ikuti server: tambah di SEMUA tabel yang dimiliki server, yaitu branches, products, categories, customers, option_groups, options, product_option_groups, bank_accounts, company_settings, pending_invitations, customer_point_ledger + inventory_items/product_recipes/receipt_settings yang branch-scoped (isi dari branch induk saat insert — lihat S-14)).
- Kondisi saat ini: tidak ada kolom org di tabel bisnis lokal (pemicu workaround `getBranchIdsForUserInOrg`).
- Perubahan konkret (urutan): (1) tambah `TextColumn get organizationId => text().nullable()();` di tiap tabel target; (2) bump `schemaVersion => 24`; (3) blok `if (from < 24)` berisi `m.addColumn` per tabel + panggil `_backfillLocalOrgIds()` (fungsi baru di file yang sama): `UPDATE <tabel> SET organization_id = ? WHERE organization_id IS NULL` dengan orgId = satu-satunya org di `organizations` (bila tepat 1; bila 0 atau >1, LEWATI backfill + log w — jangan tebak); (4) `onCreate` tidak perlu diubah (`createAll` mencakup kolom baru); (5) hapus cache `.dart_tool/build` lalu `dart run build_runner build --delete-conflicting-outputs` (wajib per TD-001 workaround).
- Behavior yang dipertahankan: semua data lokal utuh (non-destruktif); FK tidak berubah.
- Error handling: build_runner crash `Null is not InterfaceElement` → ulangi setelah hapus cache; bila tetap gagal, STOP (blocker TD-001, jangan edit `.g.dart` manual).
- Test yang harus ditambahkan: `test/core/database/org_backfill_test.dart` — seed branch+produk tanpa org + 1 org → jalankan migrasi (buka DB via `AppDatabase.memory()` tak menjalankan onUpgrade; maka uji `_backfillLocalOrgIds` via skenario: insert row NULL lalu panggil fungsi backfill langsung bila public, ATAU uji via `customStatement` setara — pilih yang pertama bila visibilitas memungkinkan, else uji DAO-level: companion tanpa org tetap insertable). Input/expected eksplisit: row NULL → setelah backfill = orgId satu-satunya; 0 org → tetap NULL.
- Command verifikasi: `flutter pub get`, `flutter analyze` (0 error), `flutter test test/core/database/org_backfill_test.dart`, lalu `flutter test` penuh.
- Hasil yang diharapkan: semua hijau; `app_database.g.dart` ter-regenerasi.
- Completion criteria: kolom ada di semua tabel target + backfill teruji + suite hijau.
- Tidak boleh diubah: logika migrasi < 24, RLS, file migrasi Supabase.

## S-12 Stamp organization_id di DTO push

- Tujuan: baris baru dari HP lahir dengan org terisi → lolos RLS pasca-16 + terlihat di pull.
- Finding: F-APP-02.
- Dependency: S-11 (kolom lokal ada).
- File yang harus dibaca: `lib/core/sync/sync_dtos.dart` (semua extension `*SyncDto.toSupabaseJson`), `lib/core/sync/sync_repository.dart` (pemanggil push).
- File yang harus diubah: `lib/core/sync/sync_dtos.dart` saja.
- Simbol: `toSupabaseJson()` pada Branch/Product/BranchProduct/Category/Customer/InventoryItem/Recipe/OptionGroup/Option/ProductOptionGroup/BankAccount/ReceiptSetting/CustomerPointLedger/Transaction? — TRANSAKSI dan turunannya TIDAK perlu (branch-scoped via branch_id; RLS-nya via cabang — jangan tambah org ke payload tx agar payload minimal; catat pengecualian ini di komentar kode).
- Kondisi saat ini: tidak ada DTO yang mengirim org (kecuali invitation/member/subscription).
- Perubahan konkret: tiap DTO di atas tambah `'organization_id': organizationId` (dari Row; nullable → kirim null bila null; JANGAN fallback diam-diam ke current org di DTO — stamping saat create menjadi tanggung jawab S-14; DTO hanya meneruskan). Untuk pull (`*FromJson`), tambah `organizationId: Value(json['organization_id'] as String?)` di companion yang kolomnya ditambah S-11.
- Behavior yang dipertahankan: format payload lain identik; pull lama tanpa org tetap parse (nullable).
- Error handling: org null pada push pra-16 → server nullable, aman; pasca-16 → ditolak (by design; S-14 mencegah null terjadi).
- Test: perluas `test/core/sync/*_test.dart` (atau file baru `sync_org_stamp_test.dart`): row dengan org `org-1` → `toSupabaseJson()['organization_id']=='org-1'`; row null → key ada bernilai null; `FromJson` dengan org mengisi companion.
- Command verifikasi: `flutter analyze`, `flutter test test/core/sync/`.
- Hasil yang diharapkan: hijau; tidak ada payload tx berubah.
- Completion criteria: semua DTO target mengirim + mem-parse org; pengecualian tx terdokumentasi di komentar.
- Tidak boleh diubah: logika pull filter, RLS, migrasi.

## S-13 RPC signup atomik + onboarding pakai RPC

- Tujuan: organisasi KEDUA dan seterusnya bisa lahir (client tak punya INSERT policy org).
- Finding: F-APP-03 (ADR-0014).
- Dependency: S-04..S-09 selesai di server (org tables + claim RPC ada).
- File yang harus dibaca: `lib/features/onboarding/create_org_screen.dart` (`_submit` baris 41-131), `lib/features/auth/auth_repository.dart` (`claimJoinCode` pola `sb.rpc`), `lib/core/database/daos/organization_dao.dart`.
- File yang harus diubah: baru `supabase/migrations/20260925000005_org_signup_rpc.sql` + `lib/features/onboarding/create_org_screen.dart` + `lib/features/auth/auth_repository.dart` (tambah `createOrganization` via rpc).
- Simbol: fungsi `create_organization_with_owner(p_name, p_business_type, p_phone, p_address)` returns json; `AuthRepository.createOrganization`.
- Kondisi saat ini: onboarding hanya tulis lokal; tidak ada RPC create-org.
- Perubahan konkret (urutan): (1) tulis file migrasi: fungsi SECURITY DEFINER (`SET search_path=public`), milik postgres: validasi `auth.uid() NOT NULL`; insert `organizations` (id gen_random_uuid, status active, trial +30 hari) → insert `organization_members` (user=auth.uid, role owner, active) → insert `organization_subscriptions` (plus/trialing/manual, periode now→+30h) → `GRANT EXECUTE TO authenticated`; (2) apply via `db query` + verifikasi MCP (`pg_proc` ada + grant) + repair; (3) `AuthRepository.createOrganization(...)` panggil `sb.rpc` kembalikan `(organizationId, organizationName)` atau Err string; (4) `CreateOrgScreen._submit`: ganti langkah 1-3 lokal menjadi: panggil repo RPC DULU → bila Ok, upsert hasil ke DAO lokal (Row dari server via select balik atau konstruksi dari input + id server) → `completeOnboarding` seperti semula; bila Err, tampilkan snackbar + JANGAN ubah state (tidak ada org setengah-jadi); fallback: bila RPC gagal karena jaringan, simpan draft lokal TANPA completeOnboarding (user tetap needsOnboarding; catat keterbatasan di komentar).
- Behavior yang dipertahankan: validasi form, loading state, snackbar sukses/gagal, navigasi `/bootstrap`.
- Error handling: timeout/offline → Err + tetap di onboarding; double-submit dicegah `_isLoading` (sudah ada); RPC idempotent? TIDAK (tiap panggil bikin org baru) — guard double-tap sudah cukup + catat di komentar.
- Test: `flutter test` existing auth/onboarding (bila ada); tambah `test/features/onboarding/create_org_rpc_test.dart` dengan mock `AuthRepository`? Repo memakai Riverpod + mocktail tersedia: mock rpc wrapper minimal — bila terlalu kompleks untuk model kecil, ganti dengan test DTO respons (parse Ok/Err dari map) + catat di Progress Log. Deterministik pilih: test parse respons (bukan mock Supabase).
- Command verifikasi: `flutter analyze`, `flutter test`, MCP cek fungsi+grant, `list_migrations` memuat versi baru.
- Hasil yang diharapkan: org kedua tercipta atomik dari HP; riwayat +1.
- Completion criteria: RPC live + onboarding memakainya + test parse hijau.
- Tidak boleh diubah: policy existing selain grant baru; alur bootstrap/pull.

## S-14 Stamp org pada pembuatan data baru

- Tujuan: tidak ada lagi baris NULL-org yang lahir dari app.
- Finding: F-APP-04.
- Dependency: S-11, S-12.
- File yang harus dibaca: pencari: semua `*.insert(` / `into(db.<tabel>)` di `lib/features/` (catalog, inventory, customers, bank_accounts, modifiers, settings) + `CheckoutUseCase` (transaksi: isi `organization_id`? TIDAK — tx branch-scoped; pastikan saja branch-nya ber-org).
- File yang harus diubah: tiap call-site insert master (daftar eksplisit dibuat saat eksekusi via grep; pola seragam di bawah).
- Simbol: `currentOrganizationIdProvider`, companion field `organizationId: Value(orgId)`.
- Kondisi saat ini: insert tanpa org.
- Perubahan konkret (pola seragam per call-site): baca `ref.read(currentOrganizationIdProvider)`; bila null → tolak aksi dengan snackbar "pilih organisasi dulu" (jangan insert NULL); bila ada → sertakan `organizationId: Value(orgId)` di companion. Untuk branch-scoped (inventory/recipes/receipt_settings): ambil org dari branch induk via `getBranchById` (bila branch tak ber-org (legacy), tolak dengan pesan yang sama).
- Behavior yang dipertahankan: validasi form existing; tidak ada perubahan UI selain pesan tolak.
- Error handling: org null (single-tenant legacy / belum onboarding) → blokir + pesan; JANGAN default diam-diam.
- Test: tambah ke `org_backfill_test.dart` atau file baru `org_stamp_test.dart`: insert produk dengan org terisi → tersimpan; simulasi provider null → fungsi guard mengembalikan penolakan (uji helper murni `resolveOrgForInsert` bila diekstrak — WAJIB ekstrak helper murni agar testable: `String? resolveOrgForInsert(String? currentOrgId)` return null bila null/empty).
- Command verifikasi: `flutter analyze`, `flutter test`.
- Hasil yang diharapkan: hijau; grep `into(db.products)` dkk. semua didahului resolve org.
- Completion criteria: tidak ada path insert master yang bisa menghasilkan NULL-org dari UI.
- Tidak boleh diubah: pricing/checkout math, RLS, migrasi.

## S-15 Apply item 16 (GATED)

- Tujuan: aktifkan isolasi tenant di prod untuk tenant pertama yang sudah ter-stamp.
- Finding: F-SRV-07.
- Dependency: S-10 (patch), S-14 hijau + smoke pra-16 hijau (GATE; bila gagal, STOP, jangan apply).
- File yang harus dibaca: file 16 hasil patch S-10 (baca ulang diff).
- File yang harus diubah: none (sudah dipatch).
- Simbol: 61 policy baru, 2 helper rewrite.
- Kondisi saat ini: data ter-stamp (S-12/S-14 + data lama dari backfill no.15); app mengirim org.
- Perubahan konkret (urutan): (1) smoke pra-16 dari HP owner: edit 1 produk + 1 customer → sync → MCP cek `organization_id` terisi di kedua row; (2) `db query --linked -f` file 16; (3) verifikasi MCP SEGERA: count visible sebagai service_role tetap (44/109/134 + anggota), `pg_policies` memuat nama baru (`branches_select`, `products_write`, ...), `app_users_insert` baru mengandung `auth.jwt` (grep via `qual`); (4) smoke pasca-16 dari HP: buka katalog (44 terlihat), edit 1 produk → sync sukses (outbox tidak failed), invite user kedua → klaim → hapus undangan sukses; (5) repair `20260615000000`.
- Behavior yang dipertahankan: seluruh data (tidak ada hapus/ubah nilai; hanya kebijakan).
- Error handling: bila smoke pasca-16 gagal → rollback manual dari snapshot S-01 (recreate policy lama via Dashboard; JANGAN `db push`), catat insiden, STOP. Bila `db query` gagal di tengah (transaksional — seluruh file rollback oleh Postgres), baca error, perbaiki file (pre-apply-record, boleh), ulangi.
- Test: smoke manual di atas (tidak ada test otomatis untuk RLS prod).
- Command verifikasi: MCP counts + policy names + `get_advisors(security)` + `flutter test` (app tak tersentuh langkah ini, sanity).
- Hasil yang diharapkan: owner lihat 44/109/134; outbox push 0 failed; klaim user-2 sukses penuh.
- Completion criteria: semua smoke lolos + riwayat 33 entri (26 + 000002,17,18,000003,16,000001,000004).
- Tidak boleh diubah: data (hanya policy), file lain.

## S-16 Regresi akhir + handoff

- Tujuan: bukti final + serah terima.
- Dependency: S-15.
- File yang harus dibaca: file plan ini (update Tasks + Progress Log — satu-satunya edit file di langkah ini).
- File yang harus diubah: file plan ini saja.
- Perubahan konkret: (1) `flutter pub get`, `flutter analyze` (ekspektasi 0 error), `flutter test` (ekspektasi all passed); (2) MCP `list_migrations` (33 entri, tanpa gap), `get_advisors(security+performance)` catat sisa; (3) update Tasks `[x]` + Progress Log berdasi tanggal.
- Behavior: semua.
- Error handling: bila test gagal BARU (bukan baseline info-lint), investigasi + perbaiki akar (dilarang melemahkan test/nonaktifkan validasi); bila hanya info-lint baseline, catat jumlahnya.
- Test: seluruh suite.
- Command verifikasi: ketiga command di atas + `git status --porcelain` (ekspektasi hanya file yang disengaja).
- Hasil yang diharapkan: hijau semua; riwayat migrasi kontinu 33.
- Completion criteria: laporan akhir berisi status/temuan/perbaikan/test/verifikasi/risiko/commit (tanpa hash bila belum commit — JANGAN commit di plan ini; commit adalah tugas terpisah atas instruksi user).
- Tidak boleh diubah: selain file plan ini (tanpa staging/commit).

## Risks

- Prod-direct tanpa staging: setiap apply RLS punya window menit berisiko. Mitigasi: snapshot S-01 + verifikasi segera + rollback manual siap. Counter: menunda 16 selamanya membuat drift app↔server melebar — batas 1 sprint.
- `db query` mengeksekusi file utuh transaksional: gagal di tengah = tidak ada perubahan parsial (aman), tapi pastikan tidak ada statement non-transaksional (tidak ada di file-file ini).
- TD-001 build_runner: S-11 wajib hapus `.dart_tool/build` dulu; bila codegen tetap crash = blocker, stop.
- Double-org lokal bila user sudah punya >1 org saat backfill S-11: dipilih LEWATI + log (aman, tidak tebak).

## Open Questions / Blockers

- B-01: Billing tahap 6–7 ditunda (asumsi). Opsi: ikutkan bila user meminta — risiko: scope +2-3 hari (entitlement check di checkout + UI paywall). Rekomendasi: tunda (diputuskan implisit; konfirmasi ulang bila ragu).
- B-02: Identitas owner prod = user (asumsi). Bila bukan, smoke S-15 butuh kredensial owner aktual.
- B-03: 000001 repair-tanpa-jalan (dipilih eksplisit dengan alasan: isi dicakup no.15, RLS-nya berbahaya). Alternatif (ditolak): jalankan lalu cabut policy terbukanya — lebih banyak langkah tanpa manfaat.
- B-04: Klaim kode item 17 untuk org KEDUA butuh `updated_at` (diatasi S-04) dan versi PG (S-03); bila PG < 15, fallback index biasa sudah dispesifikasi di S-05.

## Progress Log

- 2026-09-25 15:00:00 — Plan dibuat; belum ada implementasi; S-01..S-16 pending.
- 2026-09-25 15:10:00 — S-01 done: snapshot `docs/saas-rls-snapshot-2026-09-25.sql` (81 policy public+storage + 8 definisi helper, tanpa secret). S-02 done: `app_users_insert` lama = owner-only `(user_global_role()='owner')`; self-claim jalan via OR dengan `app_users_self_claim_insert` — ini sekaligus mengoreksi klaim AND-semantics pada analisa kemarin: policy PERMISSIVE digabung OR, sehingga uba/invite self-claim SURVIVE item 16; yang tetap fatal hanya error 42501 `auth.users` (error ≠ false) + invisibilitas baris NULL-org + write master NULL-org ditolak. S-03 done: Postgres 17.6.1 → NULLS NOT DISTINCT didukung, S-05 lanjut.
- 2026-09-25 15:25:00 — S-04 done: insiden `.env`/`.env.local` (header tanpa `=` di L4 kedua file, ditambahkan sesi lain) membuat CLI gagal parse; diperbaiki dengan comment `#` tanpa menyentuh secret. Kolom `organization_id`+`updated_at` + index terverifikasi; repair 20260925000002 (riwayat 27).
- 2026-09-25 15:40:00 — S-05 done: `ADD CONSTRAINT IF NOT EXISTS` (sintaks invalid) diganti DO-guard; percobaan pertama gagal 23505 karena 2+ undangan email legacy NULL-join_code se-org (membuktikan NULLS NOT DISTINCT bertentangan dengan maksud file) → fallback partial unique index WHERE join_code IS NOT NULL; `db query` transaksional rollback bersih lalu sukses. Terverifikasi: 6 kolom, 3 index, `claim_invitation_code` SECURITY DEFINER + grant authenticated; repair 20260617 (riwayat 28).
- 2026-09-25 15:50:00 — S-06 done: file 18 hanya probe read-only + grant (dibaca penuh); `keep_alive_ping` + grant anon/authenticated terverifikasi; repair sempat gagal transien pooler EAUTHQUERY, retry sukses (riwayat 29).
- 2026-09-25 16:00:00 — S-07 done: grep konfirmasi satu-satunya `sb.rpc` adalah claim (authenticated). Terverifikasi: search_path pin di kedua trigger, anon hilang dari EXECUTE helper (tinggal authenticated), 6 policy owner ber-role `{authenticated}`; repair 20260925000003 (riwayat 30).
- 2026-09-25 16:05:00 — S-08 done: 000001 di-repair TANPA menjalankan isi (superseded by no.15); verifikasi 0 policy `*_read_auth` tercipta (riwayat 31).
- 2026-09-25 16:10:00 — S-09 done: 10/10 index terverifikasi via pg_indexes; repair 20260925000004 (riwayat 32).
- 2026-09-25 16:15:00 — S-10 done: 1 edit wajib (jwt) + header PATCH; grep `auth.users` tinggal 2 hit di komentar header sendiri (0 di SQL), `auth.jwt` di SQL; file BELUM tercatat di riwayat. M1+M2 selesai (S-01..S-10). Lanjut M3 app phase (S-11..S-14) sebelum S-15.
- 2026-09-25 16:45:00 — S-11 done: kolom org di 8 tabel Drift + company_settings raw + schemaVersion 24 + backfill sole-org; build_runner sukses (cache-clear TD-001); `org_backfill_test` 3/3 (solo/zero/multi). Deviasi: BranchProducts/Inventory*/Recipes/ReceiptSettings dilewati (server tak punya kolom; RLS branch-scoped); POG org diderivasi saat push.
- 2026-09-25 17:00:00 — S-12 done: push+pull org di Branch/Product/Category/Customer/CPL/OptionGroup/Option/BankAccount/CompanySetting; tx payload tetap org-free; POG push sertakan org dari produk lokal; `sync_org_stamp_test` 5/5; analyze 0 error.
- 2026-09-25 17:10:00 — S-13 done: migrasi baru `20260925000005_org_signup_rpc.sql` (`create_organization_with_owner`, SECURITY DEFINER, grant authenticated + REVOKE anon/PUBLIC) di-apply + repair (riwayat 33); `AuthRepository.createOrganization` + `CreateOrgScreen` sekarang memanggil RPC dulu, lalu persist lokal + completeOnboarding; `org_signup_rpc_test` 4/4.
- 2026-09-25 17:15:00 — S-14 done: helper murni `resolveOrgForInsert` + test 2/2; stamp org pada insert produk (form + CSV import + quick-add kategori), kategori (screen + quick-add), customer, bank account, option group/option, company_settings; CPL earn/void mewarisi org dari customer/earn ledger. Gate: `flutter analyze` 0 error; `flutter test` 153/153.
- 2026-09-25 17:20:00 — S-15 **BLOCKED (tidak di-apply)**: gate plan mewajibkan smoke pra-16 dari HP (edit produk → org terisi). Perangkat saat ini masih memakai APK 1.1.2+33 yang dibangun SEBELUM perubahan app-phase, jadi push master-nya tidak membawa `organization_id`. Menerapkan 16 sekarang akan membuat edit produk/customer dari HP ditolak RLS (outbox failed) — regresi nyata. Urutan yang benar: build + install APK baru (schema 24) → smoke pra-16 → baru apply 16.
- 2026-09-25 17:25:00 — S-16 (sebagian) — verifikasi read-only prod pasca S-13: owner aktif (`organization_members` role=owner status=active), 0 baris NULL-org di branches/products/customers/categories/option_groups, data utuh (2 branch / 44 produk / 109 customer / 134 transaksi), riwayat migrasi kontinu 33 tanpa gap.
- 2026-09-25 16:30:00 — S-11 DEVIASI TERDOKUMENTASI vs teks plan: kolom org lokal HANYA untuk tabel yang server-nya punya kolom org (branches/products/categories/customers/option_groups/options/product_option_groups/bank_accounts/company_settings/pending_invitations/customer_point_ledger — terverifikasi 16 kolom via MCP). BranchProducts/InventoryItems/Movements/Recipes/ReceiptSettings DILEWATI (server tak punya kolomnya; RLS mereka branch-scoped; kirim org = error 400). ProductOptionGroups lokal dilewati; org-nya diderivasi dari produk saat push (S-12). PendingInvitations sudah punya kolom (skip).

## Notes

- Pola eksekusi server per item: `& "scripts/supabase-with-token.ps1" db query --linked -f <file>` dari repo root → verifikasi MCP read-only → `migration repair --status applied --linked <version>`. DILARANG `db push` (akan menyeret item tertunda lain).
- Env guard: token hanya via wrapper dari `.env.local`; dilarang `Get-Content .env.local`, `echo` token, atau paste secret ke chat/log. Log token hanya bentuk `token loaded (N chars, redacted)` (sudah bawaan script).
- Perintah Dart yang boleh: `flutter pub get`, `flutter analyze`, `flutter test`, `dart run build_runner build --delete-conflicting-outputs` (hanya S-11, setelah hapus cache), `flutter gen-l10n` bila ARB tersentuh (tidak direncanakan).
- Dilarang: staging/commit/push/tag, amend, `--no-verify`, force push, `apply_migration` MCP, edit migrasi yang sudah tercatat applied (14, 15, 1–13), edit `.g.dart` manual.

---

## Handoff Checklist (model eksekutor kecil)

- [ ] Kerjakan S-01 → S-10 berurutan (M1+M2); JANGAN sentuh apply 16 sebelum S-14 hijau.
- [ ] Setiap apply server: query-file → verifikasi MCP → repair → catat di Progress Log (versi + hasil hitungan).
- [ ] Setiap anomali verifikasi (kolom/policy/fungsi tak muncul, linter memburuk tak terduga): STOP, jangan repair, laporkan sebagai blocker.
- [ ] S-11: hapus `.dart_tool/build` sebelum build_runner; jangan sentuh `.g.dart` manual.
- [ ] Setiap finding wajib punya verifikasi: sebutkan nama query/test-nya di Progress Log.
- [ ] Jangan `git add/commit/push/tag`; jangan `db push`; jangan ubah area Out-of-scope.
- [ ] Akhiri S-16 dengan laporan: status, temuan+severity, perbaikan, test, hasil verifikasi, risiko sisa (tanpa commit).
