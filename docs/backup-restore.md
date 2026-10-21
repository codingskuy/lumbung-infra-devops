# Backup dan Uji Restore

Berlaku untuk DB logis `lumbung` (Postgres) dan SQLite gudang. Skrip di `deploy/backup/`.

## Harian penuh + WAL (Postgres)

- Penuh harian: `deploy/backup/pg-backup.sh` (pg_dump format custom + `.counts` + `.sha256`, retensi default 14 hari). Jadwal cron di server backup, mis. `30 18 * * *` UTC (01:30 WIB):
  ```bash
  DATABASE_URL=... BACKUP_DIR=/var/backups/lumbung deploy/backup/pg-backup.sh
  ```
  Skrip menolak DB selain `lumbung`.
- WAL: aktifkan pengarsipan pada server Postgres (ditulis, belum diuji di sini):
  ```
  wal_level = replica
  archive_mode = on
  archive_command = 'test ! -f /var/backups/lumbung-wal/%f && cp %p /var/backups/lumbung-wal/%f'
  ```
  Untuk produksi disarankan pgBackRest atau WAL-G (point-in-time recovery). Salin dump dan WAL ke penyimpanan di luar host (retensi sesuai kebijakan Finance).

## Uji restore mingguan

- Otomatis: workflow `restore-drill.yml` (Senin 03:00 WIB) membuktikan skrip pada Postgres bersih.
- Manual atas cadangan nyata (tiap pekan, catat hasil):
  ```bash
  ADMIN_URL=postgres://<user>@<host-uji>/postgres BACKUP_DIR=/var/backups/lumbung deploy/backup/pg-restore-test.sh
  ```
  Skrip memverifikasi sha256, memulihkan ke DB sementara `lumbung_restore_*`, membandingkan jumlah baris tiap tabel dengan manifest, lalu menghapus DB sementara. `ADMIN_URL` harus server UJI, bukan produksi.
- Lulus = keluar `UJI RESTORE LULUS` dan kode 0. Gagal = buka insiden.

## Ekspor SQLite gudang ke flashdisk (tiap Jumat sore)

```bash
SQLITE_DB=/path/gudang.sqlite FLASHDISK_DIR=/media/flashdisk deploy/backup/sqlite-export-gudang.sh
```
Memakai `.backup` (aman saat aplikasi berjalan), cek `integrity_check`, tulis sha256. Pada PC Windows gudang jalankan lewat Git Bash/WSL atau padanan `sqlite3.exe .backup` (belum ada versi PowerShell). Flashdisk dibawa ke kantor dan disalin ke penyimpanan cadangan.

## Pool Postgres (selaras `docs/runbook.md`)

- `max_connections` pool per replika <= `min(2 x vCPU, floor((postgres_max - 10) / jumlah_replika))`; contoh postgres_max=100, 2 replika, 4 vCPU -> 8.
- `acquire_timeout` = 3 detik; `min_connections` 2; `idle_timeout` 300 dtk; `max_lifetime` 1800 dtk.
