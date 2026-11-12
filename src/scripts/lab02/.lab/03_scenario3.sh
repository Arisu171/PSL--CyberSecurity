#!/bin/bash
# Kich ban 3: MITM. mitm.py lay tu thu muc du an. File txt trong container chi de doc ket qua.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
ATTACK_DIR="${PROJECT_LAB}/attack"
SCENARIO_HOST="${ATTACK_DIR}/mitm.py"
SCENARIO_CONTAINER="/tmp/mitm.py"

CONTAINER_USER="lab02_user"
CONTAINER_SERVER="lab02_server"
CONTAINER_ATTACKER="lab02_attacker"
CONTAINERS=("$CONTAINER_USER" "$CONTAINER_SERVER" "$CONTAINER_ATTACKER")

IP_USER="10.2.6.10"
IP_SERVER="10.2.6.20"
NC_PORT="10101"
NC_BIN="nc"
NC_LISTEN_OPTS="-d -lp"
NC_WAIT_NORMAL="2"
NC_WAIT_MITM="3"
PAYLOAD="Hello Server from Nguyen Bao Long 223001756"
MITM_EXPECT="XXXXX XXXXXX XXXX XXXXXX XXX XXXX XXXXXXXXX"
NC_NORMAL_FILE="/tmp/nc_normal.txt"
NC_MITM_FILE="/tmp/nc_mitm.txt"

PYTHON_BIN="python3"
SYSCTL_FORWARD="net.ipv4.ip_forward"
FORWARD_ON="1"
PING_WARMUP="1"
PING_WAIT="1"
WAIT_LISTEN="1"
WAIT_POISON="4"
WAIT_READ="2"
NAME_FORMAT='{{.Names}}'

names=""
normal=""
mitm=""
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

cleanup_nc() {
  sudo docker exec "$CONTAINER_ATTACKER" pkill -9 "$PYTHON_BIN" 2>/dev/null || true
  sudo docker exec "$CONTAINER_SERVER" pkill -9 "$NC_BIN" 2>/dev/null || true
  sudo docker exec "$CONTAINER_USER" pkill -9 "$NC_BIN" 2>/dev/null || true
  sudo docker exec "$CONTAINER_ATTACKER" iptables -F FORWARD 2>/dev/null || true
}

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

note "Khoi phuc ARP hai chieu"
cleanup_nc
sudo docker exec "$CONTAINER_USER" arp -d "$IP_SERVER" 2>/dev/null || true
sudo docker exec "$CONTAINER_SERVER" arp -d "$IP_USER" 2>/dev/null || true
sudo docker exec "$CONTAINER_USER" ip neigh flush all >/dev/null 2>&1 || true
sudo docker exec "$CONTAINER_SERVER" ip neigh flush all >/dev/null 2>&1 || true
sudo docker exec "$CONTAINER_USER" ping -c "$PING_WARMUP" -W "$PING_WAIT" "$IP_SERVER" >/dev/null
sudo docker exec "$CONTAINER_SERVER" ping -c "$PING_WARMUP" -W "$PING_WAIT" "$IP_USER" >/dev/null

note "Truyen tin binh thuong"
sudo docker exec "$CONTAINER_SERVER" rm -f "$NC_NORMAL_FILE"
sudo docker exec -d "$CONTAINER_SERVER" sh -c "${NC_BIN} ${NC_LISTEN_OPTS} ${NC_PORT} > ${NC_NORMAL_FILE}"
sleep "$WAIT_LISTEN"
sudo docker exec "$CONTAINER_USER" sh -c "echo \"${PAYLOAD}\" | ${NC_BIN} -w ${NC_WAIT_NORMAL} ${IP_SERVER} ${NC_PORT}"
sleep "$WAIT_LISTEN"
normal="$(sudo docker exec "$CONTAINER_SERVER" cat "$NC_NORMAL_FILE" | tr -d '\r')"
normal="${normal%$'\n'}"
echo "TRUOC TAN CONG: [$normal]"
sudo docker exec "$CONTAINER_SERVER" pkill -9 "$NC_BIN" 2>/dev/null || true
if [[ "$normal" == "$PAYLOAD" ]]; then
  pass "thong diep goc nguyen ven"
else
  bad "thong diep goc sai"
fi

note "MITM thay chu va so bang X"
sudo docker exec "$CONTAINER_ATTACKER" sysctl -w "${SYSCTL_FORWARD}=${FORWARD_ON}" >/dev/null
sudo docker exec "$CONTAINER_ATTACKER" iptables -F FORWARD 2>/dev/null || true
sudo docker exec "$CONTAINER_ATTACKER" iptables -A FORWARD -p tcp --dport "$NC_PORT" -j DROP
sudo docker exec "$CONTAINER_ATTACKER" iptables -A FORWARD -p tcp --sport "$NC_PORT" -j DROP
sudo docker cp "$SCENARIO_HOST" "${CONTAINER_ATTACKER}:${SCENARIO_CONTAINER}"
sudo docker exec -d "$CONTAINER_ATTACKER" "$PYTHON_BIN" "$SCENARIO_CONTAINER"
sleep "$WAIT_POISON"

sudo docker exec "$CONTAINER_SERVER" rm -f "$NC_MITM_FILE"
sudo docker exec -d "$CONTAINER_SERVER" sh -c "${NC_BIN} ${NC_LISTEN_OPTS} ${NC_PORT} > ${NC_MITM_FILE}"
sleep "$WAIT_LISTEN"
sudo docker exec "$CONTAINER_USER" sh -c "echo \"${PAYLOAD}\" | ${NC_BIN} -w ${NC_WAIT_MITM} ${IP_SERVER} ${NC_PORT}"
sleep "$WAIT_READ"
mitm="$(sudo docker exec "$CONTAINER_SERVER" cat "$NC_MITM_FILE" | tr -d '\r')"
mitm="${mitm%$'\n'}"
echo "SAU MITM: [$mitm]"

cleanup_nc
if [[ "$mitm" == "$MITM_EXPECT" ]]; then
  pass "thong diep da bi thay bang X"
else
  bad "thong diep MITM sai"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA KICH BAN 3: PASS"
else
  echo "KET QUA KICH BAN 3: FAIL"
fi
exit "$fail"
