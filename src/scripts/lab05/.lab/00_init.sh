#!/bin/bash
# Khoi tao Lab 05 (SQL Injection): dung Web Server (Apache + PHP + MySQL) tren Docker
# Import co so du lieu webvul.sql va kiem tra ket noi toi ung dung web.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_LAB}/docker-compose.yml"

CONTAINER_WEB="lab05_webserver"
CONTAINER_ATTACKER="lab05_attacker"
CONTAINER_USER="lab05_user"
CONTAINERS=("$CONTAINER_WEB" "$CONTAINER_ATTACKER" "$CONTAINER_USER")

IP_WEB="10.2.6.80"
IP_ATTACKER="10.2.6.51"
IP_USER="10.2.6.10"
HOST_BAD_DEFAULT="192.168.117.2"
WEB_PATH_SQLI="/sqli/sqli1.html"

WAIT_BOOT="4"
NAME_FORMAT='{{.Names}}'
PS_FORMAT='table {{.Names}}\t{{.Status}}\t{{.Image}}'

# Container cua cac lab khac co the dang chiem subnet 10.2.6.0/24
CLEANUP_LAB02=("lab02_user" "lab02_server" "lab02_attacker")
CLEANUP_LAB03=("user-10.2.6.5" "attacker-10.2.6.1" "local-dns-server-10.2.6.53" "attacker-ns-10.2.6.153")
CLEANUP_LAB04=("lab04_victim" "lab04_attacker" "lab04_user" "lab04_dns")
CLEANUP_LAB99=("lab99_target" "lab99_assessor")
SUBNET_NETS=("net-10.2.6.0" "seed-net")

fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Khong tim thay compose file: $COMPOSE_FILE"
  exit 1
fi

note "Go default route Host gay can tro internet (neu co)"
sudo ip route del default via "$HOST_BAD_DEFAULT" 2>/dev/null || true

note "Don dep cac bai lab cu neu dang chiem subnet 10.2.6.0/24"
# Xoa truc tiep theo ten container — khong phu thuoc file compose cua lab khac
sudo docker rm -f \
  "${CLEANUP_LAB02[@]}" \
  "${CLEANUP_LAB03[@]}" \
  "${CLEANUP_LAB04[@]}" \
  "${CLEANUP_LAB99[@]}" \
  2>/dev/null || true
for _net in "${SUBNET_NETS[@]}"; do
  sudo docker network rm "$_net" 2>/dev/null || true
done

note "Khoi dong cac containers Lab 05"
sudo docker compose -f "$COMPOSE_FILE" --project-directory "$PROJECT_LAB" up -d --force-recreate
sleep "$WAIT_BOOT"

note "Kiem tra trang thai container"
sudo docker ps --format "$PS_FORMAT"
names="$(sudo docker ps --format "$NAME_FORMAT")"
for c in "${CONTAINERS[@]}"; do
  if grep -qx "$c" <<<"$names"; then
    pass "$c dang chay"
  else
    bad "$c chua khoi dong thanh cong"
  fi
done

note "Khoi chay Web Server va ung dung SQL Injection tren Web Server"
sudo docker exec "$CONTAINER_WEB" pkill -f webserver.py 2>/dev/null || true
sudo docker exec -d "$CONTAINER_WEB" python3 /var/www/html/sqli/webserver.py
sleep 1

note "Kiem tra truy cap ung dung Web tu may User"
response=$(sudo docker exec "$CONTAINER_USER" curl -s "http://${IP_WEB}${WEB_PATH_SQLI}" | head -n 5)
if [[ -n "$response" ]]; then
  pass "Trang ${WEB_PATH_SQLI} hoat dong binh thuong!"
else
  bad "Khong the truy cap http://${IP_WEB}${WEB_PATH_SQLI}"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA KHOI TAO LAB 05: PASS"
else
  echo "KET QUA KHOI TAO LAB 05: FAIL"
fi
exit "$fail"
