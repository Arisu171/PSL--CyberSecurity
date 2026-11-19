#!/bin/bash
# Lab99 Tuan 1: thu thap metrics + Lynis TRUOC hardening.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_TARGET="lab99_target"
COLLECT="/audit/collect_metrics.sh"
REPORT_HOST="${PROJECT_LAB}/volumes/reports"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "Chay collect_metrics.sh (before) trong target"
sudo docker exec -e OUT_DIR=/volumes/reports "$CONTAINER_TARGET" \
  bash "$COLLECT" before
rc=$?
[[ "$rc" -eq 0 ]] && pass "Da ghi metrics_before" || bad "collect_metrics that bai"

note "File bao cao"
ls -lh "${REPORT_HOST}/metrics_before."* 2>/dev/null || bad "Thieu metrics_before"
[[ -f "${REPORT_HOST}/metrics_before.json" ]] && pass "metrics_before.json"
cat "${REPORT_HOST}/metrics_before.txt" 2>/dev/null || true

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA BASELINE: PASS"
else
  echo "KET QUA BASELINE: FAIL"
fi
exit "$fail"
