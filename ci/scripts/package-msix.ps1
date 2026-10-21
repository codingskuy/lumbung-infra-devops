<#
.SYNOPSIS
  Merakit MSIX :gudang-desktop 1.0.0 (x64). Tanpa auto-update.
.DESCRIPTION
  1. Bila task Gradle `packageMsix` ada di :gudang-desktop, pakai itu.
  2. Jika tidak (Compose Desktop tidak menyediakannya bawaan), jalankan
     :gudang-desktop:createDistributable lalu bungkus dengan makeappx.exe
     memakai ci/msix/AppxManifest.template.xml.
  Penandatanganan: set MSIX_PFX_BASE64 + MSIX_PFX_PASSWORD (opsional). Tanpa itu MSIX tidak
  ditandatangani (cukup untuk sideload uji; pilot gudang wajib bertanda tangan).
#>
param(
  [Parameter(Mandatory)][string]$Version,
  [string]$OutDir = 'out',
  [string]$IdentityName = 'CodingSkuy.LumbungGudang',
  [string]$Publisher = 'CN=Coding-Skuy',
  [string]$ExeName = 'gudang-desktop.exe'
)
$ErrorActionPreference = 'Stop'

# MSIX butuh versi 4 segmen: 1.0.0 -> 1.0.0.0
$parts = $Version.Split('.')
if ($parts.Count -gt 4 -or ($parts | Where-Object { $_ -notmatch '^\d+$' })) { throw "Versi tidak valid: $Version" }
while ($parts.Count -lt 4) { $parts += '0' }
$msixVersion = $parts -join '.'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$outFile = Join-Path $OutDir "gudang-desktop-$Version-x64.msix"

$tasks = & ./gradlew :gudang-desktop:tasks --all --no-daemon -q | Out-String
if ($tasks -match 'packageMsix') {
  & ./gradlew :gudang-desktop:packageMsix --no-daemon
  if ($LASTEXITCODE -ne 0) { throw 'packageMsix gagal' }
  $found = Get-ChildItem -Recurse -Filter *.msix gudang-desktop/build | Select-Object -First 1
  if (-not $found) { throw 'Berkas .msix tidak ditemukan' }
  Copy-Item $found.FullName $outFile
} else {
  & ./gradlew :gudang-desktop:createDistributable --no-daemon
  if ($LASTEXITCODE -ne 0) { throw 'createDistributable gagal' }
  $appDir = Get-ChildItem -Directory gudang-desktop/build/compose/binaries/main*/app | Select-Object -First 1
  if (-not $appDir) { throw 'Direktori aplikasi hasil createDistributable tidak ditemukan' }
  $exe = Get-ChildItem -Recurse -Filter $ExeName $appDir.FullName | Select-Object -First 1
  if (-not $exe) { throw "$ExeName tidak ditemukan di $($appDir.FullName)" }

  $stage = Join-Path $env:RUNNER_TEMP 'msix-stage'
  if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
  Copy-Item -Recurse $appDir.FullName $stage
  $assets = Join-Path $stage 'Assets'
  New-Item -ItemType Directory -Force -Path $assets | Out-Null
  $assetSrc = Join-Path $PSScriptRoot '..\msix\Assets'
  if (Test-Path $assetSrc) { Copy-Item "$assetSrc\*" $assets }
  else { Write-Warning 'ci/msix/Assets tidak ada; ikon wajib ditambahkan sebelum rilis pilot.' }

  $exeRel = [IO.Path]::GetRelativePath($stage, (Join-Path $stage ($exe.FullName.Substring($appDir.FullName.Length).TrimStart('\'))))
  (Get-Content (Join-Path $PSScriptRoot '..\msix\AppxManifest.template.xml') -Raw) `
    -replace '@@IDENTITY_NAME@@', $IdentityName -replace '@@PUBLISHER@@', $Publisher `
    -replace '@@VERSION@@', $msixVersion -replace '@@EXE@@', $exeRel |
    Set-Content (Join-Path $stage 'AppxManifest.xml') -Encoding utf8

  $makeappx = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin\*\x64\makeappx.exe' -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1
  if (-not $makeappx) { throw 'makeappx.exe (Windows SDK) tidak ditemukan di runner' }
  & $makeappx.FullName pack /d $stage /p $outFile /o
  if ($LASTEXITCODE -ne 0) { throw 'makeappx gagal' }
}

if ($env:MSIX_PFX_BASE64) {
  $pfx = Join-Path $env:RUNNER_TEMP 'msix.pfx'
  [IO.File]::WriteAllBytes($pfx, [Convert]::FromBase64String($env:MSIX_PFX_BASE64))
  $signtool = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe' | Sort-Object FullName -Descending | Select-Object -First 1
  & $signtool.FullName sign /fd SHA256 /f $pfx /p $env:MSIX_PFX_PASSWORD $outFile
  Remove-Item $pfx -Force
  if ($LASTEXITCODE -ne 0) { throw 'signtool gagal' }
} else {
  Write-Warning 'MSIX tidak ditandatangani (MSIX_PFX_BASE64 kosong).'
}
Write-Host "MSIX siap: $outFile"
