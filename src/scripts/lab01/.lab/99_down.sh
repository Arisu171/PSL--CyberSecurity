#!/bin/bash
# Dong Lab 01: Dung cac tien trinh bat goi tin (tcpdump, dumpcap, tshark), don dep luu luong tam.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"

PCAP_DIR="/tmp"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "1. Dung cac tien trinh thu thap goi tin va quet nen"
sudo pkill -9 -f 'tcpdump.*task.*\.pcap' 2>/dev/null || true
sudo pkill -9 -x dumpcap 2>/dev/null || true
sudo pkill -9 -x tshark 2>/dev/null || true
sudo pkill -9 -x nmap 2>/dev/null || true
pass "Da dung toan bo cac tien trinh quet va bat goi tin"

note "2. Kiem tra danh sach cac file PCAP da tao"
found_pcap=0
for i in 1 2 3 4; do
  pcap_file="${PCAP_DIR}/task${i}.pcap"
  if [[ -f "$pcap_file" ]]; then
    pass "Tim thay $pcap_file ($(ls -lh "$pcap_file" | awk '{print $5}'))"
    found_pcap=$(( found_pcap + 1 ))
  else
    echo "[-] File $pcap_file chua duoc tao"
  fi
done

if [[ "$found_pcap" -gt 0 ]]; then
  echo "[+] Tong so file PCAP luu giu: $found_pcap/4 file"
fi

note "3. Kiem tra tien trinh con ton dong"
if pgrep -f 'tcpdump.*task' >/dev/null 2>&1; then
  bad "Van con tien trinh tcpdump chay ngam"
else
  pass "He thong sach se, khong con tien trinh chay ngam"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA DONG LAB 01: PASS"
else
  echo "KET QUA DONG LAB 01: FAIL"
fi
exit "$fail"
