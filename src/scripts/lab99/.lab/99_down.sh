#!/bin/bash
# Dong Lab99: tat container/network lab99-net.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_LAB}/docker-compose.yml"
CONTAINERS=("lab99_target" "lab99_assessor")
NETWORK_NAME="lab99-net"
NAME_FORMAT='{{.Names}}'
PS_FORMAT='table {{.Names}}\t{{.Status}}\t{{.Image}}'
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "Dung Lab99"
sudo docker compose -f "$COMPOSE_FILE" --project-directory "$PROJECT_LAB" down 2>/dev/null || true
sudo docker rm -f "${CONTAINERS[@]}" 2>/dev/null || true
sudo docker network rm "$NETWORK_NAME" 2>/dev/null || true

note "Kiem tra"
sudo docker ps --format "$PS_FORMAT"
names="$(sudo docker ps --format "$NAME_FORMAT")"
for container in "${CONTAINERS[@]}"; do
  if grep -qx "$container" <<<"$names"; then
    bad "$container van chay"
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
  echo "KET QUA DONG LAB99: PASS"
else
  echo "KET QUA DONG LAB99: FAIL"
fi
exit "$fail"
