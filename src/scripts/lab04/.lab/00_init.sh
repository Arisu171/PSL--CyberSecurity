#!/bin/bash
# Khoi tao Lab 04 (DoS): dung 4 container (Victim, Attacker, User, DNS)
# Thiet lap dich vu Telnet (port 23), kiem tra ket noi mang va baseline.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_LAB}/docker-compose.yml"

CONTAINER_VICTIM="lab04_victim"
CONTAINER_ATTACKER="lab04_attacker"
CONTAINER_USER="lab04_user"
CONTAINER_DNS="lab04_dns"
CONTAINERS=("$CONTAINER_VICTIM" "$CONTAINER_ATTACKER" "$CONTAINER_USER" "$CONTAINER_DNS")

IP_VICTIM="10.2.6.20"
IP_ATTACKER="10.2.6.51"
IP_USER="10.2.6.10"
IP_DNS="10.2.6.53"
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
                   "/media/sf_.shared/scripts/lab99/docker-compose.yml"; do
  if [[ -f "$old_compose" ]]; then
    sudo docker compose -f "$old_compose" down 2>/dev/null || true
  fi
done
sudo docker network rm net-10.2.6.0 2>/dev/null || true
sudo docker network rm seed-net 2>/dev/null || true

note "Khoi dong 4 containers Lab 04"
sudo docker compose -f "$COMPOSE_FILE" --project-directory "$PROJECT_LAB" up -d --force-recreate
sleep "$WAIT_BOOT"

note "Kiem tra danh sach container dang chay"
sudo docker ps --format "$PS_FORMAT"
names="$(sudo docker ps --format "$NAME_FORMAT")"
for c in "${CONTAINERS[@]}"; do
  if grep -qx "$c" <<<"$names"; then
    pass "$c dang chay"
  else
    bad "$c chua khoi dong thanh cong"
  fi
done

note "Khoi chay dich vu Telnet (port 23) tren Victim"
sudo docker exec "$CONTAINER_VICTIM" pkill -9 -f telnetd.py 2>/dev/null || true
sudo docker exec -d "$CONTAINER_VICTIM" python3 /attack/telnetd.py
sleep 1

note "Kiem tra ket noi ping giua cac may"
sudo docker exec "$CONTAINER_USER" ping -c 2 "$IP_VICTIM" && pass "User -> Victim OK" || bad "User -> Victim FAIL"
sudo docker exec "$CONTAINER_USER" ping -c 2 "$IP_ATTACKER" && pass "User -> Attacker OK" || bad "User -> Attacker FAIL"
sudo docker exec "$CONTAINER_USER" ping -c 2 "$IP_DNS" && pass "User -> DNS OK" || bad "User -> DNS FAIL"

note "Kiem tra ket noi Telnet ban dau tu User den Victim"
if sudo docker exec "$CONTAINER_USER" nc -z -w 2 "$IP_VICTIM" 23; then
  pass "Dich vu Telnet tren Victim (port 23) hoat dong binh thuong"
else
  bad "Khong the ket noi toi port 23 cua Victim"
fi

echo -e "\n[✓] KHOI TAO LAB 04 THANH CONG!"
