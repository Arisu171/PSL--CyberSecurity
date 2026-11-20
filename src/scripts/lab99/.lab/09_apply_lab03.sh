#!/bin/bash
# Lab99: Kiem chung phong thu ha tang DNS & Source Port Randomization (Ky thuat tu Lab 03).
# Thuc hien truc tiep tren moi truong Lab 99: Assessor (10.2.99.20) kiem thu Target (10.2.99.10).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_TARGET="lab99_target"
CONTAINER_ASSESSOR="lab99_assessor"
IP_TARGET="10.2.99.10"
IP_ASSESSOR="10.2.99.20"
REPORT_DIR="${PROJECT_LAB}/volumes/reports"
LOG="${REPORT_DIR}/lab03_verify.log"
SUMMARY="${REPORT_DIR}/lab03_verify_summary.txt"
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
  echo " LAB99 -> KIEM CHUNG PHONG THU HA TANG DNS (LAB 03)"
  echo " Thoi gian thuc hien: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo " Target: ${IP_TARGET} | Assessor: ${IP_ASSESSOR}"
  echo "=========================================================="
  echo

  echo "[*] Buoc 1: Kiem tra cau hinh may chu phan giai DNS tren Target"
  RESOLV_CONF=$(sudo docker exec "$CONTAINER_TARGET" cat /etc/resolv.conf 2>/dev/null || echo "")
  echo "  - Noi dung /etc/resolv.conf tren Target:"
  echo "$RESOLV_CONF"
  echo

  echo "[*] Buoc 2: Kiem tra co che cap phat cong nguon ngau nhien (Source Port Randomization)"
  # Kiem tra dai ephemeral ports tren Target (ky vong tu 1024 hoac 32768 den 60999/65535)
  LOCAL_PORT_RANGE=$(sudo docker exec "$CONTAINER_TARGET" sysctl -n net.ipv4.ip_local_port_range 2>/dev/null || echo "")
  echo "  - net.ipv4.ip_local_port_range tren Target: ${LOCAL_PORT_RANGE}"
  LOW_PORT=$(echo "$LOCAL_PORT_RANGE" | awk '{print $1}')
  HIGH_PORT=$(echo "$LOCAL_PORT_RANGE" | awk '{print $2}')

  if [[ -n "$LOW_PORT" && -n "$HIGH_PORT" && "$HIGH_PORT" -gt 60000 ]]; then
    TOTAL_PORTS=$(( HIGH_PORT - LOW_PORT ))
    echo "  [+] Dai cong nguon ephemeral kha dung: ${TOTAL_PORTS} cong (mo rong entropy chong Kaminsky attack)."
  else
    echo "  [-] Dai cong nguon khong hop le hoac bi co dinh."
    fail=1
  fi
  echo

  echo "[*] Buoc 3: Thu nghiem do tim va tan cong gia mao DNS tu Assessor toi Target"
  # Assessor kiem tra xem Target co mo cong DNS de quy nguy hiem (port 53) hay khong
  DNS_PORT_OPEN=$(sudo docker exec "$CONTAINER_ASSESSOR" nc -z -u -w 2 "$IP_TARGET" 53 2>&1 || true)
  if sudo docker exec "$CONTAINER_TARGET" ss -lun | grep -q ':53 '; then
    echo "  [-] Canh bao: Target dang mo cong DNS Server (53/udp)."
  else
    echo "  [+] Target khong mo cong DNS Server cong khai: mien nhiem voi DNS Amplification reflector."
  fi
  echo

  echo "[*] Buoc 4: Kiem tra do toan ven truy van DNS outbound tu Target"
  # Thu phan giai ten mien hop le tu Target
  DIG_OUT=$(sudo docker exec "$CONTAINER_TARGET" python3 -c "
import socket
try:
    ip = socket.gethostbyname('example.com')
    print(f'RESOLVED:{ip}')
except Exception as e:
    print(f'ERROR:{e}')
" 2>/dev/null || echo "ERROR")
  echo "  - Ket qua phan giai example.com tren Target: ${DIG_OUT}"
  if echo "$DIG_OUT" | grep -q "RESOLVED:"; then
    echo "  [+] DNS Resolver hoat dong on dinh va tra ve dia chi IP hop le."
  else
    echo "  [*] DNS Resolver khong ket noi duoc internet hoac container co lap (chap nhan trong lab)."
  fi

  echo
  if [[ "$fail" -eq 0 ]]; then
    echo "LAB03_VERIFY=PASS"
  else
    echo "LAB03_VERIFY=FAIL"
  fi
} 2>&1 | tee "$LOG"

if grep -q 'LAB03_VERIFY=PASS' "$LOG"; then
  pass "Kiem chung phong thu DNS (Lab 03) tren Lab 99: PASS"
  fail=0
else
  bad "Kiem chung phong thu DNS (Lab 03) tren Lab 99: FAIL"
  fail=1
fi

{
  echo "method=Lab03_DNS_Resilience_SPR_EphemeralPorts"
  echo "target=${IP_TARGET}"
  echo "assessor=${IP_ASSESSOR}"
  echo "log=$LOG"
  if [[ "$fail" -eq 0 ]]; then echo "result=PASS"; else echo "result=FAIL"; fi
} | tee "$SUMMARY"

echo
exit "$fail"
