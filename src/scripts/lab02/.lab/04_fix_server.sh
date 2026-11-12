#!/bin/bash
# Ban fix: ARP tinh cho Server. scenario1.py lay tu thu muc du an.
# MAC Server gan vao bien truoc khi arp -s dung no.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
ATTACK_DIR="${PROJECT_LAB}/attack"
SCENARIO_HOST="${ATTACK_DIR}/scenario1.py"
SCENARIO_CONTAINER="/tmp/scenario1.py"

CONTAINER_USER="lab02_user"
CONTAINER_SERVER="lab02_server"
CONTAINER_ATTACKER="lab02_attacker"
CONTAINERS=("$CONTAINER_USER" "$CONTAINER_SERVER" "$CONTAINER_ATTACKER")

IP_SERVER="10.2.6.20"
IFACE="eth0"
MAC_FILE="/sys/class/net/${IFACE}/address"
PYTHON_BIN="python3"
TCPDUMP_BIN="tcpdump"
SYSCTL_FORWARD="net.ipv4.ip_forward"
FORWARD_OFF="0"
ARP_FLAG_STATIC="CM"
PING_WARMUP="1"
PING_COUNT="3"
PING_WAIT="1"
WAIT_ATTACK="6"
NAME_FORMAT='{{.Names}}'
LOSS_NONE="0% packet loss"

SERVER_MAC=""
names=""
static_arp=""
held_arp=""
ping_out=""
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

if [[ ! -f "$SCENARIO_HOST" ]]; then
  echo "Khong thay script du an: $SCENARIO_HOST"
  exit 1
fi

names="$(sudo docker ps --format "$NAME_FORMAT")"
for container in "${CONTAINERS[@]}"; do
  if ! grep -qx "$container" <<<"$names"; then
    echo "Thieu $container. Chay 00_init.sh truoc."
    exit 1
  fi
done

note "Don tan cong cu va lay MAC Server hien tai"
sudo docker exec "$CONTAINER_ATTACKER" pkill -9 "$PYTHON_BIN" 2>/dev/null || true
sudo docker exec "$CONTAINER_USER" pkill -9 "$TCPDUMP_BIN" 2>/dev/null || true
sudo docker exec "$CONTAINER_USER" arp -d "$IP_SERVER" 2>/dev/null || true
sudo docker exec "$CONTAINER_USER" ip neigh flush all >/dev/null 2>&1 || true
sudo docker exec "$CONTAINER_USER" ping -c "$PING_WARMUP" -W "$PING_WAIT" "$IP_SERVER" >/dev/null

SERVER_MAC="$(sudo docker exec "$CONTAINER_SERVER" cat "$MAC_FILE")"
echo "Gan ARP tinh ${IP_SERVER} -> ${SERVER_MAC}"
sudo docker exec "$CONTAINER_USER" arp -s "$IP_SERVER" "$SERVER_MAC"

note "Kiem tra co ${ARP_FLAG_STATIC}"
static_arp="$(sudo docker exec "$CONTAINER_USER" arp -n)"
echo "$static_arp"
if awk -v ip="$IP_SERVER" -v mac="$SERVER_MAC" -v flag="$ARP_FLAG_STATIC" '$1==ip && $3==mac && $4==flag { found=1 } END { exit !found }' <<<"$static_arp"; then
  pass "ARP tinh ${ARP_FLAG_STATIC} dung MAC Server"
else
  bad "Khong tao duoc ban ghi ${ARP_FLAG_STATIC}"
fi

note "Thu lai scenario1 tu file du an"
sudo docker exec "$CONTAINER_ATTACKER" sysctl -w "${SYSCTL_FORWARD}=${FORWARD_OFF}" >/dev/null
sudo docker cp "$SCENARIO_HOST" "${CONTAINER_ATTACKER}:${SCENARIO_CONTAINER}"
sudo docker exec -d "$CONTAINER_ATTACKER" "$PYTHON_BIN" "$SCENARIO_CONTAINER"
sleep "$WAIT_ATTACK"
sudo docker exec "$CONTAINER_ATTACKER" pkill -f "$SCENARIO_CONTAINER" || true

held_arp="$(sudo docker exec "$CONTAINER_USER" arp -n)"
echo "$held_arp"
if awk -v ip="$IP_SERVER" -v mac="$SERVER_MAC" -v flag="$ARP_FLAG_STATIC" '$1==ip && $3==mac && $4==flag { found=1 } END { exit !found }' <<<"$held_arp"; then
  pass "MAC Server giu nguyen sau tan cong"
else
  bad "Ban ghi tinh bi ghi de"
fi

note "Ping sau khi da gan ARP tinh"
ping_out="$(sudo docker exec "$CONTAINER_USER" ping -c "$PING_COUNT" -W "$PING_WAIT" "$IP_SERVER" || true)"
echo "$ping_out"
if grep -F -q "$LOSS_NONE" <<<"$ping_out"; then
  pass "$LOSS_NONE"
else
  bad "Ping khong thong sau khi fix"
fi

echo
echo "Ban ghi tinh van duoc giu. Xoa bang lenh: sudo docker exec ${CONTAINER_USER} arp -d ${IP_SERVER}"
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA FIX SERVER: PASS"
else
  echo "KET QUA FIX SERVER: FAIL"
fi
exit "$fail"
