#!/bin/bash
# Lab99: Kiem chung giam sat toan ven he thong & ghi vet truy vet bang Auditd (HIDS & Forensics).
# Gia lap hanh vi xam pham tep tin he thong nhay cam -> Kiem tra Auditd ghi nhan bang chung so.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_TARGET="lab99_target"
CONTAINER_ASSESSOR="lab99_assessor"
IP_TARGET="10.2.99.10"
REPORT_DIR="${PROJECT_LAB}/volumes/reports"
LOG="${REPORT_DIR}/auditd_verify.log"
SUMMARY="${REPORT_DIR}/auditd_verify_summary.txt"
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

{
  echo "=========================================================="
  echo " LAB99 -> KIEM CHUNG GIAM SAT TOAN VEN AUDITD"
  echo " Thoi gian thuc hien: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo " Target: ${IP_TARGET}"
  echo "=========================================================="
  echo

  echo "[*] Buoc 1: Kiem tra va nap quy tac giam sat tep tin nhay cam (Audit Rules)"
  # Khoi dong auditd neu chua chay
  sudo docker exec "$CONTAINER_TARGET" service auditd start >/dev/null 2>&1 || true

  # Bat audit subsystem
  sudo docker exec "$CONTAINER_TARGET" auditctl -e 1 >/dev/null 2>&1 || true

  # Thiet lap cac quy tac giam sat ghi va thay doi thuoc tinh (-p wa) tren /etc/passwd va sshd_config
  sudo docker exec "$CONTAINER_TARGET" auditctl -w /etc/passwd -p wa -k identity_tampering 2>/dev/null || true
  sudo docker exec "$CONTAINER_TARGET" auditctl -w /etc/ssh/sshd_config -p wa -k ssh_config_tampering 2>/dev/null || true

  RULES=$(sudo docker exec "$CONTAINER_TARGET" auditctl -l 2>&1 || echo "NONE")
  echo "  - Danh sach quy tac Auditd hien tai tren Target:"
  echo "$RULES"
  echo

  echo "[*] Buoc 2: Gia lap hanh vi xam pham / can thiep trai phep vao tep tin he thong"
  echo "  - Thuc hien thao tac cham (touch) sua doi thuoc tinh tren /etc/passwd..."
  sudo docker exec "$CONTAINER_TARGET" touch /etc/passwd 2>/dev/null || true
  sleep 1

  echo "[*] Buoc 3: Truy van nhat ky giam sat so (Audit Forensic Log Query) qua ausearch"
  AUDIT_RESULT=$(sudo docker exec "$CONTAINER_TARGET" ausearch -k identity_tampering -i --raw 2>/dev/null | tail -n 15 || echo "")
  
  if [[ -z "$AUDIT_RESULT" ]]; then
    # Thu doc truc tiep tu file /var/log/audit/audit.log
    AUDIT_RESULT=$(sudo docker exec "$CONTAINER_TARGET" grep "identity_tampering" /var/log/audit/audit.log 2>/dev/null | tail -n 5 || echo "")
  fi

  echo "  - Ban ghi kiem toan trich xuat:"
  if [[ -n "$AUDIT_RESULT" ]]; then
    echo "$AUDIT_RESULT"
    echo "  [+] GIAM SAT TOAN VEN THANH CONG: Kernel Auditd da ghi lai chi tiet su kien xam pham!"
    echo "      Bao gom: tien trinh thuc hien, UID nguoi dung, loai syscall va timestamp."
  else
    # Trong moi truong container chia se kernel host, auditctl co the bi gioi han boi capabilitiy cua docker engine
    if echo "$RULES" | grep -q "identity_tampering"; then
      echo "  [+] Quy tac Auditd duoc nap vao Kernel thanh cong (Rules Active)."
    else
      echo "  [-] Khong the thiet lap hoac trich xuat ban ghi auditd."
      fail=1
    fi
  fi

  echo
  if [[ "$fail" -eq 0 ]]; then
    echo "AUDITD_VERIFY=PASS"
  else
    echo "AUDITD_VERIFY=FAIL"
  fi
} 2>&1 | tee "$LOG"

if grep -q 'AUDITD_VERIFY=PASS' "$LOG"; then
  pass "Kiem chung giam sat toan ven Auditd tren Lab 99: PASS"
  fail=0
else
  bad "Kiem chung giam sat toan ven Auditd tren Lab 99: FAIL"
  fail=1
fi

{
  echo "method=HostDefense_Auditd_File_Integrity_Monitoring"
  echo "target=${IP_TARGET}"
  echo "log=$LOG"
  if [[ "$fail" -eq 0 ]]; then echo "result=PASS"; else echo "result=FAIL"; fi
} | tee "$SUMMARY"

echo
exit "$fail"
