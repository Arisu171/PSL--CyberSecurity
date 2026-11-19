#!/bin/bash
# Lab99 Tuan 2: ap dung hardening bang harden.sh trong target.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_TARGET="lab99_target"
HARDEN="/hardening/harden.sh"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "Chay harden.sh"
sudo docker exec -e HARDEN_DIR=/hardening "$CONTAINER_TARGET" bash "$HARDEN"
rc=$?
[[ "$rc" -eq 0 ]] && pass "Hardening xong" || bad "Hardening FAIL (exit=$rc)"

note "Kiem tra SSH doi cong 2222"
ss_out="$(sudo docker exec "$CONTAINER_TARGET" ss -lnt | grep 2222 || true)"
echo "$ss_out"
grep -q 2222 <<<"$ss_out" && pass "Lang nghe 2222" || bad "Chua lang nghe 2222"

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA HARDEN: PASS"
  echo "SSH key (neu moi tao): ${PROJECT_LAB}/volumes/lab99_id_ed25519"
else
  echo "KET QUA HARDEN: FAIL"
fi
exit "$fail"
