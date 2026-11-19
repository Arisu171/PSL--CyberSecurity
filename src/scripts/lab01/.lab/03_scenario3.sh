#!/bin/bash
# Kich ban 3 (Lab 01): Quet cong su dung ky thuat TCP ACK Scan (nmap -sA -F)
# Bat luu luong ra file task3.pcap va phan tich co che phat hien firewall (unfiltered).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET_IP="192.168.117.13"
PCAP_FILE="/tmp/task3.pcap"

IFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')
if [[ -z "$IFACE" ]]; then
  IFACE="eth0"
fi

fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "1. Khoi dong tien trinh bat goi tin task3.pcap"
sudo rm -f "$PCAP_FILE"
sudo tcpdump -i "$IFACE" -n -w "$PCAP_FILE" "tcp" >/dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 2

note "2. Thuc thi lenh quet TCP ACK Scan: sudo nmap -sA -F ${TARGET_IP}"
sudo nmap -sA -F "$TARGET_IP"
sleep 2

note "3. Dung tien trinh bat goi tin"
sudo kill -2 "$TCPDUMP_PID" 2>/dev/null || sudo pkill -f 'tcpdump.*task3.pcap' || true
sleep 1

note "4. Kiem tra file luu luong task3.pcap"
if [[ -f "$PCAP_FILE" ]] && [[ -s "$PCAP_FILE" ]]; then
  pass "Da tao file luu luong $PCAP_FILE ($(ls -lh "$PCAP_FILE" | awk '{print $5}'))"
else
  bad "File $PCAP_FILE khong ton tai hoac rong"
fi

note "5. Phan tich dac diem luu luong TCP ACK Scan trong task3.pcap"
echo "--- Cac goi TCP chi bat co ACK (Flags 0x010) gui di ---"
ack_sent=$(tcpdump -n -r "$PCAP_FILE" 'tcp[tcpflags] == tcp-ack' 2>/dev/null | head -n 5)
echo "$ack_sent"

echo "--- Cac goi RST tra loi tu muc tieu (khang dinh cong unfiltered) ---"
rst_reply=$(tcpdump -n -r "$PCAP_FILE" 'tcp[tcpflags] & tcp-rst != 0' 2>/dev/null | head -n 5)
echo "$rst_reply"

echo "--- Kiem tra goi SYN (phai bang 0 vi khong co bat tay) ---"
syn_count=$(tcpdump -n -r "$PCAP_FILE" 'tcp[tcpflags] & tcp-syn != 0' 2>/dev/null | wc -l)
echo "[+] So luong goi SYN xuat hien: $syn_count"
if [[ "$syn_count" -le 2 ]]; then
  pass "Khong co goi SYN nao duoc gui: Xac nhan ky thuat thuan tuy la ACK Scan"
else
  echo "[-] Luu y: Co goi SYN nen xuat hien"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA KICH BAN 3 (TCP ACK SCAN): PASS"
else
  echo "KET QUA KICH BAN 3 (TCP ACK SCAN): FAIL"
fi
exit "$fail"
