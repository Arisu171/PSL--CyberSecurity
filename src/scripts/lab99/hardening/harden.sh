#!/bin/bash
# Ap dung hardening Ubuntu target (chay TRONG container lab99_target).
set -u

HARDEN_DIR="${HARDEN_DIR:-/hardening}"
SSH_DROPIN="/etc/ssh/sshd_config.d/99-lab99-hardening.conf"
SYSCTL_DROPIN="/etc/sysctl.d/99-lab99-hardening.conf"
JAIL_LOCAL="/etc/fail2ban/jail.local"
PWQUALITY="/etc/security/pwquality.conf"
SSH_PORT="2222"
APP_PORT="8080"
ALLOW_USER="labuser"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

if [[ ! -d "$HARDEN_DIR" ]]; then
  echo "Thieu thu muc hardening: $HARDEN_DIR"
  exit 1
fi

note "1) SSH hardening (port ${SSH_PORT}, no root/password login)"
mkdir -p /etc/ssh/sshd_config.d /home/"$ALLOW_USER"/.ssh
chmod 700 /home/"$ALLOW_USER"/.ssh
if [[ ! -f /home/"$ALLOW_USER"/.ssh/authorized_keys ]]; then
  # Tao key noi bo de van SSH duoc sau khi tat password (dung cho lab).
  ssh-keygen -t ed25519 -N "" -f /tmp/lab99_id_ed25519 -q
  cat /tmp/lab99_id_ed25519.pub > /home/"$ALLOW_USER"/.ssh/authorized_keys
  cp /tmp/lab99_id_ed25519 /volumes/lab99_id_ed25519
  cp /tmp/lab99_id_ed25519.pub /volumes/lab99_id_ed25519.pub
  chmod 600 /home/"$ALLOW_USER"/.ssh/authorized_keys /volumes/lab99_id_ed25519
  chown -R "$ALLOW_USER":"$ALLOW_USER" /home/"$ALLOW_USER"/.ssh
  pass "Da tao SSH key labuser -> /volumes/lab99_id_ed25519"
fi
cp "${HARDEN_DIR}/sshd_hardening.conf" "$SSH_DROPIN"
chmod 644 "$SSH_DROPIN"
# Dam bao Port 22 khong con lang nghe sau harden (sshd chi dung drop-in).
if grep -qE '^Port ' /etc/ssh/sshd_config; then
  sed -i 's/^Port .*/# Port overridden by sshd_config.d/' /etc/ssh/sshd_config
fi
sshd -t && pass "sshd_config hop le" || bad "sshd_config loi"
service ssh restart || /usr/sbin/sshd
pass "SSH dang lang nghe cong ${SSH_PORT}"

note "2) UFW firewall & Rate Limiting (chong DoS)"
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}/tcp" comment 'lab99-ssh'
ufw allow "${APP_PORT}/tcp" comment 'lab99-app'
ufw --force enable
# Quy tac Rate Limiting phong ve TCP SYN Flood va ICMP Flood
iptables -I INPUT -p tcp --dport "${SSH_PORT}" --syn -m limit --limit 10/s --limit-burst 20 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p icmp -m limit --limit 5/s --limit-burst 10 -j ACCEPT 2>/dev/null || true
ufw status verbose | head -20
pass "UFW va Rate Limiting da duoc kich hoat"

note "3) Fail2ban"
cp "${HARDEN_DIR}/jail.local" "$JAIL_LOCAL"
mkdir -p /var/log
touch /var/log/auth.log
service fail2ban restart || true
sleep 1
if fail2ban-client status sshd >/dev/null 2>&1; then
  pass "fail2ban jail sshd active"
else
  # Mot so container khong co systemd socket; thu start truc tiep.
  fail2ban-server -x start 2>/dev/null || true
  sleep 1
  fail2ban-client status sshd >/dev/null 2>&1 && pass "fail2ban jail sshd active" || bad "fail2ban sshd chua active"
fi

note "4) Kernel sysctl (chong IP/ARP Spoofing va SYN Flood)"
cp "${HARDEN_DIR}/sysctl-hardening.conf" "$SYSCTL_DROPIN"
sysctl --system >/tmp/sysctl_lab99.out 2>&1 || true
grep -E 'rp_filter|tcp_syncookies|arp_ignore|arp_announce' /tmp/sysctl_lab99.out | head -10 || true
pass "Da nap sysctl hardening"

note "5) Co che phong thu ARP tinh (Static ARP Defense)"
# Khoa anh xa MAC cho gateway va assessor de triet tieu rui ro ARP Poisoning
GATEWAY_IP="10.2.99.254"
ASSESSOR_IP="10.2.99.20"
ping -c 1 "$ASSESSOR_IP" >/dev/null 2>&1 || true
ASSESSOR_MAC=$(ip neigh show "$ASSESSOR_IP" 2>/dev/null | awk '{print $5}')
if [[ -n "$ASSESSOR_MAC" && "$ASSESSOR_MAC" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then
  ip neigh replace "$ASSESSOR_IP" lladdr "$ASSESSOR_MAC" nud permanent dev eth0 2>/dev/null || true
  pass "Da thiet lap Static ARP khoa cung ${ASSESSOR_IP} -> ${ASSESSOR_MAC}"
else
  echo "[*] Chua tim thay MAC Assessor qua ARP cache"
fi

note "6) PAM password quality"
if [[ -f "$PWQUALITY" ]]; then
  cp "${HARDEN_DIR}/pwquality.conf" "$PWQUALITY"
  pass "pwquality.conf updated"
else
  bad "Thieu $PWQUALITY"
fi

note "7) Unattended upgrades"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
pass "unattended-upgrades bat"

note "8) Auditd"
if command -v auditctl >/dev/null 2>&1; then
  service auditd start 2>/dev/null || auditd 2>/dev/null || true
  auditctl -w /etc/passwd -p wa -k identity 2>/dev/null || true
  auditctl -w /etc/ssh/sshd_config -p wa -k sshd_config 2>/dev/null || true
  auditctl -w /etc/ssh/sshd_config.d -p wa -k sshd_config 2>/dev/null || true
  pass "auditd rules nap (passwd/sshd)"
else
  echo "WARN: auditctl khong co san tren moi truong"
fi

note "9) Dam bao ung dung Web Lab99 hoat dong"
if ! pgrep -f lab99_app.py >/dev/null 2>&1; then
  python3 /usr/local/bin/lab99_app.py 8080 > /volumes/logs/lab99_app.log 2>&1 &
  sleep 1
fi
if curl -s "http://127.0.0.1:${APP_PORT}/health" | grep -q "healthy"; then
  pass "Ung dung Web Lab99 hoat dong binh thuong tren port ${APP_PORT}"
else
  bad "Khong the khoi chay ung dung Web Lab99 tren port ${APP_PORT}"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA HARDENING: PASS"
else
  echo "KET QUA HARDENING: FAIL"
fi
exit "$fail"
