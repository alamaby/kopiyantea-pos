# QA Device Matrix — KopiyanteaPOS

> Dokumen ini adalah panduan QA fisik di device nyata.
> Diisi oleh user/qa engineer saat test di perangkat Android/iOS.
> Model tidak mengklaim QA selesai tanpa eksekusi device nyata.

**Dibuat:** 2026-09-21
**Latar belakang:** Hardening Backlog Sprint M6 — dokumen QA device matrix untuk rilis berikutnya.

---

## Legenda

| Kolom | Keterangan |
|---|---|
| **Langkah** | Skenario yang harus dicoba di device |
| **Ekspektasi** | Perilaku yang diharapkan |
| **Hasil Dev** | Diisi saat test di device development (APK debug) |
| **Hasil Prod** | Diisi saat test di device production (AAB store build) |
| **Lolos/Gagal** | ✓ Lolos atau ✗ Gagal |

---

## Matriks Uji

| # | Langkah | Ekspektasi | Hasil Dev | Hasil Prod | Lolos/Gagal |
|---|---------|-----------|-----------|------------|-------------|
| 1 | **Fresh install** — uninstall app, install ulang dari APK/AAB, buka app | App meminta izin storage/bluetooth, langsung ke layar login (bukan splash POS) | | | |
| 2 | **Login** — masukkan email + password yang sudah terdaftar di Supabase dev | Berhasil masuk ke /onboarding (create/join org), tidak ada crash | | | |
| 3 | **Bootstrap — akses cabang** | Screen "Memuat akses cabang..." muncul → selesai → lanjut ke create/join org | | | |
| 4 | **Bootstrap — menu & stok** | Screen "Memuat menu & stok..." → pull produk/cabang dari Supabase berhasil | | | |
| 5 | **Bootstrap — riwayat** | Screen "Memuat riwayat transaksi..." → pull 100 tx terakhir berhasil | | | |
| 6 | **Checkout cash** — pilih produk → tambah ke keranjang → bayar cash → cetak struk | Transaksi tersimpan, struk muncul di printer Bluetooth, outbox pushed done | | | |
| 7 | **Checkout QRIS** — pilih produk → bayar QRIS → tap "Pembayaran Diterima" | Tx tersimpan, QRIS image tampil di struk (jika toggle ON) | | | |
| 8 | **Checkout transfer** — pilih rekening bank → bayar transfer | Tx tersimpan dengan bankAccountSnapshot, struk menampilkan info rekening | | | |
| 9 | **Outbox pending terlihat** — matikan WiFi, buat transaksi, nyalakan WiFi | Outbox queue muncul di Settings > Sinkronisasi dengan status "menunggu" | | | |
| 10 | **Kill app → background sync terkirim** — kill app saat offline, nyalakan lagi dengan WiFi | Outbox pending ter-drain otomatis, status berubah ke "done" dalam ≤ 30 detik | | | |
| 11 | **Reprint 58mm** — buka detail transaksi → "Cetak Ulang Struk" | Printer 58mm mencetak struk dengan logo di atas (default) | | | |
| 12 | **Reprint 80mm** — ganti paper width di settings → cetak ulang | Printer 80mm mencetak struk lebih lebar, logo tetap di posisi yang benar | | | |
| 13 | **Toggle QRIS di struk** — Settings > Tampilan Struk > "Cetak QRIS" OFF lalu ON | Saat QRIS OFF → struk tidak ada QR; saat ON → QR muncul | | | |
| 14 | **Nama kasir di struk** — Settings > Tampilkan nama kasir → OFF/ON | Saat ON → nama kasir muncul di header struk; saat OFF → tidak muncul | | | |
| 15 | **Void + tutup kas variance 0** — batalkan txcash → Tutup Kas dengan counted = expected | Void berhasil (tx tetap ada dengan status voided, stok balik); Tutup Kas menunjukkan variance Rp 0 ("Pas") | | | |

---

## Catatan Tambahan

### OEM Doze Mode (Android)
Beberapa OEM (Samsung, Xiaomi, OPPO) mematikan background task saat layar off. Jika background sync tidak berjalan:
- Buka Settings → Apps → KopiyanteaPOS → Battery → Non-optimized / Unrestricted
- Matikan "Optimize battery usage" untuk aplikasi ini

### Fallback Printer (PDF / Share)
Jika printer Bluetooth tidak tersedia:
- Settings > Printer > Pilih "Share PDF" sebagai fallback
- Struk akan di-share via sheet sharing OS (bukan cetak langsung)

### Workmanager Best-Effort iOS
- iOS tidak menjamin periodic background task
- User perlu manual tap "Sinkron Sekarang" di Settings jika data tidak tersinkron setelah buka app
- Ini adalah known limitation Apple

### Cara Isi Kolom Hasil
1. Jalankan test pada device fisik (bukan emulator)
2. Catat hasil di kolom "Hasil Dev" untuk build debug
3. Setelah release AAB ke Play Store, ulangi di device production
4. Tanda ✓ untuk lolos, ✗ untuk gagal dengan catatan kegagalan
