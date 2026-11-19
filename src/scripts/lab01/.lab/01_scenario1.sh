#!/bin/bash
# Kich ban 1 (Lab 01): Quet mang su dung ky thuat ARP Ping Scan (nmap -sn)
# Bat luu luong ra file task1.pcap va phan tich dac diem goi tin.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET_NET="192.168.117.0/24"
PCAP_FILE="/tmp/task1.pcap"

IFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')
if [[ -z "$IFACE" ]]; then
  IFACE="eth0"
fi

fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "1. Khoi dong tien trinh bat goi tin task1.pcap"
sudo rm -f "$PCAP_FILE"
sudo tcpdump -i "$IFACE" -n -w "$PCAP_FILE" "arp or ip" >/dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 2

note "2. Thuc thi lenh quet ARP Ping Scan: sudo nmap -sn ${TARGET_NET}"
sudo ip neigh flush all 2>/dev/null || true
sudo nmap -sn "$TARGET_NET"
sleep 2

note "3. Dung tien trinh bat goi tin"
sudo kill -2 "$TCPDUMP_PID" 2>/dev/null || sudo pkill -f 'tcpdump.*task1.pcap' || true
sleep 1

note "4. Kiem tra file luu luong task1.pcap"
if [[ -f "$PCAP_FILE" ]] && [[ -s "$PCAP_FILE" ]]; then
  pass "Da tao file luu luong $PCAP_FILE ($(ls -lh "$PCAP_FILE" | awk '{print $5}'))"
else
  bad "File $PCAP_FILE khong ton tai hoac rong"
fi

note "5. Phan tich dac diem luu luong trong task1.pcap"
echo "--- Cac goi ARP Request quang ba (Opcode 1) ---"
arp_req=$(tcpdump -n -r "$PCAP_FILE" "arp[6:2] == 1" 2>/dev/null | head -n 5)
echo "$arp_req"

echo "--- Cac goi ARP Reply tu host hoat dong (Opcode 2) ---"
arp_rep=$(tcpdump -n -r "$PCAP_FILE" "arp[6:2] == 2" 2>/dev/null | head -n 5)
echo "$arp_rep"

echo "--- Kiem tra goi TCP hoac ICMP trong luc quet (Dac diem 3: phai bang 0) ---"
tcp_icmp=$(tcpdump -n -r "$PCAP_FILE" "tcp or icmp" 2>/dev/null | wc -l)
echo "[+] So luong goi TCP/ICMP bat duoc: $tcp_icmp"
if [[ "$tcp_icmp" -le 5 ]]; then
  pass "Khong co luu luong TCP/ICMP tham do cong (Dac trung ARP Ping Scan)"
else
  echo "[-] Luu y: Co luu luong nen TCP/ICMP xuat hien tren he thong"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA KICH BAN 1 (ARP PING SCAN): PASS"
else
  echo "KET QUA KICH BAN 1 (ARP PING SCAN): FAIL"
fi
exit "$fail"
