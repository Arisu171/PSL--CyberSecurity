#!/bin/bash
# Khoi tao Lab 01: Kiem tra moi truong thuc nghiem quet mang Nmap va bat goi tin PCAP.
# Kiem tra cong cu nmap, tcpdump/dumpcap, tshark va ket noi toi muc tieu 192.168.117.13.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET_IP="192.168.117.13"
TARGET_NET="192.168.117.0/24"
MAIL_NET="192.168.100.0/24"
PCAP_DIR="/tmp"

fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "1. Kiem tra card mang hoat dong"
IFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')
if [[ -z "$IFACE" ]]; then
  IFACE="eth0"
fi
echo "[+] Su dung card mang: $IFACE"
ip addr show "$IFACE" || bad "Khong the lay thong tin card mang $IFACE"

note "2. Kiem tra cac cong cu can thiet"
for bin in nmap tcpdump; do
  if which "$bin" >/dev/null 2>&1; then
    pass "Cong cu $bin da duoc cai dat"
  else
    bad "Thieu cong cu $bin (can: sudo apt install $bin)"
  fi
done

for opt_bin in tshark dumpcap wireshark; do
  if which "$opt_bin" >/dev/null 2>&1; then
    pass "Cong cu phan tich $opt_bin san sang"
  else
    echo "[-] Cong cu bo sung $opt_bin chua cai (co the dung tcpdump thay the)"
  fi
done

note "3. Kiem tra ket noi toi may Server muc tieu (${TARGET_IP})"
if ping -c 2 -W 2 "$TARGET_IP" >/dev/null 2>&1; then
  pass "Ket noi toi Server ${TARGET_IP} thanh cong"
else
  echo "[-] Canh bao: Khong ping duoc ${TARGET_IP} (co the dang chay tren Server hoac may muc tieu tat ping)"
fi

note "4. Don dep cac file pcap cu tai ${PCAP_DIR}"
sudo rm -f "${PCAP_DIR}/task"*.pcap 2>/dev/null || true
sudo pkill -f 'tcpdump.*task.*\.pcap' 2>/dev/null || true
pass "Moi truong Lab 01 da san sang thuc nghiem"

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA KHOI TAO LAB 01: PASS"
else
  echo "KET QUA KHOI TAO LAB 01: FAIL"
fi
exit "$fail"
