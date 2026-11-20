#!/bin/bash
# Khoi tao Lab 03: dung 4 container DNS tu thu muc du an, kiem tra ket noi va dig ban dau.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_LAB}/docker-compose.yml"
NAMED_OPTIONS_HOST="${PROJECT_LAB}/image_local_dns_server/named.conf.options"

CONTAINER_USER="user-10.2.6.5"
CONTAINER_ATTACKER="attacker-10.2.6.1"
CONTAINER_DNS="local-dns-server-10.2.6.53"
CONTAINER_ATTACKER_NS="attacker-ns-10.2.6.153"
CONTAINERS=("$CONTAINER_USER" "$CONTAINER_ATTACKER" "$CONTAINER_DNS" "$CONTAINER_ATTACKER_NS")

IP_USER="10.2.6.5"
IP_ATTACKER="10.2.6.1"
IP_DNS="10.2.6.53"
IP_ATTACKER_NS="10.2.6.153"
HOST_BAD_DEFAULT="192.168.117.2"

DOMAIN_ATTACKER_NS="ns.attacker32.com"
DOMAIN_EXAMPLE_WWW="www.example.com"
POISON_IP="1.2.3.5"

PING_COUNT="2"
PING_WAIT="1"
WAIT_BOOT="4"
DIG_TIME="5"
DIG_TRIES="2"
NAME_FORMAT='{{.Names}}'
PS_FORMAT='table {{.Names}}\t{{.Status}}\t{{.Image}}'
LOSS_NONE="0% packet loss"

# Container cua cac lab khac co the dang chiem subnet 10.2.6.0/24
CLEANUP_LAB02=("lab02_user" "lab02_server" "lab02_attacker")
CLEANUP_LAB04=("lab04_victim" "lab04_attacker" "lab04_user" "lab04_dns")
CLEANUP_LAB05=("lab05_webserver" "lab05_attacker" "lab05_user")
CLEANUP_LAB99=("lab99_target" "lab99_assessor")
SUBNET_NETS=("net-10.2.6.0" "seed-net")

names=""
ping_dns=""
ping_ns=""
ping_attacker=""
dig_ns=""
dig_www=""
dig_direct=""
fail=0note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Khong thay compose du an: $COMPOSE_FILE"
  exit 1
fi

note "Go default route Host gay ket DNS (neu co)"
sudo ip route del default via "$HOST_BAD_DEFAULT" 2>/dev/null || true

note "Tat cac lab khac neu dang chiem subnet 10.2.6.0/24"
# Xoa truc tiep theo ten container — khong phu thuoc file compose cua lab khac
sudo docker rm -f \
  "${CLEANUP_LAB02[@]}" \
  "${CLEANUP_LAB04[@]}" \
  "${CLEANUP_LAB05[@]}" \
  "${CLEANUP_LAB99[@]}" \
  2>/dev/null || true
for _net in "${SUBNET_NETS[@]}"; do
  sudo docker network rm "$_net" 2>/dev/null || true
done

note "Build Local DNS (neu can) va khoi dong Lab 03 tu du an"
sudo docker compose -f "$COMPOSE_FILE" --project-directory "$PROJECT_LAB" build local-server
sudo docker compose -f "$COMPOSE_FILE" --project-directory "$PROJECT_LAB" up -d --force-recreate
sleep "$WAIT_BOOT"

note "Nap named.conf.options (query-source 44444 + tat cookie)"
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
else
  bad "Thieu $NAMED_OPTIONS_HOST"
fi

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

note "Kiem tra named va cau hinh cong 44444"
sudo docker exec "$CONTAINER_DNS" rndc status | head -8
if sudo docker exec "$CONTAINER_DNS" grep -q "query-source port 44444;" /etc/bind/named.conf.options; then
  pass "Local DNS dang dung query-source port 44444"
else
  bad "Thieu query-source port 44444 (can file $NAMED_OPTIONS_HOST)"
fi

note "Ping tu User"
ping_dns="$(sudo docker exec "$CONTAINER_USER" ping -c "$PING_COUNT" -W "$PING_WAIT" "$IP_DNS" || true)"
ping_ns="$(sudo docker exec "$CONTAINER_USER" ping -c "$PING_COUNT" -W "$PING_WAIT" "$IP_ATTACKER_NS" || true)"
ping_attacker="$(sudo docker exec "$CONTAINER_USER" ping -c "$PING_COUNT" -W "$PING_WAIT" "$IP_ATTACKER" || true)"
echo "$ping_dns"
echo "$ping_ns"
echo "$ping_attacker"
grep -F -q "$LOSS_NONE" <<<"$ping_dns" && pass "Ping toi Local DNS" || bad "Ping Local DNS that bai"
grep -F -q "$LOSS_NONE" <<<"$ping_ns" && pass "Ping toi Attacker NS" || bad "Ping Attacker NS that bai"
grep -F -q "$LOSS_NONE" <<<"$ping_attacker" && pass "Ping toi Attacker" || bad "Ping Attacker that bai"

note "Dig ban dau"
dig_ns="$(sudo docker exec "$CONTAINER_USER" dig +time="$DIG_TIME" +tries="$DIG_TRIES" "$DOMAIN_ATTACKER_NS" || true)"
dig_www="$(sudo docker exec "$CONTAINER_USER" dig +time="$DIG_TIME" +tries="$DIG_TRIES" "$DOMAIN_EXAMPLE_WWW" || true)"
dig_direct="$(sudo docker exec "$CONTAINER_USER" dig +time="$DIG_TIME" +tries="$DIG_TRIES" @"$DOMAIN_ATTACKER_NS" "$DOMAIN_EXAMPLE_WWW" || true)"
echo "$dig_ns"
echo "$dig_www"
echo "$dig_direct"

if grep -q "$IP_ATTACKER_NS" <<<"$dig_ns"; then
  pass "${DOMAIN_ATTACKER_NS} -> ${IP_ATTACKER_NS}"
else
  bad "dig ${DOMAIN_ATTACKER_NS} sai"
fi
if grep -q "ANSWER SECTION" <<<"$dig_www" && ! grep -q "$POISON_IP" <<<"$dig_www"; then
  pass "${DOMAIN_EXAMPLE_WWW} tra ve IP that (chua bi dau doc)"
else
  bad "dig ${DOMAIN_EXAMPLE_WWW} ban dau khong hop le"
fi
if grep -q "$POISON_IP" <<<"$dig_direct"; then
  pass "Truy van truc tiep Attacker NS tra ve ${POISON_IP}"
else
  bad "dig @${DOMAIN_ATTACKER_NS} khong tra ${POISON_IP}"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA KHOI TAO: PASS"
else
  echo "KET QUA KHOI TAO: FAIL"
fi
exit "$fail"
