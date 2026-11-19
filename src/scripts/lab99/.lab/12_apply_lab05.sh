#!/bin/bash
# Lab99: ap dung dung chuoi thu nghiem Lab 05 (SQL Injection SELECT & INSERT -> PDO Prepared Statements defense).
# Tai su dung script da co trong lab05/.lab — khong viet tan cong moi.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
LAB05_DIR="/media/sf_.shared/scripts/lab05/.lab"
REPORT_DIR="${PROJECT_LAB}/volumes/reports"
LOG="${REPORT_DIR}/lab05_verify.log"
SUMMARY="${REPORT_DIR}/lab05_verify_summary.txt"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

mkdir -p "$REPORT_DIR"

if [[ ! -d "$LAB05_DIR" ]]; then
  echo "Khong thay Lab 05: $LAB05_DIR"
  exit 1
fi

note "Giai phong subnet 10.2.6.0/24 (tat cac lab khac neu dang chay)"
bash "${PROJECT_LAB}/.lab/99_down.sh" >/dev/null 2>&1 || true
bash /media/sf_.shared/scripts/lab02/.lab/99_down.sh >/dev/null 2>&1 || true
bash /media/sf_.shared/scripts/lab03/.lab/99_down.sh >/dev/null 2>&1 || true
bash /media/sf_.shared/scripts/lab04/.lab/99_down.sh >/dev/null 2>&1 || true

{
  echo "LAB99 -> LAB05 VERIFY  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Su dung script san co: 00_init .. 03_test_defense .. 99_down"
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

  run_step "00_init" "${LAB05_DIR}/00_init.sh" || fail=1
  run_step "01_example1_select" "${LAB05_DIR}/01_example1_select.sh" || fail=1
  run_step "02_example2_insert" "${LAB05_DIR}/02_example2_insert.sh" || fail=1
  run_step "03_test_defense" "${LAB05_DIR}/03_test_defense.sh" || fail=1
  run_step "99_down" "${LAB05_DIR}/99_down.sh" || fail=1

  echo
  if [[ "$fail" -eq 0 ]]; then
    echo "LAB05_VERIFY=PASS"
  else
    echo "LAB05_VERIFY=FAIL"
  fi
} 2>&1 | tee "$LOG"

if grep -q 'LAB05_VERIFY=PASS' "$LOG"; then
  pass "Lab 05 chuoi thu nghiem PASS"
  fail=0
else
  bad "Lab 05 chuoi thu nghiem FAIL — xem $LOG"
  fail=1
fi

{
  echo "method=Lab05_SQLi_PreparedStatements"
  echo "scripts=00_init,01_example1_select,02_example2_insert,03_test_defense,99_down"
  echo "log=$LOG"
  if [[ "$fail" -eq 0 ]]; then echo "result=PASS"; else echo "result=FAIL"; fi
} | tee "$SUMMARY"

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA LAB99 APPLY LAB05: PASS"
else
  echo "KET QUA LAB99 APPLY LAB05: FAIL"
fi
exit "$fail"
