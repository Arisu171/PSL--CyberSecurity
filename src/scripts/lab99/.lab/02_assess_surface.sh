#!/bin/bash
# Lab99: danh gia be mat tu assessor (nmap inventory + SSH auth probe an toan).
# Khong thuc hien brute-force / exploit.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_ASSESSOR="lab99_assessor"
PHASE="${1:-before}"
ASSESS="/audit/assess_surface.sh"
REPORT_HOST="${PROJECT_LAB}/volumes/reports"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "Assess surface (${PHASE})"
sudo docker exec -e OUT_DIR=/volumes/reports -e TARGET_IP=10.2.99.10 \
  "$CONTAINER_ASSESSOR" bash "$ASSESS" "$PHASE"
[[ -f "${REPORT_HOST}/surface_${PHASE}.txt" ]] && pass "surface_${PHASE}.txt" || bad "Thieu surface report"
tail -40 "${REPORT_HOST}/surface_${PHASE}.txt" || true

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA ASSESS SURFACE (${PHASE}): PASS"
else
  echo "KET QUA ASSESS SURFACE (${PHASE}): FAIL"
fi
exit "$fail"
