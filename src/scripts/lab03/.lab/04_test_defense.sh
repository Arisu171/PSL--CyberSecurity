#!/bin/bash
# Muc 4.5: Bo query-source port 44444 (Source Port Randomization) va chung minh tan cong that bai.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
ATTACK_DIR="${PROJECT_LAB}/attack"
VOLUMES_DIR="${PROJECT_LAB}/volumes"
ZIP_NAME="Nhom6_Lab03_BaoCao.zip"
ZIP_HOST="${VOLUMES_DIR}/${ZIP_NAME}"
PCAP_ATTACKER_HOST="${VOLUMES_DIR}/attacker.pcap"
PCAP_DNS_HOST="${VOLUMES_DIR}/local_dns_server.pcap"

CONTAINER_USER="user-10.2.6.5"
CONTAINER_ATTACKER="attacker-10.2.6.1"
CONTAINER_DNS="local-dns-server-10.2.6.53"
CONTAINERS=("$CONTAINER_USER" "$CONTAINER_ATTACKER" "$CONTAINER_DNS")
ATTACK_WORKDIR="/tmp/lab03_attack_run"
ATTACK_BIN_NAME="attack"
NAMED_OPTIONS="/etc/bind/named.conf.options"
FIXED_PORT_LINE="query-source port 44444;"

DOMAIN_EXAMPLE_WWW="www.example.com"
POISON_IP="1.2.3.5"
ATTACK_SECONDS="8"
DIG_TIME="5"
DIG_TRIES="2"
NAME_FORMAT='{{.Names}}'

names=""
dig_clean=""
dig_after_attack=""
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

names="$(sudo docker ps --format "$NAME_FORMAT")"
for container in "${CONTAINERS[@]}"; do
  if ! grep -qx "$container" <<<"$names"; then
    echo "Thieu $container. Chay 00_init.sh truoc."
    exit 1
  fi
done

mkdir -p "$VOLUMES_DIR"

note "Xoa cau hinh cong co dinh 44444"
sudo docker exec "$CONTAINER_DNS" sed -i "/${FIXED_PORT_LINE}/d" "$NAMED_OPTIONS"
sudo docker exec "$CONTAINER_DNS" named-checkconf
sudo docker exec "$CONTAINER_DNS" rndc reconfig
if sudo docker exec "$CONTAINER_DNS" grep -q "$FIXED_PORT_LINE" "$NAMED_OPTIONS"; then
  bad "Van con ${FIXED_PORT_LINE}"
else
  pass "Da tat query-source port co dinh"
fi

note "Flush cache va dig (ky vong IP that)"
sudo docker exec "$CONTAINER_DNS" rndc flush
dig_clean="$(sudo docker exec "$CONTAINER_USER" dig +time="$DIG_TIME" +tries="$DIG_TRIES" "$DOMAIN_EXAMPLE_WWW" || true)"
echo "$dig_clean"
if grep -q "ANSWER SECTION" <<<"$dig_clean" && ! grep -q "$POISON_IP" <<<"$dig_clean"; then
  pass "${DOMAIN_EXAMPLE_WWW} tro lai IP that"
else
  bad "Dig sau phong thu chua dung"
fi

note "Thu tan cong lai ${ATTACK_SECONDS}s (ky vong that bai)"
if sudo docker exec "$CONTAINER_ATTACKER" test -x "${ATTACK_WORKDIR}/${ATTACK_BIN_NAME}"; then
  sudo docker exec "$CONTAINER_ATTACKER" bash -c "cd ${ATTACK_WORKDIR} && timeout ${ATTACK_SECONDS} ./${ATTACK_BIN_NAME} || true"
else
  echo "Chua co binary attack trong container; bo qua buoc tan cong lai."
fi
dig_after_attack="$(sudo docker exec "$CONTAINER_USER" dig +time="$DIG_TIME" +tries="$DIG_TRIES" "$DOMAIN_EXAMPLE_WWW" || true)"
echo "$dig_after_attack"
if grep -q "ANSWER SECTION" <<<"$dig_after_attack" && ! grep -q "$POISON_IP" <<<"$dig_after_attack"; then
  pass "Sau khi bat SPR, tan cong khong dau doc duoc cache"
else
  bad "Van thay IP doc hai sau phong thu"
fi

note "Dong goi pcap (neu co) theo dinh dang nop bai"
if [[ -f "$PCAP_ATTACKER_HOST" && -f "$PCAP_DNS_HOST" ]]; then
  rm -f "$ZIP_HOST"
  (
    cd "$VOLUMES_DIR"
    zip -q "$ZIP_NAME" attacker.pcap local_dns_server.pcap
  )
  ls -lh "$ZIP_HOST"
  pass "Da tao ${ZIP_HOST}"
else
  echo "Thieu pcap, bo qua buoc zip. Can chay 03_attack.sh truoc neu can nop file."
fi

echo
echo "De khoi phuc cong 44444, chay lai 00_init.sh (recreate Local DNS tu image du an)."
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA PHONG THU: PASS"
else
  echo "KET QUA PHONG THU: FAIL"
fi
exit "$fail"
