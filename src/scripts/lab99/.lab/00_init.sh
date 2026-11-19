#!/bin/bash
# Lab99: khoi tao Ubuntu target + assessor tren Docker (subnet rieng 10.2.99.0/24).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_LAB}/docker-compose.yml"

CONTAINER_TARGET="lab99_target"
CONTAINER_ASSESSOR="lab99_assessor"
CONTAINERS=("$CONTAINER_TARGET" "$CONTAINER_ASSESSOR")
IP_TARGET="10.2.99.10"
IP_ASSESSOR="10.2.99.20"

WAIT_BOOT="5"
PING_COUNT="2"
PING_WAIT="1"
NAME_FORMAT='{{.Names}}'
PS_FORMAT='table {{.Names}}\t{{.Status}}\t{{.Image}}'
LOSS_NONE="0% packet loss"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Khong thay compose: $COMPOSE_FILE"
  exit 1
fi

mkdir -p "${PROJECT_LAB}/volumes/reports" "${PROJECT_LAB}/volumes/logs"

note "Build va khoi dong Lab99 (khong dung subnet Lab02/03)"
sudo docker compose -f "$COMPOSE_FILE" --project-directory "$PROJECT_LAB" build
sudo docker compose -f "$COMPOSE_FILE" --project-directory "$PROJECT_LAB" up -d --force-recreate
sleep "$WAIT_BOOT"

note "Danh sach container"
sudo docker ps --format "$PS_FORMAT"
names="$(sudo docker ps --format "$NAME_FORMAT")"
for container in "${CONTAINERS[@]}"; do
  if grep -qx "$container" <<<"$names"; then
    pass "$container dang chay"
  else
    bad "$container khong chay"
  fi
done

note "Ping Assessor -> Target"
if sudo docker exec "$CONTAINER_ASSESSOR" which ping >/dev/null 2>&1; then
  ping_out="$(sudo docker exec "$CONTAINER_ASSESSOR" ping -c "$PING_COUNT" -W "$PING_WAIT" "$IP_TARGET" || true)"
  echo "$ping_out"
  grep -F -q "$LOSS_NONE" <<<"$ping_out" && pass "Ping ${IP_TARGET}" || bad "Ping target that bai"
else
  nc_out="$(sudo docker exec "$CONTAINER_ASSESSOR" nc -z -v -w 2 "$IP_TARGET" 22 2>&1 || true)"
  echo "$nc_out"
  if grep -qiE "succeeded|open" <<<"$nc_out"; then
    pass "Ket noi ${IP_TARGET}:22 thanh cong"
  else
    bad "Ket noi target that bai"
  fi
fi

note "SSH target dang lang nghe (baseline: cong 22)"
ss_out="$(sudo docker exec "$CONTAINER_TARGET" ss -lnt | grep -E ':22|:2222' || true)"
echo "$ss_out"
grep -q ':22' <<<"$ss_out" && pass "SSH baseline port 22" || bad "SSH chua lang nghe"

echo
echo "Target=${IP_TARGET}  Assessor=${IP_ASSESSOR}  user=labuser"
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA KHOI TAO LAB99: PASS"
else
  echo "KET QUA KHOI TAO LAB99: FAIL"
fi
exit "$fail"
