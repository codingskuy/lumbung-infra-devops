# Rahasia (GitHub Actions secrets)

Aturan: nol nilai rahasia di repo. Nilai hanya ada di GitHub Actions secrets (per environment) atau `.env` lokal yang diabaikan git.
`ci/scripts/check-no-secrets.sh` (workflow `guard.yml`) menggagalkan CI bila ada kunci privat, URL DB berisi sandi, token, atau berkas `.env`/`.pem`/`.pfx`/`.keystore` ter-lacak.

## Inventaris

| Secret | Dipakai oleh | Cakupan | Rotasi |
|---|---|---|---|
| `DATABASE_URL` | backend, deploy, backup | HANYA DB logis `lumbung` (pengguna `lumbung_app`, tanpa `SUPERUSER`) | saat insiden / personel keluar |
| `JWT_ED25519_PRIVATE` | backend (penandatangan JWT, audiens `lumbung`) | environment backend saja | sesuai ADR keamanan; segera bila bocor |
| `DEVICE_API_KEY_GUDANG` | perangkat gudang (satu kunci per gudang) | endpoint perangkat | 90 hari + tenggang 7 hari |
| `SERVICE_API_KEY` | pipeline, ai-models (least-privilege: baca/ingest saja) | kontrak event | per ADR keamanan; ditinjau tiap 90 hari |
| `LUMBUNG_API_KEY` | web (sisi server) | kunci API web | 90 hari; cabut 1 jam bila bocor |

Catatan: issue LMB-OPS-004 mendaftar 4 secret; ADR-0001 dan AGENTS.md mendaftar 5 (tambahan `LUMBUNG_API_KEY`). Dokumen ini mengikuti ADR-0001 (5 secret).

Secret opsional rilis KMP: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `MSIX_PFX_BASE64`, `MSIX_PFX_PASSWORD` (lihat `ci/build-kmp.md`).

## Menyetel secret (tanpa menaruh nilai di riwayat shell)

```bash
# per environment (staging|prod); nilai dibaca dari stdin, bukan argumen
gh secret set DATABASE_URL --env prod --repo Coding-Skuy/<repo>          # ketik/tempel lalu Ctrl-D
gh secret set JWT_ED25519_PRIVATE --env prod --repo Coding-Skuy/<repo> < jwt_ed25519.pem   # berkas lokal di luar repo
gh secret list --env prod --repo Coding-Skuy/<repo>                        # verifikasi nama saja
```

Pembangkitan kunci JWT: `openssl genpkey -algorithm ed25519 -out jwt_ed25519.pem` (simpan di luar repo, hapus berkas setelah diunggah).
Kunci API acak: `openssl rand -base64 32`.

## Prinsip

- Satu environment = satu set secret; `staging` dan `prod` tidak berbagi nilai.
- Hak minimal: `lumbung_app` tanpa `SUPERUSER`; `SERVICE_API_KEY` hanya untuk cakupan yang dibutuhkan konsumen.
- Dilarang menyetel `DATABASE_URL` ke DB divisi lain (DB per service); skrip backup menolak DB selain `lumbung`.
- Log CI tidak boleh mencetak nilai secret; jangan `set -x` pada langkah yang memuat secret.
