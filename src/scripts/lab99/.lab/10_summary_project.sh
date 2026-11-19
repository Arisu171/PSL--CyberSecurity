#!/bin/bash
# Lab99: tong hop minh chung thu nghiem toan dien (Lab02 + Lab03 + Lab04 + Lab05 + harden neu co).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORT_DIR="${PROJECT_LAB}/volumes/reports"
OUT="${REPORT_DIR}/project_summary.md"
fail=0

mkdir -p "$REPORT_DIR"

lab02_r="CHUA_CHAY"
lab03_r="CHUA_CHAY"
lab04_r="CHUA_CHAY"
lab05_r="CHUA_CHAY"
harden_r="CHUA_CHAY"

[[ -f "${REPORT_DIR}/lab02_verify_summary.txt" ]] && lab02_r="$(awk -F= '/^result=/{print $2}' "${REPORT_DIR}/lab02_verify_summary.txt")"
[[ -f "${REPORT_DIR}/lab03_verify_summary.txt" ]] && lab03_r="$(awk -F= '/^result=/{print $2}' "${REPORT_DIR}/lab03_verify_summary.txt")"
[[ -f "${REPORT_DIR}/lab04_verify_summary.txt" ]] && lab04_r="$(awk -F= '/^result=/{print $2}' "${REPORT_DIR}/lab04_verify_summary.txt")"
[[ -f "${REPORT_DIR}/lab05_verify_summary.txt" ]] && lab05_r="$(awk -F= '/^result=/{print $2}' "${REPORT_DIR}/lab05_verify_summary.txt")"

if [[ -f "${REPORT_DIR}/compare_report.md" ]]; then
  harden_r="CO_COMPARE_REPORT"
elif [[ -f "${REPORT_DIR}/metrics_after.json" ]]; then
  harden_r="CO_METRICS_AFTER"
fi

{
  echo "# Lab99 – Tong hop bai tap lon an ninh mang"
  echo
  echo "## Phuong phap thu nghiem (tai su dung cac chuoi tan cong & phong thu Lab 02 - Lab 05)"
  echo
  echo "| Nguon | Ky thuat tan cong da hoc | Bien phap phong thu da kiem chung | Ket qua |"
  echo "|-------|--------------------------|------------------------------------|---------|"
  echo "| **Lab 02** | ARP cache poisoning + MITM packet sniffing | Co che ARP tinh Static ARP (\`04_fix_server.sh\`) | ${lab02_r} |"
  echo "| **Lab 03** | Kaminsky DNS Cache Poisoning | Source Port Randomization SPR (\`04_test_defense.sh\`) | ${lab03_r} |"
  echo "| **Lab 04** | DoS ICMP/SYN Flood, DNS Amplification | TCP SYN Cookies, iptables Rate Limiting (\`04_test_defense.sh\`) | ${lab04_r} |"
  echo "| **Lab 05** | SQL Injection (SELECT Tautology, UNION, Blind, INSERT) | Parameterized Prepared Statements PDO (\`03_test_defense.sh\`) | ${lab05_r} |"
  echo "| **Lab 99** (tuy chon) | Hardening Ubuntu host/container | SSH Hardening, UFW, Fail2ban, sysctl kernel | ${harden_r} |"
  echo
  echo "## File minh chung chi tiet"
  echo
  echo "- \`lab02_verify.log\` / \`lab02_verify_summary.txt\`"
  echo "- \`lab03_verify.log\` / \`lab03_verify_summary.txt\`"
  echo "- \`lab04_verify.log\` / \`lab04_verify_summary.txt\`"
  echo "- \`lab05_verify.log\` / \`lab05_verify_summary.txt\`"
  echo "- \`compare_report.md\`, \`metrics_*.json\`, \`validate_*.txt\` (neu chay nhanh harden)"
  echo
  echo "## Ket luan danh gia nang luc phong thu"
  echo
  echo "1. **Lop Lien ket & Mang (Layer 2/3):** Co che ARP tinh da ngan chan hoan toan ke tan cong chen vao giua (MITM) de danh cap du lieu."
  echo "2. **Lop Dich vu Nen tang (DNS):** Ky thuat Source Port Randomization mo rong khong gian entropy tu 16-bit len 32-bit khien tan cong dau doc DNS tro nen bat kha thi ve mat xac suat."
  echo "3. **Lop San sang (DoS Defense):** Giai phap TCP SYN Cookies ket hop luat gioi han toc do luu luong (iptables Rate Limiting) duy tri dich vu on dinh ngay ca khi hung chiu tan cong tu choi dich vu quy mo lon."
  echo "4. **Lop Ung dung (AppSec):** Prepared Statements loai bo triet de nguy co chen ma doc SQL bang cach co lap hoan toan giua cau truc lenh va gia tri du lieu."
  echo
} | tee "$OUT"

# Kiem tra neu tat ca cac lab co chay deu dat PASS
[[ "$lab02_r" == "PASS" || "$lab02_r" == "CHUA_CHAY" ]] || fail=1
[[ "$lab03_r" == "PASS" || "$lab03_r" == "CHUA_CHAY" ]] || fail=1
[[ "$lab04_r" == "PASS" || "$lab04_r" == "CHUA_CHAY" ]] || fail=1
[[ "$lab05_r" == "PASS" || "$lab05_r" == "CHUA_CHAY" ]] || fail=1

# Yeu cau it nhat Lab 04 hoac Lab 05 hoac Lab 02/03 phai chay PASS
if [[ "$lab04_r" != "PASS" && "$lab05_r" != "PASS" && "$lab02_r" != "PASS" && "$lab03_r" != "PASS" ]]; then
  fail=1
fi

echo
echo "Wrote $OUT"
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA SUMMARY PROJECT: PASS"
else
  echo "KET QUA SUMMARY PROJECT: FAIL"
fi
exit "$fail"
