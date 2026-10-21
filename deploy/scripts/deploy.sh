#!/usr/bin/env bash
# Rilis satu environment sesuai deploy/prod/README.md.
# Urutan: migrasi -> gulir API -> tunggu healthz -> sebarkan web -> verifikasi halaman.
# Putar balik otomatis bila healthz gagal 3 kali beruntun.
#
# Variabel (semua dari GitHub environment; tidak ada nilai rahasia di repo):
#   ENVIRONMENT (staging|prod), VERSION, DATABASE_URL (rahasia),
#   HEALTH_URL, DEPLOY_API_CMD, ROLLBACK_API_CMD, DEPLOY_WEB_CMD (opsional),
#   WEB_BASE_URL (opsional, untuk verifikasi /ops /rute /papan-harga),
#   HEALTH_RETRIES (default 30), HEALTH_INTERVAL detik (default 5),
#   DRY_RUN=1 (lewati migrasi sungguhan dan cetak langkah), SKIP_MIGRATE=1 (uji lokal).
set -euo pipefail

: "${ENVIRONMENT:?ENVIRONMENT wajib}"
: "${VERSION:?VERSION wajib}"
: "${HEALTH_URL:?HEALTH_URL wajib}"
: "${DEPLOY_API_CMD:?DEPLOY_API_CMD wajib}"
: "${ROLLBACK_API_CMD:?ROLLBACK_API_CMD wajib (rollback terdokumentasi, SRS 30)}"
case "$ENVIRONMENT" in staging|prod) ;; *) echo "ENVIRONMENT harus staging|prod" >&2; exit 2;; esac

HEALTH_RETRIES="${HEALTH_RETRIES:-30}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-5}"
FAIL_LIMIT=3

log() { printf '[deploy %s %s] %s\n' "$ENVIRONMENT" "$VERSION" "$*"; }

# healthz sehat bila HTTP 2xx dan badan memuat status ok: teks `ok` atau JSON {"status":"ok",...}
# (backend nyata menjawab {"db":"lumbung","status":"ok"}).
health_ok() {
  local body
  body="$(curl -fsS --max-time 5 "$HEALTH_URL" 2>/dev/null)" || return 1
  [ "$body" = "ok" ] || printf '%s' "$body" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"ok"'
}

rollback() {
  log "healthz gagal ${FAIL_LIMIT}x beruntun, putar balik"
  bash -c "$ROLLBACK_API_CMD"
  log "rollback dijalankan; periksa runbook insiden"
}

if [ "${SKIP_MIGRATE:-0}" = "1" ] || [ "${DRY_RUN:-0}" = "1" ]; then
  log "migrasi dilewati (SKIP_MIGRATE/DRY_RUN)"
else
  : "${DATABASE_URL:?DATABASE_URL wajib}"
  log "1/4 terapkan migrasi"
  sqlx migrate run --database-url "$DATABASE_URL"
fi

log "2/4 gulirkan API"
if [ "${DRY_RUN:-0}" = "1" ]; then log "(dry-run) $DEPLOY_API_CMD"; else bash -c "$DEPLOY_API_CMD"; fi

log "3/4 tunggu healthz (maks ${HEALTH_RETRIES}x, ${FAIL_LIMIT} gagal beruntun = rollback)"
consecutive=0
healthy=0
for i in $(seq 1 "$HEALTH_RETRIES"); do
  if health_ok; then healthy=1; break; fi
  consecutive=$((consecutive + 1))
  log "healthz belum ok (percobaan $i, gagal beruntun $consecutive)"
  if [ "$consecutive" -ge "$FAIL_LIMIT" ]; then
    rollback
    exit 1
  fi
  sleep "$HEALTH_INTERVAL"
done
[ "$healthy" = "1" ] || { rollback; exit 1; }
log "healthz ok"

if [ -n "${DEPLOY_WEB_CMD:-}" ]; then
  log "4/4 sebarkan web"
  if [ "${DRY_RUN:-0}" = "1" ]; then log "(dry-run) $DEPLOY_WEB_CMD"; else bash -c "$DEPLOY_WEB_CMD"; fi
  if [ -n "${WEB_BASE_URL:-}" ]; then
    for path in /ops /rute /papan-harga; do
      curl -fsS --max-time 10 -o /dev/null "${WEB_BASE_URL%/}$path" || { log "verifikasi $path GAGAL"; exit 1; }
      log "verifikasi $path ok"
    done
  fi
else
  log "4/4 DEPLOY_WEB_CMD kosong; web dilewati"
fi
log "selesai"
