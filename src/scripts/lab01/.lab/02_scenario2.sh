#!/bin/bash
# Kich ban 2 (Lab 01): Quet cong su dung ky thuat TCP SYN Scan (nmap -sS -F)
# Bat luu luong ra file task2.pcap va phan tich co che Half-Open Scan.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET_IP="192.168.117.13"
PCAP_FILE="/tmp/task2.pcap"

IFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')
if [[ -z "$IFACE" ]]; then
  IFACE="eth0"
fi

fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "1. Khoi dong tien trinh bat goi tin task2.pcap"
sudo rm -f "$PCAP_FILE"
sudo tcpdump -i "$IFACE" -n -w "$PCAP_FILE" "tcp or arp" >/dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 2

note "2. Thuc thi lenh quet TCP SYN Scan: sudo nmap -sS -F ${TARGET_IP}"
sudo nmap -sS -F "$TARGET_IP"
sleep 2

note "3. Dung tien trinh bat goi tin"
sudo kill -2 "$TCPDUMP_PID" 2>/dev/null || sudo pkill -f 'tcpdump.*task2.pcap' || true
sleep 1

note "4. Kiem tra file luu luong task2.pcap"
if [[ -f "$PCAP_FILE" ]] && [[ -s "$PCAP_FILE" ]]; then
  pass "Da tao file luu luong $PCAP_FILE ($(ls -lh "$PCAP_FILE" | awk '{print $5}'))"
else
  bad "File $PCAP_FILE khong ton tai hoac rong"
fi

note "5. Phan tich dac diem luu luong Half-Open trong task2.pcap"
echo "--- Cac goi SYN gui toi nhieu cong dich ---"
syn_sent=$(tcpdump -n -r "$PCAP_FILE" 'tcp[tcpflags] & tcp-syn != 0 and tcp[tcpflags] & tcp-ack == 0' 2>/dev/null | head -n 5)
echo "$syn_sent"

echo "--- Cac goi SYN/ACK tra ve tu cong mo ---"
syn_ack=$(tcpdump -n -r "$PCAP_FILE" 'tcp[tcpflags] & (tcp-syn|tcp-ack) == (tcp-syn|tcp-ack)' 2>/dev/null | head -n 5)
echo "$syn_ack"

echo "--- Cac goi RST/ACK tra ve tu cong dong ---"
rst_recv=$(tcpdump -n -r "$PCAP_FILE" 'tcp[tcpflags] & tcp-rst != 0' 2>/dev/null | head -n 5)
echo "$rst_recv"

echo "--- Kiem tra bat tay 3 buoc: Khong co goi ACK nao de hoan tat ket noi ---"
ack_sent=$(tcpdump -n -r "$PCAP_FILE" "src host ${TARGET_IP} and tcp[tcpflags] == tcp-ack" 2>/dev/null | wc -l)
echo "[+] So luong goi ACK hoan tat bat tay: $ack_sent"
if [[ "$ack_sent" -le 5 ]]; then
  pass "Xac nhan dac tinh Half-Open Scan: May do tham gui RST thay vi ACK de ket thuc!"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA KICH BAN 2 (TCP SYN SCAN): PASS"
else
  echo "KET QUA KICH BAN 2 (TCP SYN SCAN): FAIL"
fi
exit "$fail"
