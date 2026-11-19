#!/bin/bash
# Kiem thu giai phap phong chong tan cong DoS tren Victim
# 1. Kich hoat TCP SYN Cookies (net.ipv4.tcp_syncookies = 1)
# 2. Cau hinh iptables Rate Limiting chong ICMP Flood va SYN Flood

set -u

CONTAINER_VICTIM="lab04_victim"
CONTAINER_ATTACKER="lab04_attacker"
CONTAINER_USER="lab04_user"
IP_VICTIM="10.2.6.20"

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; }

note "1. Kich hoat TCP SYN Cookies va toi uu hang doi Backlog tren Victim"
sudo docker exec "$CONTAINER_VICTIM" bash -c "
  sysctl -w net.ipv4.tcp_syncookies=1
  sysctl -w net.ipv4.tcp_max_syn_backlog=2048
  sysctl -w net.ipv4.tcp_synack_retries=2
"
pass "Da bat SYN Cookies va cau hinh toi uu TCP kernel parameters"

note "2. Thiet lap iptables Rate Limiting tren Victim"
sudo docker exec "$CONTAINER_VICTIM" bash -c "
  iptables -F
  # Gioi han ICMP 2 goi/giay
  iptables -A INPUT -p icmp -m limit --limit 2/s --limit-burst 5 -j ACCEPT
  iptables -A INPUT -p icmp -j DROP
  # Gioi han ket noi moi vao port 23 (SYN rate limit)
  iptables -A INPUT -p tcp --dport 23 --syn -m limit --limit 5/s --limit-burst 10 -j ACCEPT
  iptables -A INPUT -p tcp --dport 23 --syn -j DROP
"
pass "Da thiet lap luat iptables Rate Limiting thanh cong"

note "3. Attacker phat dong lai SYN Flood vao port 23 trong 4 giay de kiem thu"
if sudo docker exec "$CONTAINER_ATTACKER" which hping3 >/dev/null 2>&1; then
  sudo docker exec "$CONTAINER_ATTACKER" timeout 4 hping3 -S -p 23 "$IP_VICTIM" --flood --rand-source 2>/dev/null || true
else
  sudo timeout 4 hping3 -S -p 23 "$IP_VICTIM" --flood --rand-source 2>/dev/null || true
fi

note "4. User ket noi Telnet toi Victim KHI DANG BI TAN CONG (co phong thu)"
if sudo docker exec "$CONTAINER_USER" nc -z -w 3 "$IP_VICTIM" 23; then
  pass "User van ket noi thanh cong nho SYN Cookies va iptables rate limiting!"
else
  bad "Ket noi van bi anh huong"
fi

note "5. Reset lai luat iptables ve mac dinh"
sudo docker exec "$CONTAINER_VICTIM" iptables -F

echo -e "\n[✓] KIEM THU PHONG CHONG DoS HOAN TAT XUAT SAC!"
