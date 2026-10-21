# Dev-stack lokal

Backend (dibangun dari checkout `lumbung-backend-service`) + Postgres `lumbung`, via Docker Compose.
Siklus 3, tanpa tiket (usulan: dibuat manajer). Untuk pengembangan lokal saja, bukan produksi.

## Prasyarat

Docker (Compose v2), `openssl`, `curl`. Checkout `lumbung-backend-service` pada branch yang ingin dijalankan
(default: folder saudara `../lumbung-backend-service`; ganti dengan `BACKEND_DIR=/jalur/backend`).

## Perintah (dari akar repo)

| Perintah | Fungsi |
|---|---|
| `make dev-up` | bangun citra backend, nyalakan Postgres + backend, tunggu sehat |
| `make dev-seed` | semai akun uji (butuh `contract/seed.py` di backend dan `uvx`); hanya DB dev |
| `make dev-smoke` | smoke lintas-repo web/app -> backend nyata ([`ci/scripts/smoke-dev.sh`](../../ci/scripts/smoke-dev.sh)) |
| `make dev-logs` | log backend |
| `make dev-down` / `make dev-reset` | matikan / matikan dan hapus data DB dev |

Port (hanya `127.0.0.1`, dapat diganti lewat variabel): backend `18480` (`BACKEND_PORT`), Postgres `15532` (`DB_PORT`).

## Env dan rahasia

`make dev-up` menjalankan `deploy/dev/gen-env.sh`, yang membuat `deploy/dev/.env` berisi nilai ACAK lokal untuk nama-nama di
`.env.example` (kata sandi DB, pasangan kunci JWT Ed25519, `DEVICE_API_KEY_GUDANG`, `SERVICE_API_KEY`). Berkas itu diabaikan git
(`deploy/dev/.gitignore`); jangan commit. Hapus `deploy/dev/.env` untuk membangkitkan ulang (lalu `make dev-reset`).

## Catatan

- Citra dibangun dengan `cargo build --release --locked` (menit pertama lama; lapisan di-cache Docker).
- Basis data dev dan akun seed (PIN 123456) tidak boleh dipakai di luar mesin lokal.
- Mock kontrak (Prism) belum disertakan: `stoplight/prism:5` jatuh (`TypeError: ... isPrimary`) membaca `openapi.yaml` backend (OpenAPI 3.1) pada uji lokal. Tindak lanjut: mock lain atau Prism versi lebih baru; web/app memakai mock sendiri.

## Smoke lintas-repo

`make dev-smoke` meniru alur klien terhadap backend nyata: web (healthz, profil dan papan harga publik, admin menerbitkan papan harga dengan
`X-Service-Key`, cek bentuk papan dan fee Rp1.500/Rp2.500 per kg) dan app (login sopir, trip hari ini, gudang masuk dengan `X-Device-Key`).
Alur app dilewati (SKIP, bukan gagal) bila akun seed belum ada; jalankan `make dev-seed` dulu untuk cakupan penuh. Skrip hanya memakai HTTP,
jadi tidak membutuhkan kode web/app; untuk uji konsumen sebenarnya jalankan Pact/Maestro di repo masing-masing terhadap `http://127.0.0.1:18480`.
