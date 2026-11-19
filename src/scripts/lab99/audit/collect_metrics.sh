#!/bin/bash
# Thu thap chi so bao mat tren target. Args: <label>  (before|after)
set -u

LABEL="${1:-before}"
OUT_DIR="${OUT_DIR:-/volumes/reports}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
JSON="${OUT_DIR}/metrics_${LABEL}.json"
TXT="${OUT_DIR}/metrics_${LABEL}.txt"
SCORE=0
MAX_SCORE=12

mkdir -p "$OUT_DIR"

ssh_port="22"
if ss -lntu 2>/dev/null | grep -q ':2222'; then
  ssh_port="2222"
elif ss -lntu 2>/dev/null | grep -q ':22 '; then
  ssh_port="22"
fi

permit_root="$(sshd -T 2>/dev/null | awk '/^permitrootlogin /{print $2; exit}')"
password_auth="$(sshd -T 2>/dev/null | awk '/^passwordauthentication /{print $2; exit}')"
allow_users="$(sshd -T 2>/dev/null | awk '/^allowusers /{print; exit}')"
ufw_status="$(ufw status 2>/dev/null | head -1 | tr -d '\r')"
f2b="inactive"
fail2ban-client status sshd >/dev/null 2>&1 && f2b="active"
auditd_on="no"
pgrep -x auditd >/dev/null 2>&1 && auditd_on="yes"
unattended="no"
[[ -f /etc/apt/apt.conf.d/20auto-upgrades ]] && grep -q 'Unattended-Upgrade "1"' /etc/apt/apt.conf.d/20auto-upgrades && unattended="yes"
rp_filter="$(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null || echo NA)"
syncookies="$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo NA)"
aslr="$(sysctl -n kernel.randomize_va_space 2>/dev/null || echo NA)"
open_tcp="$(ss -lnt 2>/dev/null | awk 'NR>1{print $4}' | sed 's/.*://' | sort -n | uniq | tr '\n' ',' | sed 's/,$//')"
lynis_score="NA"
if command -v lynis >/dev/null 2>&1; then
  # Lynis trong container co the can quyen; chay quick audit neu duoc.
  lynis audit system --quick --quiet --no-colors >/tmp/lynis_lab99.txt 2>&1 || true
  lynis_score="$(awk -F'[][]' '/Hardening index/{gsub(/ /,"",$2); print $2; exit}' /tmp/lynis_lab99.txt 2>/dev/null || echo NA)"
  [[ -z "$lynis_score" ]] && lynis_score="NA"
  cp /tmp/lynis_lab99.txt "${OUT_DIR}/lynis_${LABEL}.txt" 2>/dev/null || true
fi

# Cham diem noi bo (12 tieu chi) — so sanh before/after ro rang.
[[ "$permit_root" == "no" ]] && SCORE=$((SCORE + 1))
[[ "$password_auth" == "no" ]] && SCORE=$((SCORE + 1))
[[ "$ssh_port" == "2222" ]] && SCORE=$((SCORE + 1))
echo "$allow_users" | grep -qi labuser && SCORE=$((SCORE + 1))
echo "$ufw_status" | grep -qi 'active' && SCORE=$((SCORE + 1))
[[ "$f2b" == "active" ]] && SCORE=$((SCORE + 1))
[[ "$auditd_on" == "yes" ]] && SCORE=$((SCORE + 1))
[[ "$unattended" == "yes" ]] && SCORE=$((SCORE + 1))
[[ "$rp_filter" == "1" ]] && SCORE=$((SCORE + 1))
[[ "$syncookies" == "1" ]] && SCORE=$((SCORE + 1))
[[ "$aslr" == "2" ]] && SCORE=$((SCORE + 1))
# Chi SSH (va port harden) dang listen: khong co dich vu thua ro rang tren 80/443/3306/21
echo ",${open_tcp}," | grep -Eq ',80,|,443,|,3306,|,21,' || SCORE=$((SCORE + 1))

{
  echo "label=${LABEL}"
  echo "timestamp_utc=${STAMP}"
  echo "ssh_port=${ssh_port}"
  echo "permit_rootlogin=${permit_root:-NA}"
  echo "password_authentication=${password_auth:-NA}"
  echo "allow_users=${allow_users:-NA}"
  echo "ufw=${ufw_status:-NA}"
  echo "fail2ban_sshd=${f2b}"
  echo "auditd=${auditd_on}"
  echo "unattended_upgrades=${unattended}"
  echo "rp_filter=${rp_filter}"
  echo "tcp_syncookies=${syncookies}"
  echo "aslr=${aslr}"
  echo "open_tcp_ports=${open_tcp}"
  echo "lynis_hardening_index=${lynis_score}"
  echo "lab99_score=${SCORE}/${MAX_SCORE}"
} | tee "$TXT"

python3 - <<PY
import json
data = {
  "label": "${LABEL}",
  "timestamp_utc": "${STAMP}",
  "ssh_port": "${ssh_port}",
  "permit_rootlogin": "${permit_root:-NA}",
  "password_authentication": "${password_auth:-NA}",
  "allow_users": """${allow_users:-NA}""",
  "ufw": """${ufw_status:-NA}""",
  "fail2ban_sshd": "${f2b}",
  "auditd": "${auditd_on}",
  "unattended_upgrades": "${unattended}",
  "rp_filter": "${rp_filter}",
  "tcp_syncookies": "${syncookies}",
  "aslr": "${aslr}",
  "open_tcp_ports": "${open_tcp}",
  "lynis_hardening_index": "${lynis_score}",
  "lab99_score": ${SCORE},
  "lab99_score_max": ${MAX_SCORE},
}
with open("${JSON}", "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
print("Wrote ${JSON}")
PY

echo "SCORE ${SCORE}/${MAX_SCORE} (${LABEL})"
exit 0
