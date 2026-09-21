# Hardening Backlog Sprint — Implementasi Detail

Created: 2026-09-21 09:00:00

## Objective

Eksekusi 6 rekomendasi hardening sesuai pilihan user:

1. **Backup: opsi A** — kembalikan workflow backup terjadwal (rclone/GDrive + pg_dump).
2. **Arsip: `.kimchi/` + `backup_supabase/` dipindah ke luar repo** (bukan di-komit, bukan dihapus permanen).
3. **Drift org: bertahap** — plan ini hanya migrasi typed DAO (tanpa CI diff; CI diff jadi follow-up terpisah).
4. **Test: perbaiki** 5 test gagal pre-existing + tambah test sync/conflict + RLS smoke checklist.

Hasil akhir: working tree bersih dan ter-komit atomik, secret aman, tabel org typed Drift, `.memory/` aktif, test hijau, dokumen QA device siap dieksekusi user.

## Scope

Masuk:

- M1: triase working tree, arsip direktori lokal, restore `supabase-backup.yml`, komit atomik.
- M2: `.gitignore` + audit secret history + aturan rotasi.
- M3: inisialisasi `.memory/` + update `PROJECT_STATUS.md` minimal.
- M4: registrasi 4 tabel org ke `@DriftDatabase`, tulis ulang `OrganizationDao` typed, update semua caller, test DAO baru.
- M5: perbaiki 5 test gagal + test sync/conflict baru + `docs/rls-smoke-checklist.md`.
- M6: buat `docs/qa-device-matrix.md` (dokumen saja, eksekusi oleh user).

Keluar (eksplisit non-goal):

- CI diff DDL⇄Drift (follow-up plan terpisah, lihat `## Notes`).
- `usage_counters` tetap raw-SQL (`UsageCounterDao` tidak disentuh).
- Eksekusi QA device fisik, rotasi secret live, migrasi JWT signing keys.
- Mengubah path upgrade DB `from < 21` / `from < 22` (warisan, jangan disentuh).

Aturan kerja untuk semua milestone:

- Shell = PowerShell 7+ (`pwsh`), workdir = repo root. Jangan `cd` di dalam command, pakai `workdir`.
- **Dilarang `git add .`** sebelum M2 selesai. Selalu `git add <path eksplisit>`.
- Jangan pernah mencetak nilai secret ke chat/log/file. Placeholder saja (`sb_publishable_...placeholder`).
- Commit message: Conventional Commits satu baris, tanpa trailer `Co-authored-by`.
- Verifikasi tiap milestone: `flutter analyze` (target 0 error) dan `flutter test` (target hijau penuh di akhir M5).

## Milestones

1. M1 — Working tree bersih + backup kembali.
2. M2 — Secret hygiene.
3. M3 — Memori + status.
4. M4 — Org tables Drift typed.
5. M5 — Test hijau + RLS smoke doc.
6. M6 — QA matrix doc.

Urutan wajib M1 → M2 → M3 → M4 → M5 → M6. M2 boleh paralel M1, tetapi komit pertama apa pun harus setelah `.gitignore` baru.

## Tasks

### M1 — Triase working tree + arsip + backup (pertama)

- [ ] 1.1 Inventory. Jalankan dan catat output:
  ```powershell
  git status --short --branch
  git diff --stat
  git log --oneline -8
  ```
  Kondisi awal yang diketahui (2026-09-21): 9 file modified (`.env.example`, `supabase-ping*.yml`, `.gitignore`, `MASTER_PROMPT_v5.md`, `PROJECT_MEMORY.md`, `README.md`, `docs/PHASE_1_SETUP.md`, `lib/core/config/env.dart`) + ~30 untracked (`.kimchi/`, `backup_supabase/`, 5 migrasi supabase, `supabase/functions/`, `supabase/config.toml`, docs ADR/keep-alive/system-context, `plans/`, `.claude/`, `.env.dev`, `.env.stg`).
- [ ] 1.2 Arsip keluar repo. Copy dulu, verifikasi, baru hapus dari working tree:
  ```powershell
  New-Item -ItemType Directory -Force -Path "C:\Works\archives\kopiyantea-pos-2026-09-21"
  Copy-Item -Recurse -Force ".kimchi" "C:\Works\archives\kopiyantea-pos-2026-09-21\.kimchi"
  Copy-Item -Recurse -Force "backup_supabase" "C:\Works\archives\kopiyantea-pos-2026-09-21\backup_supabase"
  # verifikasi jumlah file sama, lalu:
  Remove-Item -Recurse -Force ".kimchi", "backup_supabase"
  ```
  `.env.dev` / `.env.stg` tetap di tempat (dibutuhkan dev, di-ignore di M2). `.claude/` tetap di tempat (tooling state, di-ignore di M2).
- [ ] 1.3 Restore workflow backup dari history (dihapus di `9973cb9`, isi 182 baris: pg_dump via `postgres:17-alpine`, sync 3 bucket S3, upload rclone, retensi 30 hari):
  ```powershell
  git show 9973cb9^:.github/workflows/supabase-backup.yml > .github/workflows/supabase-backup.yml
  ```
  Verifikasi file 182 baris dan berisi `BACKUP_REMOTE_ROOT`, `STORAGE_BUCKETS`, `rclone delete`. Secret yang dibutuhkan workflow (hanya di GitHub Secrets, tidak di repo): `RCLONE_CONFIG_BASE64`, `SUPABASE_DB_HOST/PORT/NAME/USER/PASSWORD`, `SUPABASE_S3_ENDPOINT/REGION/ACCESS_KEY_ID/SECRET_ACCESS_KEY`.
- [ ] 1.4 Komit atomik dengan `git add <path>` eksplisit, urutan:
  1. `ci(supabase): restore scheduled database and storage backup workflow` — `.github/workflows/supabase-backup.yml` (+ M2 `.gitignore` boleh digabung di sini atau komit sendiri sebelumnya).
  2. `feat(supabase): publishable keys and keep-alive edge probe` — `supabase/functions/keep-alive/`, `supabase/config.toml`, `supabase/migrations/20260702000000_keep_alive_rpc.sql`, `.github/workflows/supabase-ping*.yml`, `docs/supabase-keep-alive.md`, `lib/core/config/env.dart`, `.env.example`.
  3. `feat(saas): multi-tenant expand migration and RLS rewrite` — `supabase/migrations/20260613110000_*`, `20260615000000_*`, `20260617_*`, `20260612120000_*`, `docs/adr/0014-*`.
  4. `docs: refresh readme, setup guide and master prompt for new api keys` — `README.md`, `docs/PHASE_1_SETUP.md`, `MASTER_PROMPT_v5.md`, `docs/system-context.md`, `docs/2026-06-16-*`, `PROJECT_MEMORY.md`, `plans/`.
  Setelah tiap komit: `git status --short` untuk pastikan hanya sisa yang disengaja.
- Acceptance M1: `git status --short` tidak lagi menampilkan `.kimchi/`, `backup_supabase/`; `supabase-backup.yml` ter-commit; tidak ada file ter-komit via `git add .`.

### M2 — Secret hygiene

- [ ] 2.1 Perketat `.gitignore` (tambah di bawah blok `# Env / Secrets`):
  ```
  .env.dev
  .env.stg
  .env*.local
  backup_supabase/
  .kimchi/
  .claude/
  ```
  `*.jks` dan `key.properties` sudah ter-cover — jangan diubah.
- [ ] 2.2 Audit history (read-only, jangan print nilai):
  ```powershell
  git ls-files | Select-String -Pattern "env|jks|key.properties"
  git check-ignore .env .env.dev .env.stg upload-keystore.jks
  git log --all --oneline -- .env .env.dev .env.stg upload-keystore.jks key.properties
  ```
  Ekspektasi: `git ls-files` hanya menampilkan `.env.example` + `android/key.properties.example`; `check-ignore` sukses untuk keempat path; `git log` untuk path secret kosong (tidak pernah ter-commit).
- [ ] 2.3 Keputusan rotasi: jika audit 2.2 menemukan nilai asli pernah ter-commit/ter-push → JANGAN lanjut ke M4 sebelum user merotasi (Supabase keys via Dashboard → API Keys; keystore via build baru). Catat temuan di `.memory/` entry M3 sebagai blocker. Jika bersih → lanjut.
- Acceptance M2: `git check-ignore` sukses 4/4; tidak ada secret di `git ls-files`; komit `chore(git): ignore local env variants, archives and tooling state`.

### M3 — Memori + status (sebelum ubah code)

- [ ] 3.1 Buat `.memory/README.md` format aktif: timestamp last-updated, format version `v1`, Current state (2–4 kalimat), Active decisions (maks 5), Open items/blockers, link arsip `PROJECT_MEMORY.md`, Recent Entries (maks 20 link, awalnya 1). Jangan pindahkan isi legacy; hanya ekstrak yang masih aktif: (a) client memakai publishable key, (b) TD-001 resolved drift 2.21, (c) backup dihapus lalu direstore M1, (d) org tables masih raw-SQL (menjadi M4), (e) 5 test gagal pre-existing (menjadi M5).
- [ ] 3.2 Buat entry pertama `.memory/2026-09-21/HHmmss-hardening-sprint-kickoff.md` berisi: masalah, file kunci M1–M2, keputusan + risiko (format field: task, files, decisions, assumptions/risks, blockers, verification, commit proposal, related plans). Ganti `HHmmss` dengan jam lokal saat menulis.
- [ ] 3.3 Update `PROJECT_STATUS.md` minimal: ubah `Last updated` ke tanggal hari ini; tambah seksi `## Maintenance Log` di paling bawah (jangan tulis ulang histori fase) dengan 2 baris: migrasi publishable keys DONE + hardening sprint IN PROGRESS. Setelah M4–M6 selesai, tambahkan baris DONE per item.
- [ ] 3.4 Setelah M3, semua milestone berikutnya wajib menambah 1 entry `.memory/` per milestone + 1 baris Progress Log di plan file ini.
- Acceptance M3: `.memory/README.md` + 1 entry ada; `PROJECT_STATUS.md` tidak merusak fase lama.

### M4 — Org tables Drift typed (perubahan code terbesar; CI diff TIDAK termasuk)

Konteks: `lib/core/database/tables/organization_tables.dart` (113 baris) sudah berisi definisi Drift lengkap tetapi memakai nama kelas ber-underscore (`_Organizations`, `_OrganizationMembers`, `_SubscriptionPlans`, `_OrganizationSubscriptions`) dan tidak diregistrasi di `@DriftDatabase`. `lib/core/database/daos/organization_dao.dart` (328 baris) full raw-SQL + 4 plain data class di bawahnya (baris 226–328) + 4 mapper. TD-001 sudah resolved (drift 2.21), jadi unblock.

- [ ] 4.1 Rename kelas tabel: `_Organizations` → `Organizations`, `_OrganizationMembers` → `OrganizationMembers`, `_SubscriptionPlans` → `SubscriptionPlans`, `_OrganizationSubscriptions` → `OrganizationSubscriptions`. `@DataClassName(...)` tidak berubah. Hapus/ubah komentar "codegen blocked (TD-001)" menjadi catatan migrasi selesai + tanggal.
- [ ] 4.2 `lib/core/database/app_database.dart`: uncomment import `tables/organization_tables.dart`; uncomment 4 tabel di daftar `@DriftDatabase`; perbaiki komentar TD-001. **Jangan bump `schemaVersion`** (tetap 23): tabel sudah ada di device lama via blok `from < 21`, dan `onCreate → m.createAll()` otomatis mencakup tabel baru untuk fresh install. **Jangan ubah** blok `from < 21` (raw-SQL upgrade path) dan `_seedSubscriptionPlans()`.
- [ ] 4.3 Regenerasi: `dart run build_runner build --delete-conflicting-outputs`. Ekspektasi: `app_database.g.dart` kini berisi `OrganizationRow`, `OrganizationMemberRow`, `SubscriptionPlanRow`, `OrganizationSubscriptionRow` + Companion. Jika generator error, perbaiki dari pesan error pertama, jangan revert ke raw-SQL tanpa mencatat blocker di `.memory/`.
- [ ] 4.4 Tulis ulang `OrganizationDao` typed. Hapus semua `customStatement`/`customSelect`, semua `_map*Row`, dan 4 plain class (nama kini milik generated code). Pola per method:
  ```dart
  Future<OrganizationRow?> getOrganizationById(String id) =>
      (db.select(db.organizations)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<OrganizationRow>> getOrganizationsForUser(String userId) {
    final q = db.select(db.organizations).join([
      innerJoin(db.organizationMembers,
          db.organizationMembers.organizationId.equalsExp(db.organizations.id)),
    ])
      ..where(db.organizationMembers.userId.equals(userId) &
          db.organizationMembers.status.equals(OrganizationMemberStatus.active));
    return q.map((row) => row.readTable(db.organizations)).get();
  }

  Future<void> upsertOrganization(OrganizationRow row) =>
      db.into(db.organizations).insertOnConflictUpdate(row.toCompanion(false));
  ```
  Terapkan pola sama untuk member/plan/subscription. **Dilarang `insertOrReplace`**: `organization_members` punya FK cascade dari `organizations`, replace bisa menghapus member. Hanya `insertOnConflictUpdate`.
- [ ] 4.5 Update caller (panduan: jalankan `flutter analyze`, perbaiki tiap error `undefined class` dengan import `core/database/app_database.dart` sebagai sumber Row types):
  - `sync_dtos.dart`: field enum kini bertipe enum, bukan String. Push: `'business_type': businessType.name`, `'status': status.name`, `'role': role.name`, `'code': code.name`. Pull: parse String → enum via helper baru di file yang sama:
    ```dart
    T _byNameOr<T extends Enum>(List<T> values, String? raw, T fallback) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
      return fallback;
    }
    ```
    (`featuresJson` tetap `jsonEncode(json['features'])` — Supabase pakai kolom jsonb `features`, lokal pakai teks `features_json`.)
  - `create_org_screen.dart`: `businessType: _selectedBusinessType` (buang `.name`), `status: OrganizationStatus.active`, `role: OrganizationMemberRole.owner`, member `status: OrganizationMemberStatus.active`. Ganti import `organization_dao.dart` → `app_database.dart` untuk Row types (cek `enums.dart` sudah diimport).
  - `join_org_screen.dart` (`_onClaimSuccess`): `role: OrganizationMemberRole.values.byName(value.role)` (value.role String dari claim). Bungkus try/catch → fallback `cashier` bila tak dikenal.
  - `auth_repository.dart`, `organization_card.dart`, `entitlement` consumers: perbaiki tampilan enum (`row.status.name`) dan konstruktor yang masih pakai String. Jangan ubah logika bisnis.
  - `dao_providers.dart`: tidak berubah (tetap `Provider<OrganizationDao>`).
  - `clearOrganizationData()` di `app_database.dart`: tidak berubah (DELETE mentah tetap valid).
- [ ] 4.6 Test baru `test/core/database/organization_dao_test.dart` (ikut pola `test/helpers/test_db.dart` + `AppDatabase.memory()`): insert org + member + plan + subscription → baca balik sama; upsert menimpa name; `getOrganizationsForUser` join benar (user tanpa membership → list kosong); `clearOrganizationData` mengosongkan `organizations`/`organization_members`/`organization_subscriptions` tetapi mempertahankan `app_users` + `subscription_plans`.
- [ ] 4.7 Verifikasi M4: `dart run build_runner build --delete-conflicting-outputs` bersih; `flutter analyze` 0 error; `flutter test test/core/database/organization_dao_test.dart` hijau; smoke manual: fresh install (DB baru) + upgrade (DB lama v23) — tabel org terbaca di kedua jalur.
- Acceptance M4: tidak ada sisa `customStatement`/`customSelect`/`_map*Row`/plain `*Row` class di `organization_dao.dart` + `usage_counter_dao.dart`; grep `SUPABASE_ANON_KEY|supabaseAnonKey` di luar `plans/` dan worktree hanya sisa fallback yang disengaja di `keep-alive/index.ts`.

### M5 — Test hijau + RLS smoke doc

- [ ] 5.1 Perbaiki 2 test `test/core/sync/sync_provider_test.dart` (`forces a pull...`, `throttles...`, gejala `Expected <1> Actual <0>`): akar masalah adalah `syncNow` melewati pull bila `currentOrganizationIdProvider` null (lihat `sync_provider.dart:45`), sedangkan `_container` di test tidak meng-override provider org. Fix: tambah override di `_container` (file sudah import `auth_provider.dart`):
  ```dart
  currentOrganizationIdProvider.overrideWith((ref) => 'org-test'),
  ```
  Lalu `flutter test test/core/sync/sync_provider_test.dart` harus 5/5 hijau.
- [ ] 5.2 Perbaiki 2 test `test/core/utils/formatters_test.dart` (gejala `'22 Mei 2026, 14.30'` vs `'22 Mei 2026, 14:30'`): akar masalah adalah data locale CLDR/intl baru memakai `:` sebagai pemisah waktu id_ID, bukan `.`. Fix yang benar: ubah ekspektasi test ke output library (`'22 Mei 2026, 14:30'` dan `'14:30'`), bukan memaksa format. Grep juga kemungkinan ekspektasi `14.30` lain di `lib/`/`test/`.
- [ ] 5.3 Perbaiki `test/widget_test.dart` (gejala `find.text('Kasir')` 0 widget): aplikasi kini boot ke `/login` (auth guard) bukan placeholder POS. Fix: baca `lib/features/auth/login_screen.dart`, pilih 1 finder stabil (judul/button login), assert layar login muncul + tidak ada exception; hapus assert `Kasir`/`Lainnya`. Pertahankan bounded `pump` (jangan `pumpAndSettle` — menggantung di splash auth).
- [ ] 5.4 Test sync/conflict baru `test/core/sync/sync_conflict_test.dart` (pakai `AppDatabase.memory()` + `seedMinimal`):
  1. LWW master: insert produk lokal `updated_at` lama → simulasi pull dengan DTO server lebih baru via `catalogDao.upsertProduct` → assert field server menang.
  2. Idempotensi transaksi: insert tx id sama dua kali via `insertOnConflictUpdate`/companion → assert 1 row.
  3. Event inventory konvergen: dua movement `sale` untuk item sama → assert `cached_stock` = stok awal − jumlah kedua delta (keduanya apply, tidak ada yang hilang).
  4. Outbox FIFO: enqueue 3 entity → assert urutan drain = urutan insert.
- [ ] 5.5 Tulis `docs/rls-smoke-checklist.md` (manual, dijalankan user di project **dev**, bukan prod): tabel cek owner-write-OK, kasir-write-ditolak, isolasi antar-org (select org lain → 0 rows), anon-ditolak. Sertakan pola curl dengan placeholder (tanpa nilai asli):
  ```bash
  curl "$SUPABASE_URL/rest/v1/products?select=id&limit=1" \
    -H "apikey: $SUPABASE_PUBLISHABLE_KEY" \
    -H "Authorization: Bearer <USER_JWT>"
  ```
  Catatan: uji via REST dengan JWT user asli (bukan SQL Editor sebagai postgres yang bypass RLS).
- [ ] 5.6 Verifikasi M5: `flutter test` hijau penuh (0 gagal); `flutter analyze` 0 error.
- Acceptance M5: 5 gagal pre-existing hilang; 2 file test baru ada dan hijau; checklist RLS siap dijalankan user.

### M6 — QA matrix doc (dokumen saja)

- [ ] 6.1 Buat `docs/qa-device-matrix.md`: tabel kolom Langkah | Ekspektasi | Hasil Dev | Hasil Prod | Lolos/Gagal. Baris wajib (15): fresh install → login → langkah bootstrap ("akses cabang" → "menu & stok" → "riwayat") → checkout cash/QRIS/transfer (+rekening) → outbox pending terlihat → kill app → background sync terkirim → reprint 58mm + 80mm (logo atas/bawah, toggle QRIS, nama kasir) → void → tutup kas variance 0. Catatan OEM Doze + fallback PDF/share + workmanager best-effort iOS.
- [ ] 6.2 Tandai eksekusi sebagai user-side di plan Progress Log. Model tidak boleh mengklaim QA done tanpa device nyata.
- Acceptance M6: file matrix ada; `PROJECT_STATUS.md` + `.memory/` mencatat QA sebagai pending-eksekusi.

## Risks

- **Komit tercampur.** File seperti workflow ping memuat 2 tujuan (keep-alive + keys). Mitigasi: pesan komit jujur mencakup keduanya; jangan pecah hunk kecuali jelas terpisah (`git add -p` hanya bila yakin).
- **`git add .` tidak sengaja sebelum M2.** Mitigasi: M2 dikerjakan sebelum komit apa pun; bila ragu, `git status` dulu setiap kali.
- **Arsip terhapus permanen.** Mitigasi: copy → hitung file (`(Get-ChildItem -Recurse | Measure-Object).Count` di sumber vs arsip) → baru `Remove-Item`. Counter: arsip di luar repo tidak ter-versioned — catat path arsip di `.memory/` entry.
- **Regenerasi Drift merusak.** `.g.dart` 770KB+ bisa konflik. Mitigasi: M1 bersih dulu; bila codegen gagal, stop + catat blocker, jangan setengah migrasi (DAO typed + tabel unregistered = rusak).
- **Perubahan tipe String → enum merembet.** Mitigasi: `flutter analyze` sebagai kompas; perbaiki file per file; tidak ada logika bisnis yang diubah, hanya konstruktor/tampilan.
- **`insertOrReplace` menghapus member.** Sudah dilarang di 4.4 (FK cascade). Reviewer wajib grep `insertOrReplace` di file DAO org = harus 0 hasil.
- **Test intl rapuh lagi saat CLDR berubah.** Fix 5.2 mengikuti library, bukan memaksa pola — bila CLDR berubah lagi, test memberi sinyal, bukan menyembunyikan.
- **RLS smoke menyentuh data.** Hanya di project dev + akun uji; tidak pernah prod.
- **Asumsi yang harus dicek ulang saat implementasi:** (a) tidak ada secret pernah ter-push (baru dari `ls-files`, belum scan full history — M2.2 menutup ini); (b) tidak ada consumer tabel org selain yang terdaftar di grep (cek ulang dengan grep `organizations|organization_members` di `lib/` sebelum 4.4); (c) workflow backup lama masih kompatibel dengan secret saat ini (validasi via `workflow_dispatch` manual setelah restore).

## Progress Log

- 2026-09-21 08:43:00 — M1 (backup restore + working tree bersih) DAN M2 (secret hygiene / `.gitignore` audit) selesai atomik; 5 komit land. Arsip `.kimchi/` + `backup_supabase/` ke `C:\Works\archives\kopiyantea-pos-2026-09-21/`. `.memory/` inisialisasi + `PROJECT_STATUS.md` di-update. Lanjut M4.
- 2026-09-21 09:00:00 — Plan detail ditulis sesuai pilihan user (backup opsi A, arsip luar repo, drift bertahap tanpa CI diff, test diperbaiki). Belum ada eksekusi; implementasi dilanjutkan model lain.
- 2026-09-20 — Sprint sebelumnya: migrasi publishable keys sisi code selesai (lihat `plans/2026-09-20-supabase-new-api-keys-migration.md`).

## Notes

- Follow-up terpisah (di luar plan ini): **CI diff DDL⇄Drift** — job CI yang membandingkan kolom tabel org Supabase (`information_schema` atau file migrasi `20260613110000_*`) vs schema Drift, gagal bila divergen. Mulai sebagai warning sebelum jadi gate. Known gap untuk diff tersebut: Supabase `organization_subscriptions` punya `trial_ends_at` + `provider_subscription_id` yang tidak ada di Drift lokal; dan `subscription_plans.features` (jsonb) vs lokal `features_json` (teks) — putuskan saat menulis follow-up apakah kolom ditambah atau gap didokumentasikan.
- Referensi Supabase: mapping `anon` → publishable (publik, RLS), `service_role` → secret (backend only, `BYPASSRLS`); new keys hanya lewat header `apikey`.
- Setelah semua milestone DONE: update `PROJECT_STATUS.md` ( enumerasi DONE DEV → instruksikan QA device untuk DONE QA) dan tutup entry `.memory/` dengan commit proposal akhir.
