#!/bin/bash
# Kich ban 4 (Lab 01): Thu thap thong tin he thong - Quet may chu Mail, OS va Phien ban dich vu.
# Bat luu luong ra file task4.pcap va kiem tra banner dich vu.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET_IP="192.168.117.13"
TARGET_NET="192.168.117.0/24"
MAIL_NET="192.168.100.0/24"
MAIL_HOST="192.168.100.20"
PCAP_FILE="/tmp/task4.pcap"

IFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')
if [[ -z "$IFACE" ]]; then
  IFACE="eth0"
fi

fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "1. Khoi dong tien trinh bat goi tin task4.pcap"
sudo rm -f "$PCAP_FILE"
sudo tcpdump -i "$IFACE" -n -w "$PCAP_FILE" "tcp or ip" >/dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 2

note "2. Quet tim kiem may chu Mail (ports: 25, 110, 143, 465, 587, 993, 995)"
echo "--- Quet tren dai mang ${MAIL_NET} (theo de bai) va ${TARGET_NET} ---"
if ping -c 1 -W 1 "$MAIL_HOST" >/dev/null 2>&1; then
  sudo nmap -p 25,110,143,465,587,993,995 --open "$MAIL_NET" || true
  SCAN_TARGET="$MAIL_HOST"
else
  echo "[i] May ${MAIL_HOST} khong phan hoi tren card hien tai, su dung may chu thuc nghiem: ${TARGET_IP}"
  sudo nmap -p 25,110,143,465,587,993,995 --open "$TARGET_NET" || true
  SCAN_TARGET="$TARGET_IP"
fi

note "3. Nhan dien he dieu hanh may chu (sudo nmap -O ${SCAN_TARGET})"
sudo nmap -O "$SCAN_TARGET" || echo "[-] Nhan dien OS can quyen raw socket"

note "4. Quet phien ban chi tiet cac dich vu (sudo nmap -sV ${SCAN_TARGET})"
sudo nmap -sV "$SCAN_TARGET"

note "5. Dung tien trinh bat goi tin"
sudo kill -2 "$TCPDUMP_PID" 2>/dev/null || sudo pkill -f 'tcpdump.*task4.pcap' || true
sleep 1

note "6. Kiem tra file luu luong task4.pcap"
if [[ -f "$PCAP_FILE" ]] && [[ -s "$PCAP_FILE" ]]; then
  pass "Da tao file luu luong $PCAP_FILE ($(ls -lh "$PCAP_FILE" | awk '{print $5}'))"
else
  bad "File $PCAP_FILE khong ton tai hoac rong"
fi

note "7. Kiem tra dung luong cac file pcap (Yeu cau < 5MB)"
for p in /tmp/task*.pcap; do
  if [[ -f "$p" ]]; then
    sz=$(stat -c%s "$p" 2>/dev/null || stat -f%z "$p" 2>/dev/null || echo 0)
    sz_mb=$(( sz / 1048576 ))
    if [[ "$sz_mb" -lt 5 ]]; then
      pass "File $p dat yeu cau: $(ls -lh "$p" | awk '{print $5}') (< 5MB)"
    else
      bad "File $p vuot qua 5MB: $(ls -lh "$p" | awk '{print $5}')"
    fi
  fi
done

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA KICH BAN 4 (THU THAP THONG TIN HE THONG): PASS"
else
  echo "KET QUA KICH BAN 4 (THU THAP THONG TIN HE THONG): FAIL"
fi
exit "$fail"
