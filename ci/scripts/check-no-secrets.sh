#!/usr/bin/env bash
# Gagalkan CI bila ada pola rahasia ter-commit (kunci privat, URL DB berisi sandi, token GitHub/AWS, .env).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
bad=0
if git ls-files | grep -E '(^|/)\.env($|\.)|\.(pem|pfx|p12|keystore|jks)$' | grep -vE '\.env\.example$'; then
  echo "Berkas rahasia ter-lacak di atas." >&2; bad=1
fi
pat='-----BEGIN [A-Z ]*PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|postgres(ql)?://[^:/@ <]+:[^@ <$]+@'
# Dokumentasi memakai placeholder (<...>, $VAR, USER:PASS); skrip ini dikecualikan dari pemindaian.
hits="$(git grep -nIE -e "$pat" -- . ':!ci/scripts/check-no-secrets.sh' ':!versions' | grep -vE 'postgres(ql)?://[a-z_]+:(lumbung_ci|PASS|PASSWORD|<)' || true)"
if [ -n "$hits" ]; then
  echo "$hits"; echo "Pola rahasia ditemukan di atas." >&2; bad=1
fi
[ "$bad" = 0 ] && echo "Tidak ada rahasia ter-commit."
exit "$bad"
