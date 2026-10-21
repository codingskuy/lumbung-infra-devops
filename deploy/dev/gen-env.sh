#!/usr/bin/env bash
# Membuat deploy/dev/.env berisi nilai ACAK lokal untuk dev-stack (idempoten: tidak menimpa yang ada).
# Nama variabel mengikuti .env.example di akar repo; nilai tidak pernah masuk git (deploy/dev/.gitignore).
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] && { echo ".env sudah ada; dipakai apa adanya"; exit 0; }
command -v openssl >/dev/null || { echo "openssl wajib" >&2; exit 2; }
umask 077
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
openssl genpkey -algorithm ed25519 -out "$tmp/priv.pem" 2>/dev/null
openssl pkey -in "$tmp/priv.pem" -pubout -out "$tmp/pub.pem"
# PEM satu baris dengan \n literal (compose mengurai \n dalam tanda kutip ganda).
oneline() { awk 'BEGIN{ORS="\\n"} {print}' "$1"; }
{
  echo "POSTGRES_PASSWORD=$(openssl rand -hex 16)"
  echo "JWT_ED25519_PRIVATE=\"$(oneline "$tmp/priv.pem")\""
  echo "JWT_ED25519_PUBLIC=\"$(oneline "$tmp/pub.pem")\""
  echo "DEVICE_API_KEY_GUDANG=$(openssl rand -hex 16)"
  echo "SERVICE_API_KEY=$(openssl rand -hex 16)"
} > .env
echo "deploy/dev/.env dibuat (nilai acak lokal)"
