# Ma trận Ánh xạ Kỹ thuật Tấn công & Cơ chế Phòng thủ (Lab 99)

## Mục tiêu nghiên cứu
Dự án Lab 99 áp dụng toàn bộ các phương pháp tấn công và phòng thủ chuyên đề kết hợp các cơ chế phòng thủ chủ động (Active Defense) và giám sát số (Forensics) vào quy trình đánh giá thực nghiệm trên hệ thống máy chủ mục tiêu `lab99_target` (`10.2.99.10`), dưới sự kiểm thử và phát động tấn công từ nút thẩm định `lab99_assessor` (`10.2.99.20`).

Mục đích: **Chứng minh tính hiệu quả của mô hình Phòng thủ theo chiều sâu (Defense-in-Depth) trong môi trường thực tế.**

---

## Bảng ánh xạ kỹ thuật thực nghiệm

| STT | Tầng phòng thủ | Kỹ thuật tấn công áp dụng | Kịch bản kiểm thử từ Assessor | Cơ chế phòng thủ thực tế trên Target | Script thực thi Lab 99 | File minh chứng |
|:---:|:---|:---|:---|:---|:---|:---|
| 1 | **Do thám (Reconnaissance)** | Quét cổng & Dò tìm dịch vụ | Nmap ARP scan (`-sn`), TCP SYN scan (`-sS`), TCP ACK scan (`-sA`), Service detection (`-sV`) | UFW Firewall lọc gói trạng thái (Stateful filtering), khóa toàn bộ cổng thừa, chuyển cổng SSH sang 2222 | `.lab/02_assess_surface.sh` | `surface_before.txt`<br>`surface_after.txt` |
| 2 | **Layer 2/3 (Mạng & Liên kết)** | Giả mạo ARP & Chuyển hướng lưu lượng (ARP Spoofing) | Assessor phát tán các gói ARP Reply giả mạo để đầu độc bảng ánh xạ IP-MAC của Target | Kernel `rp_filter=1`, `arp_ignore=1`, `arp_announce=2`, cơ chế ánh xạ Static ARP cố định | `.lab/08_apply_lab02.sh` | `lab02_verify.log`<br>`lab02_verify_summary.txt` |
| 3 | **Layer 3/4 (Hạ tầng DNS)** | Tấn công đầu độc DNS & Khuếch đại (Kaminsky/Amplification) | Thẩm định cổng dịch vụ DNS và kiểm tra entropy của cổng nguồn khi truy vấn ra ngoài | Source Port Randomization (SPR) với dải ephemeral ports > 60,000 cổng; Target không mở DNS Server công khai | `.lab/09_apply_lab03.sh` | `lab03_verify.log`<br>`lab03_verify_summary.txt` |
| 4 | **Layer 4 (Sẵn sàng dịch vụ - DoS)** | Tấn công từ chối dịch vụ (DoS TCP SYN Flood & ICMP Flood) | Assessor dùng `hping3` phát luồng SYN Flood ngẫu nhiên IP nguồn và bão ICMP nhằm làm sập cổng dịch vụ | Kích hoạt TCP SYN Cookies (`tcp_syncookies=1`), UFW/iptables Rate Limiting, hàng đợi backlog mở rộng | `.lab/11_apply_lab04.sh` | `lab04_verify.log`<br>`lab04_verify_summary.txt` |
| 5 | **Layer 7 (Ứng dụng Web & OWASP)** | SQL Injection & OS Command Injection (RCE) | Assessor chèn chuỗi truy vấn độc hại (Tautology Bypass, UNION) và payload nối lệnh hệ điều hành | Parameterized Prepared Statements & Whitelist Regex Input Sanitization (`shell=False`) | `.lab/12_apply_lab05.sh` | `lab05_verify.log`<br>`lab05_verify_summary.txt` |
| 6 | **Host Defense (Phòng thủ chủ động)** | Tấn công dò quét mật khẩu (SSH Brute-Force Password Spraying) | Assessor gửi hàng loạt yêu cầu xác thực SSH sai mật khẩu liên tiếp | Fail2ban tự động phát hiện vi phạm và kích hoạt iptables DROP Ban IP kẻ tấn công | `.lab/13_apply_fail2ban.sh` | `fail2ban_verify.log`<br>`fail2ban_verify_summary.txt` |
| 7 | **Host Auditing (Giám sát truy vết số)** | Tấn công can thiệp tệp tin hệ thống nhạy cảm (/etc/passwd) | Giả lập hành vi sửa đổi / đọc ghi trái phép tệp tin hệ thống mật | Linux Kernel Auditd giám sát toàn vẹn tệp tin nhạy cảm và lưu trữ bằng chứng kiểm toán số | `.lab/14_apply_auditd.sh` | `auditd_verify.log`<br>`auditd_verify_summary.txt` |
| 8 | **Hệ điều hành (OS Hardening - Lab 99)** | Đánh giá bề mặt tấn công Lynis / CIS Benchmark | Kiểm thử đăng nhập root, quét lỗ hổng cấu hình máy chủ | Vô hiệu hóa root/password SSH (chỉ nhận Ed25519 key), UFW default deny, PAM pwquality, sysctl kernel | `.lab/01` → `.lab/07` | `compare_report.md`<br>`validate_after.txt` |

---

## Luồng đánh giá & Kiểm chứng toàn diện

```
[00_init.sh] Khoi tao Target (10.2.99.10) & Assessor (10.2.99.20)
       │
       ▼
[01_baseline_audit.sh] & [02_assess_surface.sh] (Do luong truoc khi phong thu)
       │
       ▼
[03_harden.sh] Gia co phong thu toan dien (OS + Network + Sysctl + AppSec)
       │
       ▼
[04_verify_harden.sh] Kiem tra hieu luc cac co che gia co
       │
       ▼
[05_reassess.sh] & [06_compare_report.sh] So sanh metrics truoc / sau gia co
       │
       ▼
[07_validate_defense.sh] Kiem tra be mat cong khai tu Assessor
       │
       ▼
[08_apply_lab02.sh] Assessor tan cong ARP Spoofing -> Kiem chung phong thu Layer 2
       │
       ▼
[09_apply_lab03.sh] Assessor tham dinh DNS -> Kiem chung Source Port Randomization
       │
       ▼
[11_apply_lab04.sh] Assessor tan cong DoS SYN Flood -> Kiem chung TCP SYN Cookies & Rate Limit
       │
       ▼
[12_apply_lab05.sh] Assessor tan cong SQLi & RCE -> Kiem chung Prepared Statements & Input Sanitization
       │
       ▼
[13_apply_fail2ban.sh] Assessor tan cong Brute-Force -> Kiem chung phong thu chu dong Fail2ban
       │
       ▼
[14_apply_auditd.sh] Gia lap can thiep file he thong -> Kiem chung giam sat truy vet Auditd
       │
       ▼
[10_summary_project.sh] Tong hop toan dien ma tran ket qua vao project_summary.md
```
