#!/bin/bash
# Lab99: ap dung dung chuoi thu nghiem Lab 02 (ARP poison -> MITM -> ARP tinh).
# Tai su dung script da co trong lab02/.lab — khong viet tan cong moi.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
LAB02_DIR="/media/sf_.shared/scripts/lab02/.lab"
REPORT_DIR="${PROJECT_LAB}/volumes/reports"
LOG="${REPORT_DIR}/lab02_verify.log"
SUMMARY="${REPORT_DIR}/lab02_verify_summary.txt"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

mkdir -p "$REPORT_DIR"

if [[ ! -d "$LAB02_DIR" ]]; then
  echo "Khong thay Lab 02: $LAB02_DIR"
  exit 1
fi

note "Giai phong subnet 10.2.6.0/24 (tat Lab99/Lab03 neu dang chay)"
bash "${PROJECT_LAB}/.lab/99_down.sh" >/dev/null 2>&1 || true
bash /media/sf_.shared/scripts/lab03/.lab/99_down.sh >/dev/null 2>&1 || true

{
  echo "LAB99 -> LAB02 VERIFY  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Su dung script san co: 00_init .. 04_fix_server"
  echo

  run_step() {
    local name="$1"
    local script="$2"
    echo
    echo "######## ${name} ########"
    if bash "$script"; then
      echo "STEP_OK ${name}"
      return 0
    fi
    echo "STEP_FAIL ${name}"
    return 1
  }

  run_step "00_init" "${LAB02_DIR}/00_init.sh" || fail=1
  run_step "01_scenario1" "${LAB02_DIR}/01_scenario1.sh" || fail=1
  run_step "02_scenario2" "${LAB02_DIR}/02_scenario2.sh" || fail=1
  run_step "03_scenario3" "${LAB02_DIR}/03_scenario3.sh" || fail=1
  run_step "04_fix_server" "${LAB02_DIR}/04_fix_server.sh" || fail=1

  echo
  if [[ "$fail" -eq 0 ]]; then
    echo "LAB02_VERIFY=PASS"
  else
    echo "LAB02_VERIFY=FAIL"
  fi
} 2>&1 | tee "$LOG"

if grep -q 'LAB02_VERIFY=PASS' "$LOG"; then
  pass "Lab 02 chuoi thu nghiem PASS"
  fail=0
else
  bad "Lab 02 chuoi thu nghiem FAIL — xem $LOG"
  fail=1
fi

{
  echo "method=Lab02_ARP_MITM_StaticARP"
  echo "scripts=00_init,01_scenario1,02_scenario2,03_scenario3,04_fix_server"
  echo "log=$LOG"
  if [[ "$fail" -eq 0 ]]; then echo "result=PASS"; else echo "result=FAIL"; fi
} | tee "$SUMMARY"

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA LAB99 APPLY LAB02: PASS"
else
  echo "KET QUA LAB99 APPLY LAB02: FAIL"
fi
exit "$fail"
