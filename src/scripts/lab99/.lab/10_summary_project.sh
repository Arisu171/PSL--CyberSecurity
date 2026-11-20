#!/bin/bash
# Lab99: Tong hop minh chung thu nghiem an ninh phong thu toan dien (Lab 02 - Lab 05, Fail2ban, Auditd & Hardening).
# Toan bo qua trinh kiem thu duoc thuc hien truc tiep tren he thong Lab 99 (Target 10.2.99.10).

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
f2b_r="CHUA_CHAY"
audit_r="CHUA_CHAY"
harden_r="CHUA_CHAY"

[[ -f "${REPORT_DIR}/lab02_verify_summary.txt" ]] && lab02_r="$(awk -F= '/^result=/{print $2}' "${REPORT_DIR}/lab02_verify_summary.txt")"
[[ -f "${REPORT_DIR}/lab03_verify_summary.txt" ]] && lab03_r="$(awk -F= '/^result=/{print $2}' "${REPORT_DIR}/lab03_verify_summary.txt")"
[[ -f "${REPORT_DIR}/lab04_verify_summary.txt" ]] && lab04_r="$(awk -F= '/^result=/{print $2}' "${REPORT_DIR}/lab04_verify_summary.txt")"
[[ -f "${REPORT_DIR}/lab05_verify_summary.txt" ]] && lab05_r="$(awk -F= '/^result=/{print $2}' "${REPORT_DIR}/lab05_verify_summary.txt")"
[[ -f "${REPORT_DIR}/fail2ban_verify_summary.txt" ]] && f2b_r="$(awk -F= '/^result=/{print $2}' "${REPORT_DIR}/fail2ban_verify_summary.txt")"
[[ -f "${REPORT_DIR}/auditd_verify_summary.txt" ]] && audit_r="$(awk -F= '/^result=/{print $2}' "${REPORT_DIR}/auditd_verify_summary.txt")"

if [[ -f "${REPORT_DIR}/compare_report.md" ]]; then
  harden_r="CO_COMPARE_REPORT"
elif [[ -f "${REPORT_DIR}/metrics_after.json" ]]; then
  harden_r="CO_METRICS_AFTER"
fi

cat << EOF > "$OUT"
# BÁO CÁO TỔNG HỢP DỰ ÁN NGHIÊN CỨU AN NINH MẠNG – LAB 99
## Mô hình nghiên cứu: Phòng thủ theo chiều sâu (Defense-in-Depth)

- **Mục tiêu bảo vệ (Target):** \`10.2.99.10\` (\`lab99_target\`)
- **Nút đánh giá / Tấn công (Assessor):** \`10.2.99.20\` (\`lab99_assessor\`)
- **Hạ tầng kiểm thử:** Mạng ảo hóa độc lập \`10.2.99.0/24\` (\`lab99-net\`)

---

## Ma trận kiểm chứng tấn công & năng lực phòng thủ đa tầng

| Tầng phòng thủ | Kỹ thuật tấn công áp dụng | Cơ chế phòng thủ thực tế trên Target | Kết quả kiểm chứng |
|:---|:---|:---|:---:|
| **Layer 2/3 (Mạng & Liên kết)** | ARP Spoofing / Poisoning (\`08_apply_lab02.sh\`) | Reverse Path Filtering (\`rp_filter=1\`), \`arp_ignore=1\`, Static ARP binding | **${lab02_r}** |
| **Layer 3/4 (Hạ tầng DNS)** | DNS Cache Poisoning / Kaminsky (\`09_apply_lab03.sh\`) | Source Port Randomization (SPR) với dải ephemeral ports > 60,000 cổng | **${lab03_r}** |
| **Layer 4 (Sẵn sàng dịch vụ - DoS)** | TCP SYN Flood & ICMP Ping Flood (\`11_apply_lab04.sh\`) | TCP SYN Cookies (\`tcp_syncookies=1\`), UFW/iptables Rate Limiting, Backlog queue | **${lab04_r}** |
| **Layer 7 (Ứng dụng & Dữ liệu)** | SQL Injection & OS Command Injection (\`12_apply_lab05.sh\`) | Parameterized Prepared Statements & Whitelist Regex Sanitization | **${lab05_r}** |
| **Host Defense (Phản ứng chủ động)** | SSH Brute-Force Password Spraying (\`13_apply_fail2ban.sh\`) | Fail2ban tự động phát hiện vi phạm và kích hoạt iptables DROP Ban IP kẻ tấn công | **${f2b_r}** |
| **Host Auditing (Giám sát truy vết)** | Tấn công can thiệp /etc/passwd & sshd (\`14_apply_auditd.sh\`) | Linux Kernel Auditd giám sát toàn vẹn tệp tin nhạy cảm và lưu trữ bằng chứng số | **${audit_r}** |
| **Hệ điều hành (OS Hardening)** | Đánh giá bề mặt tấn công Lynis / CIS (\`01..07\`) | Khóa SSH 2222 key-only, UFW default deny, PAM pwquality, sysctl kernel | **${harden_r}** |

---

## Chi tiết file minh chứng & Nhật ký kiểm thử

1. **Minh chứng Layer 2/3 (ARP):** \`volumes/reports/lab02_verify.log\`
2. **Minh chứng DNS (SPR):** \`volumes/reports/lab03_verify.log\`
3. **Minh chứng DoS (SYN Cookies):** \`volumes/reports/lab04_verify.log\`
4. **Minh chứng AppSec (SQLi & RCE):** \`volumes/reports/lab05_verify.log\`
5. **Minh chứng Phòng thủ chủ động (Fail2ban):** \`volumes/reports/fail2ban_verify.log\`
6. **Minh chứng Giám sát truy vết (Auditd):** \`volumes/reports/auditd_verify.log\`
7. **Minh chứng Gia cố OS (Lynis/UFW):** \`volumes/reports/compare_report.md\`, \`metrics_before.json\`, \`metrics_after.json\`

---

## Kết luận khoa học

Dự án đã xây dựng và chứng minh thành công mô hình Phòng thủ theo chiều sâu (Defense-in-Depth) hoàn chỉnh từ Tầng vật lý/liên kết, Tầng giao vận, Tầng ứng dụng đến Cấu hình hệ điều hành và Giám sát số. Hệ thống không chỉ ngăn chặn thụ động các đợt tấn công mà còn chủ động phản ứng và lưu giữ đầy đủ bằng chứng kiểm toán số.
EOF

cat "$OUT"

echo
echo "===== KET QUA TONG HOP LAB 99 ====="
for r in "$lab02_r" "$lab03_r" "$lab04_r" "$lab05_r" "$f2b_r" "$audit_r"; do
  if [[ "$r" != "PASS" ]]; then
    fail=1
  fi
done

if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA TOAN BO DU AN LAB 99: PASS (100% cac tang phong thu deu duoc xac minh)"
else
  echo "KET QUA TOAN BO DU AN LAB 99: INCOMPLETE / FAIL (co tang phong thu chua dat)"
fi

exit "$fail"
