#!/bin/bash
# Danh gia be mat tu assessor: quet cong + kiem thu SSH an toan (KHONG brute-force).
# Args: <phase> before|after
set -u

PHASE="${1:-before}"
TARGET_IP="${TARGET_IP:-10.2.99.10}"
OUT_DIR="${OUT_DIR:-/volumes/reports}"
OUT="${OUT_DIR}/surface_${PHASE}.txt"
KEY="${KEY_FILE:-/volumes/lab99_id_ed25519}"

mkdir -p "$OUT_DIR"

{
  echo "===== SURFACE ASSESSMENT (${PHASE}) target=${TARGET_IP} ====="
  echo "--- ping ---"
  ping -c 2 -W 1 "$TARGET_IP" || true
  echo "--- nmap top ports + light service detect (inventory, lab-owned) ---"
  nmap -Pn -sT -sV --version-intensity 2 --top-ports 50 -T4 "$TARGET_IP" || true
  echo "--- ssh banner / auth methods port 22 ---"
  nc -vz -w 2 "$TARGET_IP" 22 2>&1 || true
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=3 \
    -o PreferredAuthentications=none -p 22 "labuser@${TARGET_IP}" 2>&1 | head -5 || true
  echo "--- ssh banner / auth methods port 2222 ---"
  nc -vz -w 2 "$TARGET_IP" 2222 2>&1 || true
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=3 \
    -o PreferredAuthentications=none -p 2222 "labuser@${TARGET_IP}" 2>&1 | head -5 || true
  if [[ -f "$KEY" ]]; then
    echo "--- ssh key login thu cong 2222 ---"
    ssh -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
      -p 2222 "labuser@${TARGET_IP}" 'echo KEY_LOGIN_OK; hostname' 2>&1 || true
  else
    echo "--- chua co key /volumes/lab99_id_ed25519 (sau harden moi co) ---"
  fi
  echo "===== END SURFACE ${PHASE} ====="
} | tee "$OUT"

echo "Wrote $OUT"
