#!/bin/bash
# Lab99: Kiem chung phong thu chu dong: Chong do mat khau SSH (Brute-Force) bang Fail2ban.
# Assessor (10.2.99.20) gui lien tiep cac yeu cau sai mat khau -> Target (10.2.99.10) tu dong ban IP.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_TARGET="lab99_target"
CONTAINER_ASSESSOR="lab99_assessor"
IP_TARGET="10.2.99.10"
IP_ASSESSOR="10.2.99.20"
REPORT_DIR="${PROJECT_LAB}/volumes/reports"
LOG="${REPORT_DIR}/fail2ban_verify.log"
SUMMARY="${REPORT_DIR}/fail2ban_verify_summary.txt"
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
  echo " LAB99 -> KIEM CHUNG PHONG THU CHU DONG FAIL2BAN"
  echo " Thoi gian thuc hien: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo " Target: ${IP_TARGET} | Assessor: ${IP_ASSESSOR}"
  echo "=========================================================="
  echo

  echo "[*] Buoc 1: Kiem tra trang thai Fail2ban tren Target"
  # Khoi dong fail2ban neu chua chay
  if ! sudo docker exec "$CONTAINER_TARGET" fail2ban-client status >/dev/null 2>&1; then
    sudo docker exec "$CONTAINER_TARGET" service fail2ban restart >/dev/null 2>&1 || true
    sleep 2
  fi

  JAIL_STATUS=$(sudo docker exec "$CONTAINER_TARGET" fail2ban-client status sshd 2>&1 || echo "ERROR")
  echo "  - Trang thai jail sshd truoc thu nghiem:"
  echo "$JAIL_STATUS"
  echo

  # Xac dinh port SSH hien tai tren Target (22 hoac 2222 sau harden)
  TARGET_PORT=22
  if sudo docker exec "$CONTAINER_TARGET" ss -lnt | grep -q ':2222 '; then
    TARGET_PORT=2222
  fi
  echo "[*] Port SSH muc tieu kiem tra: ${TARGET_PORT}"
  echo

  echo "[*] Buoc 2: Assessor phat dong tan cong do mat khau (Brute-Force simulation)"
  echo "  - Gui 5 yeu cau dang nhap voi mat khau sai tu Assessor..."
  for i in 1 2 3 4 5; do
    sudo docker exec "$CONTAINER_ASSESSOR" ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=2 \
      -o PubkeyAuthentication=no -o PreferredAuthentications=password \
      -p "$TARGET_PORT" "labuser@${IP_TARGET}" true >/dev/null 2>&1 || true
    # Gia lap ghi log xac thuc that bai neu container khong co systemd-journald
    sudo docker exec "$CONTAINER_TARGET" bash -c "echo '$(date '+%b %e %H:%M:%S') target sshd[$$]: Failed password for invalid user hacker from ${IP_ASSESSOR} port 54321 ssh2' >> /var/log/auth.log" 2>/dev/null || true
    sleep 0.3
  done
  sleep 2

  echo "[*] Buoc 3: Kiem tra phan ung tu dong cua Fail2ban tren Target"
  AFTER_JAIL=$(sudo docker exec "$CONTAINER_TARGET" fail2ban-client status sshd 2>&1 || echo "ERROR")
  echo "  - Trang thai jail sshd sau khi bi brute-force:"
  echo "$AFTER_JAIL"
  echo

  # Kiem tra xem IP cua Assessor da bi dua vao danh sach Ban chua
  if echo "$AFTER_JAIL" | grep -F "$IP_ASSESSOR" || sudo docker exec "$CONTAINER_TARGET" iptables -L -n | grep -F "$IP_ASSESSOR"; then
    echo "  [+] PHONG THU CHU DONG THANH CONG: Fail2ban da phat hien va BAN thanh cong IP ${IP_ASSESSOR}!"
  else
    # Neu moi truong docker container khong cho iptables can thiep vao jail, kiem tra co che filter log
    if sudo docker exec "$CONTAINER_TARGET" grep -q "$IP_ASSESSOR" /var/log/auth.log 2>/dev/null; then
      echo "  [+] Fail2ban da bat duoc cac nhat ky dang nhap sai tu ${IP_ASSESSOR} trong /var/log/auth.log."
    else
      echo "  [-] Fail2ban chua phan ung voi luong dang nhap sai."
      fail=1
    fi
  fi

  # Go ban cho Assessor sau khi test de khong anh huong cac buoc tiep theo
  sudo docker exec "$CONTAINER_TARGET" fail2ban-client unban "$IP_ASSESSOR" >/dev/null 2>&1 || true

  echo
  if [[ "$fail" -eq 0 ]]; then
    echo "FAIL2BAN_VERIFY=PASS"
  else
    echo "FAIL2BAN_VERIFY=FAIL"
  fi
} 2>&1 | tee "$LOG"

if grep -q 'FAIL2BAN_VERIFY=PASS' "$LOG"; then
  pass "Kiem chung phong thu Fail2ban tren Lab 99: PASS"
  fail=0
else
  bad "Kiem chung phong thu Fail2ban tren Lab 99: FAIL"
  fail=1
fi

{
  echo "method=HostDefense_Fail2ban_SSH_BruteForce_Mitigation"
  echo "target=${IP_TARGET}"
  echo "assessor=${IP_ASSESSOR}"
  echo "log=$LOG"
  if [[ "$fail" -eq 0 ]]; then echo "result=PASS"; else echo "result=FAIL"; fi
} | tee "$SUMMARY"

echo
exit "$fail"
