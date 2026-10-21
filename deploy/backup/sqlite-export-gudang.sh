#!/usr/bin/env bash
# Ekspor cadangan SQLite gudang ke flashdisk (tiap Jumat sore, FSD/10). Memakai .backup (aman saat DB dipakai).
# Variabel: SQLITE_DB (wajib), FLASHDISK_DIR (wajib; titik mount flashdisk, harus sudah ada)
set -euo pipefail
: "${SQLITE_DB:?SQLITE_DB wajib}"
: "${FLASHDISK_DIR:?FLASHDISK_DIR wajib}"
[ -f "$SQLITE_DB" ] || { echo "SQLite tidak ditemukan: $SQLITE_DB" >&2; exit 2; }
[ -d "$FLASHDISK_DIR" ] || { echo "Flashdisk belum terpasang: $FLASHDISK_DIR" >&2; exit 2; }
out="$FLASHDISK_DIR/gudang-$(date +%Y%m%d-%H%M).sqlite"
sqlite3 "$SQLITE_DB" ".backup '$out'"
[ "$(sqlite3 "$out" 'pragma integrity_check')" = "ok" ] || { echo "GAGAL: integrity_check" >&2; rm -f "$out"; exit 1; }
( cd "$FLASHDISK_DIR" && sha256sum "$(basename "$out")" > "$(basename "$out").sha256" )
echo "OK $out"
