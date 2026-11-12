#!/bin/bash
# Dong Lab 03: tat container/network, giai subnet 10.2.6.0/24 cho Lab 02.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_LAB}/docker-compose.yml"

CONTAINER_USER="user-10.2.6.5"
CONTAINER_ATTACKER="attacker-10.2.6.1"
CONTAINER_DNS="local-dns-server-10.2.6.53"
CONTAINER_ATTACKER_NS="attacker-ns-10.2.6.153"
CONTAINERS=("$CONTAINER_USER" "$CONTAINER_ATTACKER" "$CONTAINER_DNS" "$CONTAINER_ATTACKER_NS")
NETWORK_NAME="seed-net"
SNIFF_NAME="lab03-sniff-spoof"

NAME_FORMAT='{{.Names}}'
PS_FORMAT='table {{.Names}}\t{{.Status}}\t{{.Image}}'
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Khong thay compose cua du an: $COMPOSE_FILE"
  exit 1
fi

note "Don tien trinh phu (sniff/sender/tcpdump) neu con"
sudo docker exec "$CONTAINER_ATTACKER" pkill -9 -f hit_sender.py 2>/dev/null || true
sudo docker exec "$CONTAINER_ATTACKER" pkill -9 -x tcpdump 2>/dev/null || true
sudo docker exec "$CONTAINER_DNS" pkill -9 -x tcpdump 2>/dev/null || true
sudo docker rm -f "$SNIFF_NAME" 2>/dev/null || true
# Tranh pkill -f tu khop chinh no: chi giet process python sniff.
sudo pkill -9 -f "[p]ython3 .*/lab03/attack/sniff_spoof\\.py" 2>/dev/null || true

note "Dung container Lab 03"
sudo docker compose -f "$COMPOSE_FILE" --project-directory "$PROJECT_LAB" down 2>/dev/null || true
sudo docker rm -f "${CONTAINERS[@]}" 2>/dev/null || true
sudo docker network rm "$NETWORK_NAME" 2>/dev/null || true

note "Kiem tra da tat"
sudo docker ps --format "$PS_FORMAT"
names="$(sudo docker ps --format "$NAME_FORMAT")"
for container in "${CONTAINERS[@]}"; do
  if grep -qx "$container" <<<"$names"; then
    bad "$container van dang chay"
  else
    pass "$container da tat"
  fi
done
if sudo docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  bad "Network $NETWORK_NAME con ton tai"
else
  pass "Network $NETWORK_NAME da xoa"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA DONG LAB 03: PASS"
  echo "Co the chay Lab 02: bash /media/sf_.shared/scripts/lab02/.lab/00_init.sh"
else
  echo "KET QUA DONG LAB 03: FAIL"
fi
exit "$fail"
