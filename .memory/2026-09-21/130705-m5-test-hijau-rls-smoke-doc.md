# M5 — Test Hijau + RLS Smoke Doc

**Task:** Perbaiki 5 test gagal pre-existing, tambah test sync/conflict, tulis RLS smoke checklist.

**Files:**
- `test/core/sync/sync_provider_test.dart` — tambah override `currentOrganizationIdProvider` → `'org-test'` (akar: `syncNow` skip pull bila org null).
- `test/core/utils/formatters_test.dart` — ekspektasi ikut CLDR/intl baru (`14:30`, bukan `14.30`).
- `test/widget_test.dart` — app boot ke `/login` (auth guard); assertion positif subtitle login + negatif `Kasir`; bounded `pump` dipertahankan.
- `test/core/sync/sync_conflict_test.dart` — baru (4 skenario): LWW master via `catalogDao.upsertProduct`; idempotensi tx via `insertOnConflictUpdate`; konvergensi inventory via dua `CheckoutUseCase.checkout` nyata (bukan simulasi aritmetika); outbox FIFO via `getPendingItems`.
- `docs/rls-smoke-checklist.md` — 4 cek manual di project dev (owner-write, kasir-ditolak, isolasi antar-org, anon-ditolak) + pola curl placeholder.

**Decisions:**
- Skenario 3 inventory memakai dua checkout nyata agar `cached_stock` yang di-assert adalah nilai rekonsiliasi produksi, bukan hasil hitung manual di test.
- RLS Cek 1 payload wajib `organization_id` (kolom multi-tenant); Cek 4 menerima `200 + []` sebagai lolos bila project izinkan anon read tapi policy menolak semua baris.

**Assumptions / Risks:**
- RLS smoke hanya di project dev + akun uji; tidak pernah prod.
- Test intl mengikuti library — bila CLDR berubah lagi, test memberi sinyal (bukan menyembunyikan).

**Blockers:** Tidak ada.

**Verification:**
- `flutter test` hijau penuh (126/126, 0 gagal).
- `flutter analyze` 0 error.

**Commit proposal:** `test: fix 5 pre-existing failures + add sync/conflict tests + RLS smoke doc`

**Related plans:** `plans/2026-09-21-hardening-backlog-sprint.md` (M5).
