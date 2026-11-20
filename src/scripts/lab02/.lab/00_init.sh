#!/bin/bash
# Khoi tao Lab 02 tu thu muc du an (share), khong dung ban lab tren server.
# Bien cau hinh khai bao truoc, bien runtime gan xong roi moi duoc lenh phia duoi dung.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_LAB}/docker-compose.yml"

CONTAINER_USER="lab02_user"
CONTAINER_SERVER="lab02_server"
CONTAINER_ATTACKER="lab02_attacker"
CONTAINERS=("$CONTAINER_USER" "$CONTAINER_SERVER" "$CONTAINER_ATTACKER")

IP_USER="10.2.6.10"
IP_SERVER="10.2.6.20"
IP_ATTACKER="10.2.6.51"
IFACE="eth0"
MAC_FILE="/sys/class/net/${IFACE}/address"

PYTHON_BIN="python3"
TCPDUMP_BIN="tcpdump"
NC_BIN="nc"
SYSCTL_FORWARD="net.ipv4.ip_forward"
FORWARD_ON="1"

PING_COUNT="2"
PING_WARMUP="1"
PING_WAIT="1"
WAIT_BOOT="3"
PS_FORMAT='table {{.Names}}\t{{.Status}}\t{{.Image}}'
NAME_FORMAT='{{.Names}}'
LOSS_NONE="0% packet loss"

# Container cua cac lab khac co the dang chiem subnet 10.2.6.0/24
CLEANUP_LAB03=("user-10.2.6.5" "attacker-10.2.6.1" "local-dns-server-10.2.6.53" "attacker-ns-10.2.6.153")
CLEANUP_LAB04=("lab04_victim" "lab04_attacker" "lab04_user" "lab04_dns")
CLEANUP_LAB05=("lab05_webserver" "lab05_attacker" "lab05_user")
CLEANUP_LAB99=("lab99_target" "lab99_assessor")
SUBNET_NETS=("seed-net" "net-10.2.6.0")

USER_MAC=""
SERVER_MAC=""
ATTACKER_MAC=""
names=""
ping_out=""
user_arp=""
server_arp=""
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Khong thay compose cua du an: $COMPOSE_FILE"
  exit 1
fi

note "Tat cac lab khac neu dang chiem subnet 10.2.6.0/24"
# Xoa truc tiep theo ten container — khong phu thuoc file compose cua lab khac
sudo docker rm -f \
  "${CLEANUP_LAB03[@]}" \
  "${CLEANUP_LAB04[@]}" \
  "${CLEANUP_LAB05[@]}" \
  "${CLEANUP_LAB99[@]}" \
  2>/dev/null || true
for _net in "${SUBNET_NETS[@]}"; do
  sudo docker network rm "$_net" 2>/dev/null || true
done

note "Khoi dong container tu du an"
sudo docker compose -f "$COMPOSE_FILE" --project-directory "$PROJECT_LAB" up -d
sleep "$WAIT_BOOT"

note "Don tien trinh cu va ban ghi ARP tinh"
sudo docker exec "$CONTAINER_ATTACKER" pkill -9 "$PYTHON_BIN" 2>/dev/null || true
sudo docker exec "$CONTAINER_USER" pkill -9 "$TCPDUMP_BIN" 2>/dev/null || true
sudo docker exec "$CONTAINER_USER" pkill -9 "$NC_BIN" 2>/dev/null || true
sudo docker exec "$CONTAINER_SERVER" pkill -9 "$NC_BIN" 2>/dev/null || true
sudo docker exec "$CONTAINER_ATTACKER" iptables -F FORWARD 2>/dev/null || true
sudo docker exec "$CONTAINER_ATTACKER" sysctl -w "${SYSCTL_FORWARD}=${FORWARD_ON}" >/dev/null
sudo docker exec "$CONTAINER_USER" arp -d "$IP_SERVER" 2>/dev/null || true
sudo docker exec "$CONTAINER_SERVER" arp -d "$IP_USER" 2>/dev/null || true
sudo docker exec "$CONTAINER_USER" ip neigh flush all >/dev/null 2>&1 || true
sudo docker exec "$CONTAINER_SERVER" ip neigh flush all >/dev/null 2>&1 || true

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

note "IP va MAC hien tai"
sudo docker exec "$CONTAINER_USER" ifconfig "$IFACE"
sudo docker exec "$CONTAINER_SERVER" ifconfig "$IFACE"
sudo docker exec "$CONTAINER_ATTACKER" ifconfig "$IFACE"

USER_MAC="$(sudo docker exec "$CONTAINER_USER" cat "$MAC_FILE")"
SERVER_MAC="$(sudo docker exec "$CONTAINER_SERVER" cat "$MAC_FILE")"
ATTACKER_MAC="$(sudo docker exec "$CONTAINER_ATTACKER" cat "$MAC_FILE")"
echo "USER_MAC=$USER_MAC IP=$IP_USER"
echo "SERVER_MAC=$SERVER_MAC IP=$IP_SERVER"
echo "ATTACKER_MAC=$ATTACKER_MAC IP=$IP_ATTACKER"

note "Ping va ARP ban dau"
ping_out="$(sudo docker exec "$CONTAINER_USER" ping -c "$PING_COUNT" -W "$PING_WAIT" "$IP_SERVER" || true)"
echo "$ping_out"
sudo docker exec "$CONTAINER_SERVER" ping -c "$PING_WARMUP" -W "$PING_WAIT" "$IP_USER" >/dev/null || true
if grep -F -q "$LOSS_NONE" <<<"$ping_out"; then
  pass "User ping toi Server"
else
  bad "User khong ping duoc Server"
fi

user_arp="$(sudo docker exec "$CONTAINER_USER" arp -n)"
server_arp="$(sudo docker exec "$CONTAINER_SERVER" arp -n)"
echo "$user_arp"
echo "$server_arp"
if awk -v ip="$IP_SERVER" -v mac="$SERVER_MAC" '$1==ip && $3==mac { found=1 } END { exit !found }' <<<"$user_arp"; then
  pass "User anh xa ${IP_SERVER} dung MAC Server"
else
  bad "User chua co MAC that cua Server"
fi
if awk -v ip="$IP_USER" -v mac="$USER_MAC" '$1==ip && $3==mac { found=1 } END { exit !found }' <<<"$server_arp"; then
  pass "Server anh xa ${IP_USER} dung MAC User"
else
  bad "Server chua co MAC that cua User"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA KHOI TAO: PASS"
else
  echo "KET QUA KHOI TAO: FAIL"
fi
exit "$fail"
