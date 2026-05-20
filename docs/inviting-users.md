# Panduan Mengundang Pengguna

Panduan untuk **Owner** yang ingin menambahkan kasir / manajer baru ke
KopiyanteaPOS via fitur Undangan (FEAT-006).

> **Konteks penting:** Aplikasi **tidak** otomatis kirim email / WA. Setelah
> Anda submit form undangan, Anda harus secara manual memberi tahu calon user
> bagaimana cara klaim. Magic-link email dikirim Supabase saat calon user
> melakukan langkah login mereka — bukan saat Anda submit undangan.

---

## Alur lengkap dari mulai sampai user aktif

```
[Owner submit undangan]
        │
        ▼
[pending_invitations row dibuat lokal + outbox]
        │  (Owner harus Sinkron)
        ▼
[Row tersinkron ke Supabase]
        │  (Owner manual kabari calon user via WA/SMS/lisan)
        ▼
[Calon user buka app → masukkan email → tap "Masuk via Link Email"]
        │
        ▼
[Supabase kirim magic-link email otomatis]
        │
        ▼
[Calon user klik link di email → app auto-open]
        │
        ▼
[Claim flow jalan otomatis:
   pending_invitations dihapus,
   app_users + user_branch_access dibuat]
        │
        ▼
[Calon user sekarang aktif & bisa login normal]
```

---

## Langkah 1 — Submit form undangan (Owner di aplikasi)

1. Login sebagai role **Owner**
2. **Settings → Pengguna**
3. Tap FAB "**Undang**" di pojok kanan bawah
4. Isi:
   - **Nama lengkap** — sesuai KTP / nama panggilan kerja
   - **Email** — harus email **aktif** yang user akses (untuk terima magic link)
   - **Role** — Manager atau Kasir (Owner tidak bisa diundang)
   - **Akses Cabang** — centang minimal 1 cabang (boleh multi-select)
5. Tap "**Kirim Undangan**"

### Validasi sebelum submit

- [ ] Email belum dipakai user existing (cek di list "Aktif")
- [ ] Email belum diundang sebelumnya (cek di list "Diundang")
- [ ] Email valid (ada `@` dan domain)
- [ ] Minimal 1 cabang dicentang

---

## Langkah 2 — Sinkron supaya undangan sampai ke Supabase

Setelah submit, undangan **belum** sampai ke server. Aplikasi simpan di
outbox lokal dulu.

1. Settings → tap "**Sinkron Sekarang**"
2. Cek section Sinkronisasi:
   - "Tersinkron" (badge hijau) → sukses
   - "N menunggu" → tunggu sebentar, sinkron lagi
   - "N gagal" → tap **"Lihat Antrian"** → cek error per row

### Verifikasi opsional di Supabase Dashboard

- Buka project → **Table Editor → pending_invitations**
- Harus ada row dengan email + nama + role + branch_ids_csv yang baru diisi

---

## Langkah 3 — Kabari calon user secara manual

Aplikasi tidak otomatis kirim notifikasi apapun ke calon user. Anda harus
kirim sendiri lewat WA / SMS / chat / lisan.

### Template pesan WhatsApp

> Halo [Nama],
>
> Kamu sudah diundang jadi [kasir/manajer] di Kopiyantea cabang
> [Nama Cabang]. Caranya untuk masuk pertama kali:
>
> 1. Install aplikasi Kopiyantea (link Play Store / kirim APK)
> 2. Buka aplikasi → layar Login
> 3. Masukkan email kamu: **[email-yang-tadi-diundang]**
> 4. Tap tombol **"Masuk via Link Email"** (jangan tap "Masuk" karena belum
>    punya password)
> 5. Cek inbox email kamu (cek juga folder Spam) — ada email dari Supabase
>    dengan subject "Magic Link"
> 6. Klik link **"Log In"** di email tersebut
> 7. Aplikasi Kopiyantea otomatis terbuka dan kamu sudah masuk
>
> Kalau gak nerima email setelah 5 menit, ulangi langkah 4 — Supabase akan
> kirim link baru.

### Catatan

- **Email harus sama persis** dengan yang Anda input di Langkah 1
  (case-insensitive, tapi typo tidak match)
- Magic link valid **1 jam** sejak dikirim — kalau expired, user request lagi
- Supabase **free tier** punya rate limit ~30 email/jam — kalau Anda undang
  banyak user sekaligus, magic link bisa delay sampai jam berikutnya

---

## Langkah 4 — Verifikasi user sudah aktif

Setelah calon user klik magic link, kembali ke Settings → Pengguna:

- **Sebelumnya:** undangan di section "**Diundang (belum aktif)**" dengan
  badge kuning
- **Setelah klaim:** pindah ke section "**Aktif**" dengan badge role hijau

### Verifikasi di Supabase Dashboard

| Table | Sebelum klaim | Sesudah klaim |
|---|---|---|
| `pending_invitations` | row ada | row dihapus |
| `auth.users` | tidak ada | row baru dengan email |
| `app_users` | tidak ada | row baru dengan full_name + global_role |
| `user_branch_access` | tidak ada | 1+ row sesuai cabang yang dicentang |

---

## Troubleshooting

### User klik magic link tapi tidak buka aplikasi

**Cek:**
- Aplikasi Kopiyantea sudah ter-install di device user?
- Deep link `kopiyantea://login-callback` terdaftar di Android intent-filter
  (lihat `android/app/src/main/AndroidManifest.xml`)
- Redirect URL `kopiyantea://login-callback` sudah di-whitelist di Supabase
  Dashboard → Authentication → URL Configuration → Redirect URLs

### User sudah login tapi belum jadi kasir/manajer

**Berarti claim flow tidak jalan.** Cek:
- Email di `pending_invitations` **sama persis** dengan email di
  `auth.users` (case-insensitive)
- User punya akses internet saat login pertama (claim butuh pull dari Supabase)
- Cek log Supabase → Authentication → Logs untuk error claim

### Email magic link tidak masuk

- Cek folder **Spam / Junk**
- Cek **rate limit** Supabase free tier (~30 email/jam)
- Untuk produksi: konfigurasi **SMTP custom** di Supabase Dashboard →
  Authentication → SMTP Settings (pakai SendGrid, Mailgun, AWS SES, dll.)

### Owner ingin batalkan undangan sebelum diklaim

Saat ini belum ada UI cancel — workaround:
- Supabase Dashboard → `pending_invitations` → cari row → Delete row
- Atau biarkan saja, undangan tidak punya expiry — selama email belum diklaim
  user, tidak mengganggu

(TODO: tambah swipe-to-delete di list undangan)

---

## Apa yang TIDAK perlu Anda lakukan

❌ Membuat password sementara untuk user — magic link tidak butuh password  
❌ Membuat row di `auth.users` manual via Supabase Dashboard — Supabase auto-create  
❌ Setting RLS / privilege manual — sudah handled migration 010 + 20260520120000  
❌ Mengirim password lewat WA — tidak ada password, hanya magic link  
❌ Restart app setelah undang — listener auth_provider akan auto-trigger claim
