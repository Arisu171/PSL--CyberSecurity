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

WAIT_BOOT="4"
NAME_FORMAT='{{.Names}}'
PS_FORMAT='table {{.Names}}\t{{.Status}}\t{{.Image}}'

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; exit 1; }

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Khong tim thay compose file: $COMPOSE_FILE"
  exit 1
fi

note "Go default route Host gay can tro internet (neu co)"
sudo ip route del default via "$HOST_BAD_DEFAULT" 2>/dev/null || true

note "Don dep cac bai lab cu neu dang chiem subnet 10.2.6.0/24"
for old_compose in "/media/sf_.shared/scripts/lab02/docker-compose.yml" \
                   "/media/sf_.shared/scripts/lab03/docker-compose.yml" \
                   "/media/sf_.shared/scripts/lab04/docker-compose.yml" \
                   "/media/sf_.shared/scripts/lab99/docker-compose.yml"; do
  if [[ -f "$old_compose" ]]; then
    sudo docker compose -f "$old_compose" down 2>/dev/null || true
  fi
done
sudo docker network rm net-10.2.6.0 2>/dev/null || true
sudo docker network rm seed-net 2>/dev/null || true

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
response=$(sudo docker exec "$CONTAINER_USER" curl -s "http://${IP_WEB}/sqli/sqli1.html" | head -n 5)
if [[ -n "$response" ]]; then
  pass "Trang sqli1.html hoat dong binh thuong!"
else
  bad "Khong the truy cap http://${IP_WEB}/sqli/sqli1.html"
fi

echo -e "\n[✓] KHOI TAO LAB 05 (SQL INJECTION) THANH CONG!"
