#!/usr/bin/env bash
# Uji restore: pulihkan cadangan ke DB sementara, bandingkan jumlah baris dengan manifest, lalu hapus DB sementara.
# Tidak pernah menyentuh DB `lumbung` asli. Jadwal: mingguan (docs/backup-restore.md).
#
# Variabel:
#   ADMIN_URL    wajib; koneksi ke server Postgres UJI dengan hak CREATE DATABASE (db mana pun, mis. postgres)
#   BACKUP_FILE  opsional; default dump terbaru di BACKUP_DIR
#   BACKUP_DIR   dipakai bila BACKUP_FILE kosong
set -euo pipefail
: "${ADMIN_URL:?ADMIN_URL wajib}"
if [ -z "${BACKUP_FILE:-}" ]; then
  : "${BACKUP_DIR:?BACKUP_DIR atau BACKUP_FILE wajib}"
  BACKUP_FILE="$(find "$BACKUP_DIR" -maxdepth 1 -name 'lumbung-*.dump' | sort | tail -n 1)"
fi
[ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ] || { echo "Cadangan tidak ditemukan" >&2; exit 2; }

# 1. Integritas berkas
dir="$(dirname "$BACKUP_FILE")"; base="$(basename "$BACKUP_FILE")"
if [ -f "$BACKUP_FILE.sha256" ]; then
  ( cd "$dir" && sha256sum -c "$base.sha256" ) || { echo "GAGAL: sha256 tidak cocok" >&2; exit 1; }
fi

tmpdb="lumbung_restore_$(date -u +%Y%m%d%H%M%S)_$$"
# shellcheck disable=SC2329  # dipanggil lewat trap EXIT
cleanup() { psql "$ADMIN_URL" -qc "drop database if exists \"$tmpdb\"" >/dev/null 2>&1 || true; }
trap cleanup EXIT

psql "$ADMIN_URL" -qc "create database \"$tmpdb\"" 
# Ganti nama DB pada URL admin (URL postgres://.../<db>[?query]).
tmpurl="$(python3 - "$ADMIN_URL" "$tmpdb" <<'PY'
import sys, urllib.parse as u
p = u.urlsplit(sys.argv[1])
print(u.urlunsplit((p.scheme, p.netloc, "/" + sys.argv[2], p.query, "")))
PY
)"

# 2. Restore
pg_restore --no-owner --exit-on-error --dbname "$tmpurl" "$BACKUP_FILE"

# 3. Verifikasi jumlah baris vs manifest
status=0
if [ -f "$BACKUP_FILE.counts" ]; then
  while IFS=$'\t' read -r tbl expected; do
    actual="$(psql "$tmpurl" -Atqc "select count(*) from $tbl")"
    if [ "$actual" != "$expected" ]; then
      echo "BEDA $tbl: manifest=$expected restore=$actual" >&2; status=1
    fi
  done < "$BACKUP_FILE.counts"
else
  echo "PERINGATAN: manifest .counts tidak ada; hanya cek tabel > 0" >&2
  n="$(psql "$tmpurl" -Atqc "select count(*) from pg_stat_user_tables")"
  [ "$n" -gt 0 ] || status=1
fi

if [ "$status" = 0 ]; then echo "UJI RESTORE LULUS: $base"; else echo "UJI RESTORE GAGAL: $base" >&2; fi
exit "$status"
