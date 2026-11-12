#!/bin/bash
# Kich ban 2: ARP Request. Script chay la file trong du an.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
ATTACK_DIR="${PROJECT_LAB}/attack"
SCENARIO_HOST="${ATTACK_DIR}/scenario2.py"
SCENARIO_CONTAINER="/tmp/scenario2.py"

CONTAINER_USER="lab02_user"
CONTAINER_SERVER="lab02_server"
CONTAINER_ATTACKER="lab02_attacker"
CONTAINERS=("$CONTAINER_USER" "$CONTAINER_SERVER" "$CONTAINER_ATTACKER")

IP_USER="10.2.6.10"
IP_SERVER="10.2.6.20"
IFACE="eth0"
MAC_FILE="/sys/class/net/${IFACE}/address"
PCAP_FILE="/tmp/scenario2.pcap"
PYTHON_BIN="python3"
TCPDUMP_BIN="tcpdump"
PING_WARMUP="1"
PING_WAIT="1"
WAIT_DUMP="1"
WAIT_ATTACK="6"
WAIT_FLUSH="1"
NAME_FORMAT='{{.Names}}'
PCAP_REQUEST="Request who-has ${IP_USER} tell ${IP_SERVER}"
BROADCAST_MAC="ff:ff:ff:ff:ff:ff"

SERVER_MAC=""
ATTACKER_MAC=""
names=""
restored=""
user_arp=""
pcap=""
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

note "Khoi phuc ARP dong roi bat tcpdump"
sudo docker exec "$CONTAINER_ATTACKER" pkill -9 "$PYTHON_BIN" 2>/dev/null || true
sudo docker exec "$CONTAINER_USER" pkill -9 "$TCPDUMP_BIN" 2>/dev/null || true
sudo docker exec "$CONTAINER_USER" arp -d "$IP_SERVER" 2>/dev/null || true
sudo docker exec "$CONTAINER_USER" ip neigh flush all >/dev/null 2>&1 || true
sudo docker exec "$CONTAINER_USER" ping -c "$PING_WARMUP" -W "$PING_WAIT" "$IP_SERVER" >/dev/null

SERVER_MAC="$(sudo docker exec "$CONTAINER_SERVER" cat "$MAC_FILE")"
ATTACKER_MAC="$(sudo docker exec "$CONTAINER_ATTACKER" cat "$MAC_FILE")"
echo "SERVER_MAC=$SERVER_MAC"
echo "ATTACKER_MAC=$ATTACKER_MAC"
restored="$(sudo docker exec "$CONTAINER_USER" arp -n)"
echo "$restored"
if awk -v ip="$IP_SERVER" -v mac="$SERVER_MAC" '$1==ip && $3==mac { found=1 } END { exit !found }' <<<"$restored"; then
  pass "ARP da tro lai MAC that cua Server"
else
  bad "Khong khoi phuc duoc MAC that truoc kich ban 2"
fi

sudo docker exec "$CONTAINER_USER" rm -f "$PCAP_FILE"
sudo docker exec -d "$CONTAINER_USER" "$TCPDUMP_BIN" -i "$IFACE" -n -U -w "$PCAP_FILE" arp
sleep "$WAIT_DUMP"
sudo docker cp "$SCENARIO_HOST" "${CONTAINER_ATTACKER}:${SCENARIO_CONTAINER}"
sudo docker exec -d "$CONTAINER_ATTACKER" "$PYTHON_BIN" "$SCENARIO_CONTAINER"
sleep "$WAIT_ATTACK"
sudo docker exec "$CONTAINER_ATTACKER" pkill -f "$SCENARIO_CONTAINER" || true
sudo docker exec "$CONTAINER_USER" pkill -INT -f "$PCAP_FILE" || true
sleep "$WAIT_FLUSH"

note "ARP cache sau ARP Request gia"
user_arp="$(sudo docker exec "$CONTAINER_USER" arp -n)"
echo "$user_arp"
if awk -v ip="$IP_SERVER" -v mac="$ATTACKER_MAC" '$1==ip && $3==mac { found=1 } END { exit !found }' <<<"$user_arp"; then
  pass "${IP_SERVER} da tro toi MAC Attacker"
else
  bad "ARP Request khong dau doc duoc cache"
fi

note "Pcap ARP Request gia"
pcap="$(sudo docker exec "$CONTAINER_USER" "$TCPDUMP_BIN" -nn -e -r "$PCAP_FILE" arp 2>/dev/null || true)"
echo "$pcap"
if grep -F -q "$PCAP_REQUEST" <<<"$pcap" && grep -F -q "${ATTACKER_MAC} > ${BROADCAST_MAC}" <<<"$pcap"; then
  pass "pcap co ARP Request gia mao"
else
  bad "pcap khong co ARP Request gia mao"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA KICH BAN 2: PASS"
else
  echo "KET QUA KICH BAN 2: FAIL"
fi
exit "$fail"
