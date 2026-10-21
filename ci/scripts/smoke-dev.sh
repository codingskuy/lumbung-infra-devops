#!/usr/bin/env bash
# Smoke lintas-repo: meniru alur klien web (publik + admin kunci layanan) dan app (login sopir, gudang) terhadap
# backend NYATA di dev-stack. Hanya HTTP; tidak membutuhkan kode web/app.
#
# Variabel:
#   BASE_URL     wajib, mis. http://127.0.0.1:18480 (tanpa /v1)
#   SERVICE_KEY  wajib, X-Service-Key (SERVICE_API_KEY server)
#   DEVICE_KEY   opsional, X-Device-Key (DEVICE_API_KEY_GUDANG) untuk alur gudang
#   PIN          PIN akun seed (default 123456); alur app dilewati bila akun seed belum ada (make dev-seed)
# Keluar 0 bila semua pemeriksaan yang dijalankan lulus; SKIP tidak menggagalkan.
# shellcheck disable=SC2015  # pola `A && ok || bad` disengaja (ok tidak pernah gagal)
set -uo pipefail
: "${BASE_URL:?BASE_URL wajib}"
: "${SERVICE_KEY:?SERVICE_KEY wajib}"
PIN="${PIN:-123456}"
fail=0; pass=0; skip=0
ok()   { pass=$((pass+1)); echo "LULUS  $1"; }
bad()  { fail=$((fail+1)); echo "GAGAL  $1" >&2; }
skp()  { skip=$((skip+1)); echo "SKIP   $1"; }

BODY="$(mktemp)"; trap 'rm -f "$BODY"' EXIT
code() { # method url [curl args...] -> cetak status HTTP; badan respons ada di $BODY
  local m="$1" u="$2"; shift 2
  curl -sS -o "$BODY" -w '%{http_code}' -X "$m" "$u" "$@" 2>/dev/null || echo 000
}
expect() { # deskripsi status_diharapkan status_aktual
  case " $2 " in *" $3 "*) ok "$1 ($3)";; *) bad "$1: status $3, diharapkan $2";; esac
}
jget() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2],{"d":d}))' "$BODY" "$1" 2>/dev/null; }

echo "== Alur web (publik + admin) terhadap $BASE_URL"
s="$(code GET "$BASE_URL/healthz")";                expect "healthz" "200" "$s"
[ "$(jget 'd["db"]')" = "lumbung" ] && ok "healthz melaporkan DB lumbung" || bad "healthz tidak melaporkan DB lumbung"
s="$(code GET "$BASE_URL/v1/kesehatan")";           expect "kesehatan" "200" "$s"
s="$(code GET "$BASE_URL/v1/publik/profil")";       expect "profil publik" "200" "$s"
s="$(code GET "$BASE_URL/v1/publik/papan-harga")";  expect "papan harga publik (200 terbit / 404 belum)" "200 404" "$s"
s="$(code POST "$BASE_URL/v1/admin/papan-harga" -H 'content-type: application/json' -d '{}')"
expect "admin tanpa kredensial ditolak" "401 403" "$s"

senin="$(python3 - <<'PY'
import datetime, zoneinfo
n = datetime.datetime.now(zoneinfo.ZoneInfo("Asia/Jakarta")).date()
print((n - datetime.timedelta(days=n.weekday())).isoformat())
PY
)"
s="$(code POST "$BASE_URL/v1/admin/papan-harga" -H 'content-type: application/json' -H "X-Service-Key: $SERVICE_KEY" \
  -d "{\"uuid\":\"11111111-2222-4333-8444-555555555555\",\"berlaku_mulai\":\"$senin\",\"referensi\":[{\"komoditas\":\"cabai\",\"harga\":[35000,36000,35000]},{\"komoditas\":\"bawang\",\"harga\":[31200,30000,33000]},{\"komoditas\":\"kangkung\",\"harga\":[7000,7500,6800]}]}")"
# 201 baru, 200 uuid sama, 409 minggu itu sudah terbit dengan uuid lain: semuanya berarti "ada".
expect "admin terbitkan papan harga (kunci layanan)" "200 201 409" "$s"
s="$(code GET "$BASE_URL/v1/publik/papan-harga")";  expect "papan harga publik setelah terbit" "200" "$s"
if [ "$s" = 200 ]; then
  [ "$(jget 'sorted(d.keys())')" = "['bawang', 'berlaku', 'cabai', 'fee', 'kangkung']" ] \
    && ok "bentuk papan harga sesuai kontrak" || bad "bentuk papan harga tidak sesuai kontrak: $(cat "$BODY")"
  [ "$(jget 'd["fee"]')" = "{'dekat': 1500, 'jauh': 2500}" ] && ok "fee Rp1.500/Rp2.500 per kg" || bad "fee tidak sesuai angka terkunci"
fi

echo "== Alur app (login, gudang)"
s="$(code POST "$BASE_URL/v1/auth/masuk" -H 'content-type: application/json' -d "{\"akun\":\"sopir-02\",\"pin\":\"$PIN\"}")"
if [ "$s" = 200 ]; then
  ok "login sopir-02 (200)"
  tok="$(jget 'd["token"]')"
  s="$(code GET "$BASE_URL/v1/trip-hari-ini" -H "Authorization: Bearer $tok")"; expect "trip hari ini (sopir)" "200 404" "$s"
  s="$(code GET "$BASE_URL/v1/trip-hari-ini")"; expect "trip hari ini tanpa token ditolak" "401" "$s"
else
  skp "akun seed sopir-02 tidak ada (status $s); jalankan make dev-seed untuk alur app"
fi
if [ -n "${DEVICE_KEY:-}" ]; then
  s="$(code POST "$BASE_URL/v1/gudang/masuk" -H "X-Device-Key: $DEVICE_KEY" -H 'content-type: application/json' -d "{\"operator\":\"OPR-SORTIR-1\",\"pin\":\"$PIN\"}")"
  if [ "$s" = 200 ]; then ok "gudang masuk (200)"; else skp "gudang masuk status $s (butuh akun seed)"; fi
  s="$(code POST "$BASE_URL/v1/gudang/masuk" -H 'X-Device-Key: salah' -H 'content-type: application/json' -d '{"operator":"x","pin":"000000"}')"
  expect "kunci perangkat salah ditolak" "401 403" "$s"
fi

echo "== Ringkasan: lulus=$pass gagal=$fail skip=$skip"
[ "$fail" = 0 ]
