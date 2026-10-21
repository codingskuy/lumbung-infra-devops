# Runbook Operasional Lumbung

## Basis Data `lumbung` Terpisah

- Basis data `lumbung` adalah Postgres khusus divisi Lumbung; jangan gabung dengan basis data divisi lain.
- Nama basis data: `lumbung`. Pengguna aplikasi: `lumbung_app` dengan hak minimal (tanpa `SUPERUSER`).
- Cadangan harian penuh + WAL; uji restore tiap pekan; ekspor SQLite gudang ke flashdisk tiap Jumat sore. Prosedur dan skrip: [`backup-restore.md`](backup-restore.md).
- Rahasia dan rotasi kunci: [`secrets.md`](secrets.md), [`rotasi-kunci.md`](rotasi-kunci.md).

## Tuning Pool Koneksi

- `sqlx` pool: `max_connections = min(2 × jumlah vCPU API, floor((postgres_max − 10) / jumlah replika))` (contoh: 4 vCPU, postgres_max 100, 2 replika → 8 koneksi per replika). Selalu ≤ postgres_max / replika.
- `acquire_timeout = 3s`; `min_connections = 2`; `idle_timeout = 300s`; `max_lifetime = 1800s`.
- Batas koneksi Postgres (`max_connections`) wajib ≥ total pool seluruh replika + 10 cadangan admin.

## `sqlx prepare` (Offline Check)

- Wajib jalan sebelum commit yang mengubah query SQL:
  ```bash
  cargo sqlx prepare --database-url "$DATABASE_URL"
  ```
- Hasilnya (direktori `.sqlx/`; format lama `sqlx-data.json` sudah usang) di-commit agar `cargo test` lolos tanpa DB hidup.

## Insiden Umum

- `healthz` gagal cek DB: periksa `DATABASE_URL`, konektivitas, dan pool penuh.
- Timbangan USB tidak terbaca: ganti port, periksa driver serial, restart layanan `gudang-desktop`.
- Printer thermal diam: cetak halaman uji, periksa kertas 58mm, pastikan status cetak tidak menggantung di backend.
