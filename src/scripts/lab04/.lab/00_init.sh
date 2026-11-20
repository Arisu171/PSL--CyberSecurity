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
PORT_TELNET="23"

WAIT_BOOT="4"
NAME_FORMAT='{{.Names}}'
PS_FORMAT='table {{.Names}}\t{{.Status}}\t{{.Image}}'

# Container cua cac lab khac co the dang chiem subnet 10.2.6.0/24
CLEANUP_LAB02=("lab02_user" "lab02_server" "lab02_attacker")
CLEANUP_LAB03=("user-10.2.6.5" "attacker-10.2.6.1" "local-dns-server-10.2.6.53" "attacker-ns-10.2.6.153")
CLEANUP_LAB05=("lab05_webserver" "lab05_attacker" "lab05_user")
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
  "${CLEANUP_LAB05[@]}" \
  "${CLEANUP_LAB99[@]}" \
  2>/dev/null || true
for _net in "${SUBNET_NETS[@]}"; do
  sudo docker network rm "$_net" 2>/dev/null || true
done

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

note "Khoi chay dich vu Telnet (port $PORT_TELNET) tren Victim"
sudo docker exec "$CONTAINER_VICTIM" pkill -9 -f telnetd.py 2>/dev/null || true
sudo docker exec -d "$CONTAINER_VICTIM" python3 /attack/telnetd.py
sleep 1

note "Kiem tra ket noi ping giua cac may"
if sudo docker exec "$CONTAINER_USER" ping -c 2 -W 1 "$IP_VICTIM" >/dev/null 2>&1; then
  pass "User -> Victim OK"
else
  bad "User -> Victim FAIL"
fi

if sudo docker exec "$CONTAINER_USER" ping -c 2 -W 1 "$IP_ATTACKER" >/dev/null 2>&1; then
  pass "User -> Attacker OK"
else
  bad "User -> Attacker FAIL"
fi

if sudo docker exec "$CONTAINER_USER" ping -c 2 -W 1 "$IP_DNS" >/dev/null 2>&1; then
  pass "User -> DNS OK"
else
  bad "User -> DNS FAIL"
fi

note "Kiem tra ket noi Telnet ban dau tu User den Victim"
if sudo docker exec "$CONTAINER_USER" nc -z -w 2 "$IP_VICTIM" "$PORT_TELNET"; then
  pass "Dich vu Telnet tren Victim (port $PORT_TELNET) hoat dong binh thuong"
else
  bad "Khong the ket noi toi port $PORT_TELNET cua Victim"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA KHOI TAO LAB 04: PASS"
else
  echo "KET QUA KHOI TAO LAB 04: FAIL"
fi
exit "$fail"
