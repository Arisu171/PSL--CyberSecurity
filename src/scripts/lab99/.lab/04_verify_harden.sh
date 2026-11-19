#!/bin/bash
# Lab99: xac minh control sau harden (sshd -T, ufw, fail2ban).

set -u

CONTAINER_TARGET="lab99_target"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "sshd -T (cac chi so then chot)"
ssh_t="$(sudo docker exec "$CONTAINER_TARGET" sshd -T 2>/dev/null || true)"
echo "$ssh_t" | grep -E '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|allowusers) ' || true
echo "$ssh_t" | grep -q '^port 2222$' && pass "Port 2222" || bad "Port khong phai 2222"
echo "$ssh_t" | grep -q '^permitrootlogin no$' && pass "PermitRootLogin no" || bad "Root login chua tat"
echo "$ssh_t" | grep -q '^passwordauthentication no$' && pass "PasswordAuthentication no" || bad "Password auth chua tat"

note "UFW"
ufw_s="$(sudo docker exec "$CONTAINER_TARGET" ufw status 2>/dev/null || true)"
echo "$ufw_s" | head -15
echo "$ufw_s" | grep -qi active && pass "UFW active" || bad "UFW inactive"

note "Fail2ban"
f2b="$(sudo docker exec "$CONTAINER_TARGET" fail2ban-client status sshd 2>/dev/null || true)"
echo "$f2b" | head -20
echo "$f2b" | grep -qi 'Jail list\|sshd\|Currently' && pass "fail2ban sshd" || bad "fail2ban sshd loi"

note "sysctl"
sudo docker exec "$CONTAINER_TARGET" sysctl net.ipv4.conf.all.rp_filter net.ipv4.tcp_syncookies kernel.randomize_va_space

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA VERIFY HARDEN: PASS"
else
  echo "KET QUA VERIFY HARDEN: FAIL"
fi
exit "$fail"
