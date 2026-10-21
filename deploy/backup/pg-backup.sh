#!/usr/bin/env bash
# Cadangan harian penuh DB logis `lumbung` (pg_dump format custom) + manifest jumlah baris + sha256.
# WAL diarsipkan terpisah (lihat docs/backup-restore.md).
#
# Variabel:
#   DATABASE_URL  wajib; harus menunjuk DB bernama `lumbung` (DB per service, dilarang DB divisi lain)
#   BACKUP_DIR    wajib; direktori tujuan
#   RETENTION_DAYS default 14
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL wajib}"
: "${BACKUP_DIR:?BACKUP_DIR wajib}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"

dbname="$(psql "$DATABASE_URL" -Atqc 'select current_database()')"
if [ "$dbname" != "lumbung" ]; then
  echo "TOLAK: DATABASE_URL menunjuk DB '$dbname', bukan 'lumbung'." >&2
  exit 2
fi

umask 077
mkdir -p "$BACKUP_DIR"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
out="$BACKUP_DIR/lumbung-$ts.dump"

pg_dump "$DATABASE_URL" --format=custom --no-owner --file="$out.partial"
mv "$out.partial" "$out"

# Manifest jumlah baris tiap tabel (dipakai uji restore sebagai pembanding).
psql "$DATABASE_URL" -Atq -F $'\t' -c "
  select quote_ident(schemaname)||'.'||quote_ident(relname) as t,
         (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I.%I', schemaname, relname), false, true, '')))[1]::text::bigint
  from pg_stat_user_tables order by 1" > "$out.counts"

( cd "$BACKUP_DIR" && sha256sum "$(basename "$out")" "$(basename "$out").counts" > "$(basename "$out").sha256" )

find "$BACKUP_DIR" -maxdepth 1 -name 'lumbung-*' -mtime +"$RETENTION_DAYS" -delete
echo "OK $out ($(wc -c < "$out") byte)"
