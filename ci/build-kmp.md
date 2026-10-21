# CI — Build KMP (MSIX / APK)

Alur CI untuk `lumbung-app-kmp`. Implementasi: workflow reusable
[`.github/workflows/build-kmp.yml`](../.github/workflows/build-kmp.yml) di repo ini, dipanggil dari repo app.

## Cara memanggil (dari `lumbung-app-kmp`)

```yaml
# .github/workflows/release.yml di lumbung-app-kmp
name: Rilis
on:
  push:
    tags: ["v*"]
permissions:
  contents: write
jobs:
  build:
    uses: Coding-Skuy/lumbung-infra-devops/.github/workflows/build-kmp.yml@main
    with:
      version: ${{ github.ref_name }}      # ganti dengan versi tanpa awalan "v" bila perlu, mis. 1.0.0
      msix-runner: '["self-hosted","windows","gudang"]'   # default: "windows-latest"
      publish-release: true
    secrets: inherit
```

## APK Lapangan (`lapangan-mobile`)

1. Runner: `ubuntu-latest` + JDK 17 + Android SDK (sudah ada di image).
2. Urutan: `:lapangan-mobile:testReleaseUnitTest` (gerbang QA, tidak boleh dilewati) lalu `:lapangan-mobile:assembleRelease`.
3. Penandatanganan memakai secrets opsional `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Tanpa keystore, APK tidak bertanda tangan dan CI mengeluarkan peringatan (hanya uji internal). Modul `lapangan-mobile` wajib membaca `ANDROID_KEYSTORE_PATH` dan variabel di atas pada `signingConfigs` (kewajiban repo app-kmp).
4. Artefak: `lapangan-mobile-<versi>-*.apk`, disimpan 90 hari, dan diunggah ke GitHub Releases bila `publish-release: true`.

## MSIX Gudang (`gudang-desktop`)

1. Runner: `windows-latest`, atau runner mandiri berlabel `gudang` (`msix-runner`). Uji perangkat fisik hanya di runner `gudang`.
2. Urutan: `:gudang-desktop:jvmTest` lalu [`ci/scripts/package-msix.ps1`](scripts/package-msix.ps1).
3. Skrip memakai task `packageMsix` bila ada. Compose Desktop tidak punya task itu bawaan (hanya `packageMsi`/`packageExe`), jadi jalur bawaan adalah `createDistributable` lalu `makeappx pack` dengan [`ci/msix/AppxManifest.template.xml`](msix/AppxManifest.template.xml). Folder `ci/msix/Assets/` (ikon) harus ditambahkan sebelum rilis pilot.
4. Penandatanganan: secrets opsional `MSIX_PFX_BASE64` + `MSIX_PFX_PASSWORD`. Sertifikat pilot gudang wajib dipasang di PC gudang.
5. Tanpa auto-update: manifest tidak memuat `AppInstaller`/`UpdateSettings` (non-goal PRD/30). Pembaruan = instal MSIX versi baru secara manual.
6. Artefak: `gudang-desktop-<versi>-x64.msix` disimpan 365 hari (MSIX 1.0.0 untuk pilot).
7. Uji perangkat (hanya runner `gudang` fisik): baca serial timbangan sekali + cetak halaman uji thermal. Belum diotomasi di workflow; dijalankan manual sesuai `docs/runbook.md`.

## Kanal rilis

| Platform | Kanal | Status |
|---|---|---|
| Windows | MSIX/EXE di PC gudang (GitHub Releases) | Workflow ada |
| Android | Play Store + APK sideload (pedalaman) | APK dirakit; unggah Play Store manual |
| iOS | TestFlight/IPA | Belum diotomasi (butuh runner macOS + secrets Apple); tiket lanjutan |

## Cache

- `gradle/actions/setup-gradle` menyimpan cache Gradle antar jalan; build tetap reproduksibel (`--no-daemon`, versi terkunci di wrapper).
