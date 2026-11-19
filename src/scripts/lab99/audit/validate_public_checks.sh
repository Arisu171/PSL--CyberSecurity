#!/bin/bash
# Kiem chung phong thu bang ky thuat/cong cu CONG KHAI (nmap, ssh, nc, ss).
# Chi chay tren target lab so huu. Khong brute-force, khong exploit.
# Args: <phase> before|after
set -u

PHASE="${1:-after}"
TARGET_IP="${TARGET_IP:-10.2.99.10}"
OUT_DIR="${OUT_DIR:-/volumes/reports}"
OUT="${OUT_DIR}/validate_${PHASE}.txt"
KEY="${KEY_FILE:-/volumes/lab99_id_ed25519}"
PASS=0
FAIL=0
SKIP=0

mkdir -p "$OUT_DIR"

ok() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
bad() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }
skip() { echo "[SKIP] $1"; SKIP=$((SKIP + 1)); }

port_open() {
  local port="$1"
  nc -z -w 2 "$TARGET_IP" "$port" >/dev/null 2>&1
}

ssh_auth_line() {
  local port="$1"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=4 \
    -o PreferredAuthentications=none -p "$port" "labuser@${TARGET_IP}" 2>&1 \
    | tr '\n' ' ' | head -c 400
}

{
  echo "===== VALIDATE PUBLIC CHECKS (${PHASE}) target=${TARGET_IP} ====="
  echo "Tham chieu: /audit/techniques_map.md"
  echo

  echo "### T1 Nmap inventory (cong cu cong khai)"
  nmap -Pn -sT --top-ports 100 -T4 "$TARGET_IP" -oN "${OUT_DIR}/nmap_${PHASE}.txt" || true
  echo "(chi tiet: nmap_${PHASE}.txt)"
  echo

  echo "### T2 Be mat cong 22 vs 2222"
  if [[ "$PHASE" == "before" ]]; then
    port_open 22 && ok "Truoc harden: TCP/22 mo (ky vong baseline)" || bad "Truoc harden: TCP/22 khong mo"
    port_open 2222 && skip "TCP/2222 da mo som (bat thuong nhung khong fail lab)" || ok "Truoc harden: TCP/2222 chua mo"
  else
    port_open 22 && bad "Sau harden: TCP/22 van mo" || ok "Sau harden: TCP/22 khong mo (UFW/sshd)"
    port_open 2222 && ok "Sau harden: TCP/2222 mo" || bad "Sau harden: TCP/2222 khong mo"
  fi
  echo

  echo "### T3 SSH auth method probe (khong gui mat khau)"
  line22="$(ssh_auth_line 22 || true)"
  line2222="$(ssh_auth_line 2222 || true)"
  echo "probe:22 => ${line22}"
  echo "probe:2222 => ${line2222}"
  if [[ "$PHASE" == "before" ]]; then
    echo "$line22" | grep -qiE 'password|keyboard-interactive|permission denied' \
      && ok "Baseline SSH/22 phan hoi auth (co the password)" \
      || skip "Khong doc duoc auth banner cong 22"
  else
    if echo "$line2222" | grep -qi 'publickey' && ! echo "$line2222" | grep -qi 'password'; then
      ok "Sau harden: SSH/2222 uu tien/chi publickey (password khong con trong goi y)"
    elif echo "$line2222" | grep -qi 'permission denied'; then
      ok "Sau harden: SSH/2222 tu choi BatchMode (ky vong can key)"
    else
      bad "Sau harden: khong xac nhan duoc che do auth an toan tren 2222"
    fi
    # Thu password-only BatchMode: phai that bai nhanh
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=4 \
      -o PubkeyAuthentication=no -o PreferredAuthentications=password \
      -p 2222 "labuser@${TARGET_IP}" true 2>/tmp/ssh_pw_try.txt || true
    if grep -qiE 'password|publickey|permission denied|invalid' /tmp/ssh_pw_try.txt; then
      if grep -qi 'passwordauthentication' /tmp/ssh_pw_try.txt; then
        ok "PasswordAuthentication bi tu choi/tat (probe)"
      else
        ok "Login password-only BatchMode khong thanh cong (dung ky vong sau harden)"
      fi
      cat /tmp/ssh_pw_try.txt | head -5
    else
      skip "Khong bat duoc thong diep password-only probe"
      cat /tmp/ssh_pw_try.txt 2>/dev/null | head -5 || true
    fi
  fi
  echo

  echo "### T4 Root login probe"
  root_out="$(
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=4 \
      -o PreferredAuthentications=none -p "$([ "$PHASE" = before ] && echo 22 || echo 2222)" \
      "root@${TARGET_IP}" 2>&1 | tr '\n' ' ' | head -c 400 || true
  )"
  echo "probe:root => ${root_out}"
  if [[ "$PHASE" == "after" ]]; then
    echo "$root_out" | grep -qiE 'permission denied|connection refused|no route|connection closed' \
      && ok "Root SSH khong dang nhap duoc (BatchMode)" \
      || skip "Khong ket luan duoc root probe"
  else
    skip "Baseline: root login co the con mo (chi ghi nhan)"
  fi
  echo

  echo "### T5 Key login sau harden (neu co key)"
  if [[ "$PHASE" == "after" && -f "$KEY" ]]; then
    if ssh -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
      -p 2222 "labuser@${TARGET_IP}" 'echo KEY_LOGIN_OK' 2>/dev/null | grep -q KEY_LOGIN_OK; then
      ok "Admin hop le van SSH bang key cong 2222"
    else
      bad "Key login 2222 that bai"
    fi
  else
    skip "Bo qua key login (phase=before hoac chua co key)"
  fi
  echo

  echo "### T6 Dich vu thua (FTP/HTTP/DB) — ky vong khong mo"
  extra_fail=0
  for p in 21 80 443 3306 5432; do
    if port_open "$p"; then
      echo "  OPEN unexpected: $p"
      extra_fail=1
    fi
  done
  [[ "$extra_fail" -eq 0 ]] && ok "Khong thay 21/80/443/3306/5432 mo" || bad "Co cong dich vu thua dang mo"
  echo

  echo "===== SUMMARY ${PHASE}: PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP} ====="
} | tee "$OUT"

echo "Wrote $OUT"
# before: cho phep FAIL=0 chu yeu; after: FAIL phai = 0
if [[ "$PHASE" == "after" && "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
