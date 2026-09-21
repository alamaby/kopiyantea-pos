# M6 — QA Matrix Doc

**Task:** Buat `docs/qa-device-matrix.md` (dokumen saja; eksekusi oleh user di device fisik).

**Files:**
- `docs/qa-device-matrix.md` — tabel Langkah | Ekspektasi | Hasil Dev | Hasil Prod | Lolos/Gagal, 15 baris wajib: fresh install → login → bootstrap 3 langkah → checkout cash/QRIS/transfer (+rekening) → outbox pending → kill app → background sync → reprint 58mm + 80mm (logo atas/bawah, toggle QRIS, nama kasir) → void → tutup kas variance 0. Catatan: OEM Doze + fallback PDF/share + workmanager best-effort iOS.
- `PROJECT_STATUS.md` + `.memory/README.md` — QA dicatat sebagai pending-eksekusi (user-side).

**Decisions:**
- Model tidak mengklaim QA done tanpa device nyata (aturan plan 6.2).

**Assumptions / Risks:** Tidak ada perubahan code di M6.

**Blockers:** Eksekusi QA fisik menunggu user (di luar scope model).

**Verification:** File matrix ada; status tercatat pending-eksekusi.

**Commit proposal:** `docs: add QA device matrix and update plan progress`

**Related plans:** `plans/2026-09-21-hardening-backlog-sprint.md` (M6).
