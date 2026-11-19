#!/bin/bash
# Lab99: ap dung dung chuoi thu nghiem Lab 03 (Kaminsky poison -> SPR defense).
# Tai su dung script da co trong lab03/.lab — khong viet tan cong moi.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
LAB03_DIR="/media/sf_.shared/scripts/lab03/.lab"
REPORT_DIR="${PROJECT_LAB}/volumes/reports"
LOG="${REPORT_DIR}/lab03_verify.log"
SUMMARY="${REPORT_DIR}/lab03_verify_summary.txt"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

mkdir -p "$REPORT_DIR"

if [[ ! -d "$LAB03_DIR" ]]; then
  echo "Khong thay Lab 03: $LAB03_DIR"
  exit 1
fi

note "Giai phong subnet 10.2.6.0/24 (tat Lab99/Lab02 neu dang chay)"
bash "${PROJECT_LAB}/.lab/99_down.sh" >/dev/null 2>&1 || true
bash /media/sf_.shared/scripts/lab02/.lab/99_down.sh >/dev/null 2>&1 || true

{
  echo "LAB99 -> LAB03 VERIFY  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Su dung script san co: 00_init .. 04_test_defense"
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

  run_step "00_init" "${LAB03_DIR}/00_init.sh" || fail=1
  run_step "01_gen_query" "${LAB03_DIR}/01_gen_query.sh" || fail=1
  run_step "02_gen_response" "${LAB03_DIR}/02_gen_response.sh" || fail=1
  run_step "03_test_attack" "${LAB03_DIR}/03_test_attack.sh" || fail=1
  run_step "04_test_defense" "${LAB03_DIR}/04_test_defense.sh" || fail=1

  echo
  if [[ "$fail" -eq 0 ]]; then
    echo "LAB03_VERIFY=PASS"
  else
    echo "LAB03_VERIFY=FAIL"
  fi
} 2>&1 | tee "$LOG"

if grep -q 'LAB03_VERIFY=PASS' "$LOG"; then
  pass "Lab 03 chuoi thu nghiem PASS"
  fail=0
else
  bad "Lab 03 chuoi thu nghiem FAIL — xem $LOG"
  fail=1
fi

{
  echo "method=Lab03_Kaminsky_SPR"
  echo "scripts=00_init,01_gen_query,02_gen_response,03_test_attack,04_test_defense"
  echo "log=$LOG"
  if [[ "$fail" -eq 0 ]]; then echo "result=PASS"; else echo "result=FAIL"; fi
} | tee "$SUMMARY"

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA LAB99 APPLY LAB03: PASS"
else
  echo "KET QUA LAB99 APPLY LAB03: FAIL"
fi
exit "$fail"
