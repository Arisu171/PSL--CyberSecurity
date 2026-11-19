#!/bin/bash
# Lab99: metrics AFTER + assess surface after.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_TARGET="lab99_target"
CONTAINER_ASSESSOR="lab99_assessor"
REPORT_HOST="${PROJECT_LAB}/volumes/reports"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "Collect metrics (after)"
sudo docker exec -e OUT_DIR=/volumes/reports "$CONTAINER_TARGET" \
  bash /audit/collect_metrics.sh after
[[ -f "${REPORT_HOST}/metrics_after.json" ]] && pass "metrics_after.json" || bad "Thieu metrics_after.json"
cat "${REPORT_HOST}/metrics_after.txt" 2>/dev/null || true

note "Assess surface (after)"
sudo docker exec -e OUT_DIR=/volumes/reports -e TARGET_IP=10.2.99.10 \
  -e KEY_FILE=/volumes/lab99_id_ed25519 \
  "$CONTAINER_ASSESSOR" bash /audit/assess_surface.sh after
[[ -f "${REPORT_HOST}/surface_after.txt" ]] && pass "surface_after.txt" || bad "Thieu surface_after.txt"

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA REASSESS: PASS"
else
  echo "KET QUA REASSESS: FAIL"
fi
exit "$fail"
