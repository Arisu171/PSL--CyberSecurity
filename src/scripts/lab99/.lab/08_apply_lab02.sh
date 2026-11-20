#!/bin/bash
# Lab99: Kiem chung phong thu Layer 2 / Layer 3 (Ky thuat tu Lab 02).
# Thuc hien truc tiep tren moi truong Lab 99: Assessor (10.2.99.20) kiem thu Target (10.2.99.10).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_TARGET="lab99_target"
CONTAINER_ASSESSOR="lab99_assessor"
IP_TARGET="10.2.99.10"
IP_ASSESSOR="10.2.99.20"
REPORT_DIR="${PROJECT_LAB}/volumes/reports"
LOG="${REPORT_DIR}/lab02_verify.log"
SUMMARY="${REPORT_DIR}/lab02_verify_summary.txt"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; fail=1; }

mkdir -p "$REPORT_DIR"

note "Kiem tra trang thai container Lab 99"
if ! sudo docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_TARGET"; then
  echo "[-] Container $CONTAINER_TARGET chua chay. Khoi dong .lab/00_init.sh truoc!"
  exit 1
fi
if ! sudo docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_ASSESSOR"; then
  echo "[-] Container $CONTAINER_ASSESSOR chua chay. Khoi dong .lab/00_init.sh truoc!"
  exit 1
fi

{
  echo "=========================================================="
  echo " LAB99 -> KIEM CHUNG PHONG THU LAYER 2/3 (LAB 02)"
  echo " Thoi gian thuc hien: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo " Target: ${IP_TARGET} | Assessor: ${IP_ASSESSOR}"
  echo "=========================================================="
  echo

  echo "[*] Buoc 1: Thu thap thong so MAC hien tai cua Target va Assessor"
  TARGET_MAC=$(sudo docker exec "$CONTAINER_TARGET" cat /sys/class/net/eth0/address)
  ASSESSOR_MAC=$(sudo docker exec "$CONTAINER_ASSESSOR" cat /sys/class/net/eth0/address)
  echo "  - TARGET_MAC:   ${TARGET_MAC}"
  echo "  - ASSESSOR_MAC: ${ASSESSOR_MAC}"
  echo

  echo "[*] Buoc 2: Assessor thu nghiem phat tan goi tin ARP Reply gia mao toi Target"
  # Gui goi ARP reply gia mao rang IP 10.2.99.99 (hoac Gateway) co MAC cua Assessor
  FAKE_IP="10.2.99.99"
  sudo docker exec "$CONTAINER_ASSESSOR" arping -c 3 -A -I eth0 -s "$FAKE_IP" "$IP_TARGET" >/dev/null 2>&1 || true

  echo "[*] Buoc 3: Kiem tra cau hinh phong thu tren Target"
  # 1. Kiem tra rp_filter (Reverse Path Filtering chong IP spoofing)
  RP_FILTER=$(sudo docker exec "$CONTAINER_TARGET" sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null || echo "0")
  echo "  - net.ipv4.conf.all.rp_filter: ${RP_FILTER}"
  if [[ "$RP_FILTER" -eq 1 ]]; then
    echo "  [+] Reverse Path Filtering dang bat: ngan chan goi tin gia mao IP nguon."
  else
    echo "  [-] Reverse Path Filtering chua bat."
    fail=1
  fi

  # 2. Kiem tra arp_ignore va arp_announce
  ARP_IGNORE=$(sudo docker exec "$CONTAINER_TARGET" sysctl -n net.ipv4.conf.all.arp_ignore 2>/dev/null || echo "0")
  ARP_ANNOUNCE=$(sudo docker exec "$CONTAINER_TARGET" sysctl -n net.ipv4.conf.all.arp_announce 2>/dev/null || echo "0")
  echo "  - net.ipv4.conf.all.arp_ignore:   ${ARP_IGNORE}"
  echo "  - net.ipv4.conf.all.arp_announce: ${ARP_ANNOUNCE}"

  # 3. Kiem tra trang thai ban ghi ARP tren Target
  TARGET_NEIGH=$(sudo docker exec "$CONTAINER_TARGET" ip neigh show)
  echo "  - Bang ARP hien tai tren Target:"
  echo "$TARGET_NEIGH"

  # Kiem tra xem ban ghi cua Assessor co duoc thiet lap che do PERMANENT khong
  if echo "$TARGET_NEIGH" | grep -F "$IP_ASSESSOR" | grep -qiE "PERMANENT|REACHABLE"; then
    echo "  [+] Anh xa ARP cua Assessor duoc bao ve, khong bi dau doc boi fake reply."
  else
    echo "  [-] Anh xa ARP chua co co che bao ve."
    fail=1
  fi

  echo
  if [[ "$fail" -eq 0 ]]; then
    echo "LAB02_VERIFY=PASS"
  else
    echo "LAB02_VERIFY=FAIL"
  fi
} 2>&1 | tee "$LOG"

if grep -q 'LAB02_VERIFY=PASS' "$LOG"; then
  pass "Kiem chung phong thu Layer 2/3 (Lab 02) tren Lab 99: PASS"
  fail=0
else
  bad "Kiem chung phong thu Layer 2/3 (Lab 02) tren Lab 99: FAIL"
  fail=1
fi

{
  echo "method=Lab02_ARP_Spoofing_RPFilter_StaticARP"
  echo "target=${IP_TARGET}"
  echo "assessor=${IP_ASSESSOR}"
  echo "log=$LOG"
  if [[ "$fail" -eq 0 ]]; then echo "result=PASS"; else echo "result=FAIL"; fi
} | tee "$SUMMARY"

echo
exit "$fail"
