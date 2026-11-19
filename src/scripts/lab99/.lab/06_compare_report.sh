#!/bin/bash
# Lab99: sinh bao cao so sanh before/after.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORT_DIR="${PROJECT_LAB}/volumes/reports"
BEFORE="${REPORT_DIR}/metrics_before.json"
AFTER="${REPORT_DIR}/metrics_after.json"
OUT_MD="${REPORT_DIR}/compare_report.md"
COMPARE_PY="${PROJECT_LAB}/audit/compare_report.py"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "So sanh metrics"
[[ -f "$BEFORE" ]] || bad "Thieu $BEFORE"
[[ -f "$AFTER" ]] || bad "Thieu $AFTER"
if [[ "$fail" -ne 0 ]]; then
  echo "Chay 01_baseline_audit.sh roi 03_harden.sh + 05_reassess.sh truoc."
  exit 1
fi

# Chay compare tren host (Python). Neu host thieu python, chay trong assessor.
if command -v python3 >/dev/null 2>&1; then
  python3 "$COMPARE_PY" "$BEFORE" "$AFTER" "$OUT_MD"
  rc=$?
else
  sudo docker exec lab99_assessor python3 /audit/compare_report.py \
    /volumes/reports/metrics_before.json \
    /volumes/reports/metrics_after.json \
    /volumes/reports/compare_report.md
  rc=$?
fi

[[ -f "$OUT_MD" ]] && pass "Da tao $OUT_MD" || bad "Thieu compare_report.md"
[[ "$rc" -eq 0 ]] && pass "Diem after > before" || bad "Diem after khong cao hon before (rc=$rc)"
echo
cat "$OUT_MD" 2>/dev/null || true

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA COMPARE: PASS"
else
  echo "KET QUA COMPARE: FAIL"
fi
exit "$fail"
