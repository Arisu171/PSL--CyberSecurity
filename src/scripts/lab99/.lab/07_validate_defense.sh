#!/bin/bash
# Lab99: kiem chung phong thu bang ky thuat/cong cu cong khai (sau harden).
# Co the truyen: before | after  (mac dinh after)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_ASSESSOR="lab99_assessor"
PHASE="${1:-after}"
REPORT_HOST="${PROJECT_LAB}/volumes/reports"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "Validate public checks (${PHASE})"
sudo docker exec \
  -e OUT_DIR=/volumes/reports \
  -e TARGET_IP=10.2.99.10 \
  -e KEY_FILE=/volumes/lab99_id_ed25519 \
  "$CONTAINER_ASSESSOR" bash /audit/validate_public_checks.sh "$PHASE"
rc=$?

[[ -f "${REPORT_HOST}/validate_${PHASE}.txt" ]] && pass "validate_${PHASE}.txt" || bad "Thieu validate report"
[[ -f "${REPORT_HOST}/nmap_${PHASE}.txt" ]] && pass "nmap_${PHASE}.txt" || true
[[ "$rc" -eq 0 ]] && pass "validate script exit 0" || bad "validate script exit $rc"

echo
echo "----- validate_${PHASE}.txt (tail) -----"
tail -60 "${REPORT_HOST}/validate_${PHASE}.txt" 2>/dev/null || true

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA VALIDATE DEFENSE (${PHASE}): PASS"
else
  echo "KET QUA VALIDATE DEFENSE (${PHASE}): FAIL"
fi
exit "$fail"
