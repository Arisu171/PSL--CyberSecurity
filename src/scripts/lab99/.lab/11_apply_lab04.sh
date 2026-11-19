#!/bin/bash
# Lab99: ap dung dung chuoi thu nghiem Lab 04 (DoS ICMP/SYN Flood/DNS Amplification -> SYN Cookies & iptables defense).
# Tai su dung script da co trong lab04/.lab — khong viet tan cong moi.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
LAB04_DIR="/media/sf_.shared/scripts/lab04/.lab"
REPORT_DIR="${PROJECT_LAB}/volumes/reports"
LOG="${REPORT_DIR}/lab04_verify.log"
SUMMARY="${REPORT_DIR}/lab04_verify_summary.txt"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

mkdir -p "$REPORT_DIR"

if [[ ! -d "$LAB04_DIR" ]]; then
  echo "Khong thay Lab 04: $LAB04_DIR"
  exit 1
fi

note "Giai phong subnet 10.2.6.0/24 (tat cac lab khac neu dang chay)"
bash "${PROJECT_LAB}/.lab/99_down.sh" >/dev/null 2>&1 || true
bash /media/sf_.shared/scripts/lab02/.lab/99_down.sh >/dev/null 2>&1 || true
bash /media/sf_.shared/scripts/lab03/.lab/99_down.sh >/dev/null 2>&1 || true
bash /media/sf_.shared/scripts/lab05/.lab/99_down.sh >/dev/null 2>&1 || true

{
  echo "LAB99 -> LAB04 VERIFY  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Su dung script san co: 00_init .. 04_test_defense .. 99_down"
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

  run_step "00_init" "${LAB04_DIR}/00_init.sh" || fail=1
  run_step "01_scenario1" "${LAB04_DIR}/01_scenario1.sh" || fail=1
  run_step "02_scenario2" "${LAB04_DIR}/02_scenario2.sh" || fail=1
  run_step "03_scenario3" "${LAB04_DIR}/03_scenario3.sh" || fail=1
  run_step "04_test_defense" "${LAB04_DIR}/04_test_defense.sh" || fail=1
  run_step "99_down" "${LAB04_DIR}/99_down.sh" || fail=1

  echo
  if [[ "$fail" -eq 0 ]]; then
    echo "LAB04_VERIFY=PASS"
  else
    echo "LAB04_VERIFY=FAIL"
  fi
} 2>&1 | tee "$LOG"

if grep -q 'LAB04_VERIFY=PASS' "$LOG"; then
  pass "Lab 04 chuoi thu nghiem PASS"
  fail=0
else
  bad "Lab 04 chuoi thu nghiem FAIL — xem $LOG"
  fail=1
fi

{
  echo "method=Lab04_DoS_SYNCookies_RateLimit"
  echo "scripts=00_init,01_scenario1,02_scenario2,03_scenario3,04_test_defense,99_down"
  echo "log=$LOG"
  if [[ "$fail" -eq 0 ]]; then echo "result=PASS"; else echo "result=FAIL"; fi
} | tee "$SUMMARY"

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA LAB99 APPLY LAB04: PASS"
else
  echo "KET QUA LAB99 APPLY LAB04: FAIL"
fi
exit "$fail"
