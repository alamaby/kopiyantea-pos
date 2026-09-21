# RLS Smoke Checklist — KopiyanteaPOS

> Panduan smoke test Row Level Security (RLS) di Supabase.
> Jalankan di project **development** (bukan production).
> Gunakan akun uji, bukan admin/postgres.

**Tanggal dibuat:** 2026-09-21
**Latar belakang:** Hardening Backlog Sprint M5 — verifikasi RLS bekerja setelah migrasi `20260615000000_rls_rewrite_multitenant.sql`.

---

## Prasyarat

1. Project Supabase development aktif (tidak pause).
2. Ambil nilai dari environment / GitHub Secrets:
   - `SUPABASE_DEV_URL` → base URL (contoh: `https://xxxxx.supabase.co`)
   - `SUPABASE_DEV_PUBLISHABLE_KEY` → key publik (bukan service_role!)
3. Siapkan dua akun uji:
   - **Owner A** (`owner-a@example.test`) — punya organisasi `org-A`
   - **Owner B** (`owner-b@example.test`) — punya organisasi `org-B`
   - Minimal satu kasir di bawah masing-masing owner.
4. Jangan jalankan curl sebagai postgres superuser — PostgREST bypass RLS saat pakai service_role.

---

## Cek 1 — Owner-write OK

Owner harus bisa menulis data org-nya sendiri lewat REST.

```bash
URL="<SUPABASE_DEV_URL>"
KEY="<SUPABASE_DEV_PUBLISHABLE_KEY>"
JWT="<OWNER_A_JWT>"

# Contoh: insert produk ke org owner A
curl -X POST "$URL/rest/v1/products?select=id,name" \
  -H "apikey: $KEY" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{"name":"Test Product RLS","base_price":15000,"sku":"RLS-001"}'
```

**Ekspektasi:** HTTP 201 + body berisi row baru dengan `id`.
**Gagal jika:** HTTP 403 / 404 — berarti RLS menolak write owner.

---

## Cek 2 — Kasir-write Ditolak

Kasir TIDAK boleh menulis produk (hanya owner yang bisa).

```bash
JWT="<CASHIER_A_JWT>"

curl -v -X POST "$URL/rest/v1/products" \
  -H "apikey: $KEY" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"name":"HACK","base_price":0}'
```

**Ekspektasi:** HTTP 403 (Forbidden) atau error RLS deny.
**Gagal jika:** HTTP 201 — kasir berhasil menulis, RLS bocor.

---

## Cek 3 — Isolasi Antar-Org (select)

User org-A TIDAK boleh melihat data org-B.

```bash
# Owner A mencoba membaca semua produk (harusnya cuma milik org-A)
curl "$URL/rest/v1/products?select=id,name,organization_id" \
  -H "apikey: $KEY" \
  -H "Authorization: Bearer $JWT"
```

**Ekspektasi:** Hanya baris dengan `organization_id` milik org-A.
Ulangi dengan JWT owner B → harus dapat himpunan yang terpisah total.

---

## Cek 4 — Anon Ditolak

Request tanpa Authorization header harus ditolak.

```bash
curl -v "$URL/rest/v1/products?limit=1" \
  -H "apikey: $KEY"
```

**Ekspektasi:** HTTP 401 atau 403.
**Gagal jika:** HTTP 200 + daftar produk — RLS tidak aktif untuk anon.

---

## Catatan Penting

- Semua query di atas memakai publishable key (`sb_publishable_...`), **bukan** service_role secret.
- JWT didapat dari response login Supabase (`POST /auth/v1/token?grant_type=password`).
- SQL Editor di dashboard Supabase berjalan sebagai postgres — **melewati RLS**. Jangan gunakan untuk verifikasi RLS.
- Jika ada yang gagal, cek policy di tabel terkait:
  ```sql
  SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
  FROM pg_policies
  WHERE tablename IN ('products', 'branches', 'transactions');
  ```
- Report temuan ke channel #engineering dan tambahkan ke `docs/adr/` bila perlu policy adjustment.
