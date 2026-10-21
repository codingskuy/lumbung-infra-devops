# Prosedur Rotasi Kunci

Sumber: `produk/50-autentikasi-perangkat.md` (TownHall), ADR-0001, AGENTS.md aturan 9. Jadwal ditinjau di kalender ops tiap 90 hari.

## Device key per gudang (90 hari, tenggang 7 hari)

1. H-14: buat kunci baru untuk gudang X (`openssl rand -base64 32`); catat tanggal terbit di log rotasi (tanpa nilai).
2. Hari-H: daftarkan kunci baru di backend untuk gudang X; kunci lama tetap berlaku (tenggang).
3. Pasang kunci baru di perangkat gudang X (provisioning perangkat) dan perbarui secret `DEVICE_API_KEY_GUDANG` (environment terkait).
4. Verifikasi: perangkat X mengirim satu timbangan uji dengan kunci baru (HTTP 200) dan satu permintaan memakai kunci lama masih lolos selama tenggang.
5. Hari-H+7: cabut kunci lama di backend; verifikasi kunci lama menghasilkan 401.
6. Catat selesai di log rotasi.

## Service key (least-privilege)

1. Terbitkan kunci baru dengan cakupan sama atau lebih sempit (jangan melebar).
2. Perbarui `SERVICE_API_KEY` dan konsumen (pipeline, ai-models) secara berurutan; jalankan satu panggilan uji.
3. Cabut kunci lama. Tinjau cakupan tiap 90 hari.

## Kunci API web (`LUMBUNG_API_KEY`, 90 hari)

1. Terbitkan kunci baru; perbarui secret environment web dan deploy ulang web (`deploy.yml`).
2. Verifikasi halaman `/ops`, `/rute`, `/papan-harga` memuat data.
3. Cabut kunci lama.

## Kunci JWT Ed25519 (`JWT_ED25519_PRIVATE`)

Rotasi mengikuti ADR keamanan backend (`docs/auth.md` backend). Akses 15 menit dan refresh 7 hari berarti token lama kedaluwarsa alami; terapkan kunci baru dengan masa tumpang tindih verifikasi (kid) bila backend mendukung.

## Kunci bocor (cabut dalam 1 jam)

1. T+0: nyatakan insiden; cabut kunci di backend (tanpa tenggang).
2. T+15 menit: terbitkan kunci pengganti, perbarui secret, deploy.
3. T+60 menit: pastikan kunci lama menghasilkan 401; periksa log akses untuk penggunaan tak sah.
4. Tulis ringkasan insiden (tanpa nilai kunci) di `docs/runbook.md` bagian insiden.

## Log rotasi (templat, isi tanpa nilai rahasia)

| Tanggal | Kunci | Gudang/Env | Operator | Tenggang berakhir | Verifikasi |
|---|---|---|---|---|---|
