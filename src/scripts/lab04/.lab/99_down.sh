#!/bin/bash
# Dong Lab 04: tat container/network, giai phong subnet 10.2.6.0/24 cho cac lab khac.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_LAB}/docker-compose.yml"

CONTAINER_VICTIM="lab04_victim"
CONTAINER_ATTACKER="lab04_attacker"
CONTAINER_USER="lab04_user"
CONTAINER_DNS="lab04_dns"
CONTAINERS=("$CONTAINER_VICTIM" "$CONTAINER_ATTACKER" "$CONTAINER_USER" "$CONTAINER_DNS")
NETWORK_NAME="net-10.2.6.0"

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

note "Don dep cac tien trinh tan cong va bat goi tin"
sudo docker exec "$CONTAINER_ATTACKER" pkill -9 hping3 2>/dev/null || true
sudo docker exec "$CONTAINER_ATTACKER" pkill -9 -f saddam.py 2>/dev/null || true
sudo docker exec "$CONTAINER_VICTIM" pkill -9 tcpdump 2>/dev/null || true
sudo docker exec "$CONTAINER_VICTIM" pkill -9 -f telnetd.py 2>/dev/null || true
sudo pkill -9 -f "hping3.*10.2.6.20" 2>/dev/null || true

note "Dung container Lab 04"
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
  echo "KET QUA DONG LAB 04: PASS"
else
  echo "KET QUA DONG LAB 04: FAIL"
fi
exit "$fail"
