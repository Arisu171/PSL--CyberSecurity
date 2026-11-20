#!/bin/bash
# Lab99: Kiem chung phong thu DoS TCP SYN Flood & ICMP Flood.
# Thuc hien truc tiep tren moi truong Lab 99: Assessor (10.2.99.20) tan cong kiem thu Target (10.2.99.10).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_TARGET="lab99_target"
CONTAINER_ASSESSOR="lab99_assessor"
IP_TARGET="10.2.99.10"
IP_ASSESSOR="10.2.99.20"
REPORT_DIR="${PROJECT_LAB}/volumes/reports"
LOG="${REPORT_DIR}/lab04_verify.log"
SUMMARY="${REPORT_DIR}/lab04_verify_summary.txt"
fail=0
TARGET_PORT=22

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
  echo " LAB99 -> KIEM CHUNG PHONG THU DoS SYN/ICMP FLOOD"
  echo " Thoi gian thuc hien: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo " Target: ${IP_TARGET} | Assessor: ${IP_ASSESSOR}"
  echo "=========================================================="
  echo

  echo "[*] Buoc 1: Kiem tra cau hinh phong thu kernel tren Target"
  SYN_COOKIES=$(sudo docker exec "$CONTAINER_TARGET" sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo "0")
  ICMP_BROADCAST=$(sudo docker exec "$CONTAINER_TARGET" sysctl -n net.ipv4.icmp_echo_ignore_broadcasts 2>/dev/null || echo "0")
  SYN_BACKLOG=$(sudo docker exec "$CONTAINER_TARGET" sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null || echo "0")

  echo "  - net.ipv4.tcp_syncookies:              ${SYN_COOKIES}"
  echo "  - net.ipv4.icmp_echo_ignore_broadcasts: ${ICMP_BROADCAST}"
  echo "  - net.ipv4.tcp_max_syn_backlog:         ${SYN_BACKLOG}"

  if [[ "$SYN_COOKIES" -eq 1 ]]; then
    echo "  [+] TCP SYN Cookies da duoc KICH HOAT: bao ve hang doi ket noi truoc SYN Flood."
  else
    echo "  [-] TCP SYN Cookies chua bat."
    fail=1
  fi
  echo

  # Xac dinh cong SSH dang mo tren Target (22 hoac 2222 sau harden)
  TARGET_PORT=22
  if sudo docker exec "$CONTAINER_TARGET" ss -lnt | grep -q ':2222 '; then
    TARGET_PORT=2222
  fi
  echo "[*] Cong muc tieu kiem tra tren Target: TCP/${TARGET_PORT}"
  echo

  echo "[*] Buoc 2: Do luong ket noi baseline truoc khi tan cong"
  if sudo docker exec "$CONTAINER_ASSESSOR" nc -z -w 2 "$IP_TARGET" "$TARGET_PORT"; then
    echo "  [+] Ket noi baseline toi ${IP_TARGET}:${TARGET_PORT} thanh cong."
  else
    echo "  [-] Khong the ket noi toi ${IP_TARGET}:${TARGET_PORT}."
    fail=1
  fi
  echo

  echo "[*] Buoc 3: Assessor phat dong tan cong TCP SYN Flood (hping3) voi toc do cao"
  echo "  - Luong tan cong: hping3 -S -p ${TARGET_PORT} --flood --rand-source (chay 4 giay)"
  sudo docker exec -d "$CONTAINER_ASSESSOR" hping3 -S -p "$TARGET_PORT" --flood --rand-source "$IP_TARGET" >/dev/null 2>&1 || true
  sleep 2

  echo "[*] Buoc 4: Kiem tra kha nang song sot va dap ung dich vu cua Target TRONG KHI bi flood"
  # Thu ket noi hop le tu Assessor den Target trong khi cuoc tan cong dang dien ra
  SURVIVED=0
  for i in 1 2 3; do
    if sudo docker exec "$CONTAINER_ASSESSOR" nc -z -w 2 "$IP_TARGET" "$TARGET_PORT"; then
      SURVIVED=$(( SURVIVED + 1 ))
    fi
    sleep 0.5
  done

  # Dung tien trinh hping3
  sudo docker exec "$CONTAINER_ASSESSOR" pkill -9 hping3 >/dev/null 2>&1 || true
  echo "  - Ket qua thu nghiem truy cap: ${SURVIVED}/3 lan ket noi thanh cong trong con bao SYN Flood."

  if [[ "$SURVIVED" -ge 2 ]]; then
    echo "  [+] Dich vu tren Target duy tri on dinh nho TCP SYN Cookies & Rate Limiting!"
  else
    echo "  [-] Target bi suy giam dap ung hoac tran hang doi ket noi."
    fail=1
  fi
  echo

  echo "[*] Buoc 5: Thu nghiem tan cong ICMP Ping Flood"
  sudo docker exec -d "$CONTAINER_ASSESSOR" hping3 --icmp --flood "$IP_TARGET" >/dev/null 2>&1 || true
  sleep 2
  sudo docker exec "$CONTAINER_ASSESSOR" pkill -9 hping3 >/dev/null 2>&1 || true
  # Kiem tra ping binh thuong
  if sudo docker exec "$CONTAINER_ASSESSOR" ping -c 2 -W 1 "$IP_TARGET" >/dev/null 2>&1; then
    echo "  [+] Target van phan hoi ICMP hop le sau luot flood."
  else
    echo "  [-] Target khong phan hoi ping sau flood."
    fail=1
  fi

  echo
  if [[ "$fail" -eq 0 ]]; then
    echo "LAB04_VERIFY=PASS"
  else
    echo "LAB04_VERIFY=FAIL"
  fi
} 2>&1 | tee "$LOG"

if grep -q 'LAB04_VERIFY=PASS' "$LOG"; then
  pass "Kiem chung phong thu DoS tren Lab 99: PASS"
  fail=0
else
  bad "Kiem chung phong thu DoS tren Lab 99: FAIL"
  fail=1
fi

{
  echo "method=Lab04_DoS_SYNCookies_RateLimit"
  echo "target=${IP_TARGET}"
  echo "assessor=${IP_ASSESSOR}"
  echo "target_port=${TARGET_PORT}"
  echo "log=$LOG"
  if [[ "$fail" -eq 0 ]]; then echo "result=PASS"; else echo "result=FAIL"; fi
} | tee "$SUMMARY"

echo
exit "$fail"
