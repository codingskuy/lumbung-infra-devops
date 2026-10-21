# Deploy Produksi Lumbung

## Topologi

- API: `lumbung-backend-service` (kontainer, 2 replika) di depan penyeimbang beban.
- Web: `lumbung-web` (statis/Node) di CDN.
- DB: Postgres khusus `lumbung` (terpisah dari divisi lain).

## Langkah Rilis

Dieksekusi oleh [`deploy/scripts/deploy.sh`](../scripts/deploy.sh) lewat workflow
[`deploy.yml`](../../.github/workflows/deploy.yml) (environment `prod`, disarankan Required reviewers):

1. Terapkan migrasi: `sqlx migrate run --database-url "$DATABASE_URL"`.
2. Gulirkan kontainer API ke citra baru (`DEPLOY_API_CMD`); tunggu `GET /healthz` menjawab `ok`.
3. Sebarkan web (`DEPLOY_WEB_CMD`); verifikasi halaman `/ops`, `/rute`, `/papan-harga` (`WEB_BASE_URL`).
4. Putar balik (`ROLLBACK_API_CMD`) bila `healthz` gagal 3 kali beruntun; skrip keluar dengan kode 1.

Menjalankan: Actions > "Deploy per environment" > Run workflow > `environment=prod`, `version=<tag>`.
Secara lokal (uji): `DRY_RUN=1 ENVIRONMENT=prod VERSION=x HEALTH_URL=... DEPLOY_API_CMD=... ROLLBACK_API_CMD=... deploy/scripts/deploy.sh`.

## Konfigurasi environment GitHub `prod`

| Jenis | Nama | Isi |
|---|---|---|
| Secret | `DATABASE_URL` | DB logis `lumbung` saja |
| Variabel | `HEALTH_URL` | mis. `https://api.<domain>/healthz` |
| Variabel | `DEPLOY_API_CMD`, `ROLLBACK_API_CMD` | perintah gulir dan putar balik (bergantung penyedia VPS/kontainer; belum ditetapkan, asumsi) |
| Variabel | `DEPLOY_WEB_CMD`, `WEB_BASE_URL` | opsional |

## Pasca-rilis

- Periksa log error 15 menit pertama.
- Pastikan pipeline `ingest-timbangan` tetap menulis ke DB `lumbung`.
- Jejak rilis: ringkasan job workflow mencatat environment, versi, dan waktu.
