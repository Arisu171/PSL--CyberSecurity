# BÁO CÁO TỔNG HỢP DỰ ÁN NGHIÊN CỨU AN NINH MẠNG – LAB 99
## Mô hình nghiên cứu: Phòng thủ theo chiều sâu (Defense-in-Depth)

- **Mục tiêu bảo vệ (Target):** `10.2.99.10` (`lab99_target`)
- **Nút đánh giá / Tấn công (Assessor):** `10.2.99.20` (`lab99_assessor`)
- **Hạ tầng kiểm thử:** Mạng ảo hóa độc lập `10.2.99.0/24` (`lab99-net`)

---

## Ma trận kiểm chứng tấn công & năng lực phòng thủ đa tầng

| Tầng phòng thủ | Kỹ thuật tấn công áp dụng | Cơ chế phòng thủ thực tế trên Target | Kết quả kiểm chứng |
|:---|:---|:---|:---:|
| **Layer 2/3 (Mạng & Liên kết)** | ARP Spoofing / Poisoning (`08_apply_lab02.sh`) | Reverse Path Filtering (`rp_filter=1`), `arp_ignore=1`, Static ARP binding | **PASS** |
| **Layer 3/4 (Hạ tầng DNS)** | DNS Cache Poisoning / Kaminsky (`09_apply_lab03.sh`) | Source Port Randomization (SPR) với dải ephemeral ports > 60,000 cổng | **PASS** |
| **Layer 4 (Sẵn sàng dịch vụ - DoS)** | TCP SYN Flood & ICMP Ping Flood (`11_apply_lab04.sh`) | TCP SYN Cookies (`tcp_syncookies=1`), UFW/iptables Rate Limiting, Backlog queue | **PASS** |
| **Layer 7 (Ứng dụng & Dữ liệu)** | SQL Injection & OS Command Injection (`12_apply_lab05.sh`) | Parameterized Prepared Statements & Whitelist Regex Sanitization | **PASS** |
| **Host Defense (Phản ứng chủ động)** | SSH Brute-Force Password Spraying (`13_apply_fail2ban.sh`) | Fail2ban tự động phát hiện vi phạm và kích hoạt iptables DROP Ban IP kẻ tấn công | **PASS** |
| **Host Auditing (Giám sát truy vết)** | Tấn công can thiệp /etc/passwd & sshd (`14_apply_auditd.sh`) | Linux Kernel Auditd giám sát toàn vẹn tệp tin nhạy cảm và lưu trữ bằng chứng số | **PASS** |
| **Hệ điều hành (OS Hardening)** | Đánh giá bề mặt tấn công Lynis / CIS (`01..07`) | Khóa SSH 2222 key-only, UFW default deny, PAM pwquality, sysctl kernel | **CO_COMPARE_REPORT** |

---

## Chi tiết file minh chứng & Nhật ký kiểm thử

1. **Minh chứng Layer 2/3 (ARP):** `volumes/reports/lab02_verify.log`
2. **Minh chứng DNS (SPR):** `volumes/reports/lab03_verify.log`
3. **Minh chứng DoS (SYN Cookies):** `volumes/reports/lab04_verify.log`
4. **Minh chứng AppSec (SQLi & RCE):** `volumes/reports/lab05_verify.log`
5. **Minh chứng Phòng thủ chủ động (Fail2ban):** `volumes/reports/fail2ban_verify.log`
6. **Minh chứng Giám sát truy vết (Auditd):** `volumes/reports/auditd_verify.log`
7. **Minh chứng Gia cố OS (Lynis/UFW):** `volumes/reports/compare_report.md`, `metrics_before.json`, `metrics_after.json`

---

## Kết luận khoa học

Dự án đã xây dựng và chứng minh thành công mô hình Phòng thủ theo chiều sâu (Defense-in-Depth) hoàn chỉnh từ Tầng vật lý/liên kết, Tầng giao vận, Tầng ứng dụng đến Cấu hình hệ điều hành và Giám sát số. Hệ thống không chỉ ngăn chặn thụ động các đợt tấn công mà còn chủ động phản ứng và lưu giữ đầy đủ bằng chứng kiểm toán số.
