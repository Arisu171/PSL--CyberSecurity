#!/bin/bash
# Muc 4.2: Sinh file binary DNS Query ip_req.bin bang gen_query.py trong du an.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
ATTACK_DIR="${PROJECT_LAB}/attack"
GEN_QUERY_HOST="${ATTACK_DIR}/gen_query.py"
REQ_BIN_NAME="ip_req.bin"
REQ_BIN_HOST="${ATTACK_DIR}/${REQ_BIN_NAME}"

CONTAINER_ATTACKER="attacker-10.2.6.1"
ATTACK_MOUNT="/attack"
PYTHON_BIN="python3"
NAME_FORMAT='{{.Names}}'

IP_SRC="10.2.6.1"
IP_DST="10.2.6.53"
UDP_SPORT="12345"
UDP_DPORT="53"
QNAME_SAMPLE="twysw.example.com"

names=""
gen_out=""
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

if [[ ! -f "$GEN_QUERY_HOST" ]]; then
  echo "Khong thay script du an: $GEN_QUERY_HOST"
  exit 1
fi

names="$(sudo docker ps --format "$NAME_FORMAT")"
if ! grep -qx "$CONTAINER_ATTACKER" <<<"$names"; then
  echo "Thieu $CONTAINER_ATTACKER. Chay 00_init.sh truoc."
  exit 1
fi

note "Thong tin Query se dung"
echo "IP nguon : $IP_SRC (Attacker)"
echo "UDP sport: $UDP_SPORT"
echo "IP dich  : $IP_DST (Local DNS)"
echo "UDP dport: $UDP_DPORT"
echo "QNAME mau: $QNAME_SAMPLE (attack se thay 5 ky tu dau)"

note "Chay gen_query.py tu file du an (mount /attack)"
gen_out="$(sudo docker exec "$CONTAINER_ATTACKER" bash -c "cd ${ATTACK_MOUNT} && ${PYTHON_BIN} gen_query.py && ls -la ${REQ_BIN_NAME}")"
echo "$gen_out"

if [[ -f "$REQ_BIN_HOST" ]]; then
  pass "Da tao ${REQ_BIN_HOST}"
  ls -lh "$REQ_BIN_HOST"
else
  bad "Khong thay ${REQ_BIN_HOST} tren thu muc du an"
fi
if grep -q "Created ${REQ_BIN_NAME}" <<<"$gen_out" || grep -q "$REQ_BIN_NAME" <<<"$gen_out"; then
  pass "gen_query.py chay thanh cong"
else
  bad "gen_query.py khong in ket qua mong doi"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA GEN QUERY: PASS"
else
  echo "KET QUA GEN QUERY: FAIL"
fi
exit "$fail"
