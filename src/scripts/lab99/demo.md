# HƯỚNG DẪN THỰC NGHIỆM DỰ ÁN NGHIÊN CỨU AN NINH MẠNG – LAB 99
## Mô hình kiểm chứng: Phòng thủ theo chiều sâu (Defense-in-Depth)

Dự án áp dụng toàn diện các kỹ thuật tấn công và biện pháp phòng vệ thực nghiệm đã học từ **Lab 01 đến Lab 05**, kết hợp **Phòng thủ phản ứng chủ động (Fail2ban)** và **Giám sát truy vết số (Auditd)** trực tiếp trên hệ thống mục tiêu **Lab 99**:
- **Target:** `10.2.99.10` (`lab99_target` - Máy chủ được bảo vệ & gia cố)
- **Assessor:** `10.2.99.20` (`lab99_assessor` - Trạm phát động tấn công & đánh giá độc lập)
- **Subnet độc lập:** `10.2.99.0/24` (`lab99-net`)

---

## 1. Kết nối SSH từ máy Windows lên Ubuntu Server
```bash
ssh orias@192.168.117.13
```

## 2. Di chuyển vào thư mục bài Lab 99
```bash
cd /media/sf_.shared/scripts/lab99
```

## 3. Quy trình thực nghiệm & Đánh giá năng lực phòng thủ toàn diện

### Giai đoạn 1: Khởi tạo hệ sinh thái Lab 99
```bash
bash .lab/00_init.sh
```

### Giai đoạn 2: Đánh giá hiện trạng ban đầu (Baseline Before Hardening)
```bash
# 1) Kiểm toán baseline cấu hình và chỉ số Lynis ban đầu
bash .lab/01_baseline_audit.sh

# 2) Thăm dò bề mặt tấn công mạng (Kỹ thuật thăm dò Nmap từ Lab 01)
bash .lab/02_assess_surface.sh before

# 3) Đánh giá kiểm thử bề mặt công khai ban đầu
bash .lab/07_validate_defense.sh before
```

### Giai đoạn 3: Triển khai gia cố hệ thống toàn diện (Multi-layer Hardening)
```bash
# 4) Áp dụng gia cố: SSH 2222, UFW, Fail2ban, Sysctl (rp_filter, syncookies), Static ARP, AppSec
bash .lab/03_harden.sh

# 5) Xác minh hiệu lực cấu hình sau gia cố
bash .lab/04_verify_harden.sh
```

### Giai đoạn 4: Tái đánh giá & Đo lường độ cải thiện (After Hardening)
```bash
# 6) Tái kiểm toán chỉ số Lynis và dịch vụ sau gia cố
bash .lab/05_reassess.sh

# 7) Thăm dò lại bề mặt mạng sau khi UFW chặn cổng thừa
bash .lab/02_assess_surface.sh after

# 8) Kiểm chứng bảo mật bề mặt dịch vụ sau gia cố
bash .lab/07_validate_defense.sh after

# 9) So sánh định lượng Before vs After (sinh file compare_report.md)
bash .lab/06_compare_report.sh
```

### Giai đoạn 5: Phát động các kịch bản tấn công thực tế từ Assessor để kiểm chứng phòng thủ
```bash
# 10) Phát động tấn công ARP Spoofing -> Kiểm chứng phòng vệ Layer 2/3 (Lab 02)
bash .lab/08_apply_lab02.sh

# 11) Thẩm định hạ tầng DNS -> Kiểm chứng cơ chế Source Port Randomization (Lab 03)
bash .lab/09_apply_lab03.sh

# 12) Phát động tấn công DoS TCP SYN Flood & ICMP Flood -> Kiểm chứng SYN Cookies & Rate Limit (Lab 04)
bash .lab/11_apply_lab04.sh

# 13) Phát động tấn công Web AppSec: SQLi & OS Command Injection (RCE) -> Kiểm chứng Prepared Statements & Input Sanitization (Lab 05)
bash .lab/12_apply_lab05.sh

# 14) Phát động tấn công SSH Brute-Force -> Kiểm chứng phòng thủ chủ động Fail2ban (Tự động Ban IP)
bash .lab/13_apply_fail2ban.sh

# 15) Giả lập can thiệp tệp tin nhạy cảm (/etc/passwd) -> Kiểm chứng giám sát truy vết Auditd (HIDS)
bash .lab/14_apply_auditd.sh
```

### Giai đoạn 6: Tổng hợp báo cáo nghiên cứu hoàn chỉnh
```bash
# 16) Tổng hợp ma trận kết quả toàn bộ dự án vào project_summary.md
bash .lab/10_summary_project.sh
```

*(Khi hoàn thành toàn bộ kịch bản, đóng dọn dẹp container bằng lệnh:)*
```bash
bash .lab/99_down.sh
```

---

## 4. Minh chứng kết quả thu được trong `volumes/reports/`

- `compare_report.md`: Báo cáo so sánh định lượng Lynis Index, cổng mở, dịch vụ trước và sau khi gia cố.
- `lab02_verify.log`: Bằng chứng cơ chế Static ARP và `rp_filter` ngăn chặn thành công ARP Spoofing.
- `lab03_verify.log`: Bằng chứng dải cổng nguồn ephemeral mở rộng bảo vệ hạ tầng DNS trước Kaminsky attack.
- `lab04_verify.log`: Bằng chứng dịch vụ duy trì phản hồi thông suốt trong cơn bão DoS SYN Flood nhờ TCP SYN Cookies.
- `lab05_verify.log`: Bằng chứng Parameterized Prepared Statements & Input Sanitization triệt tiêu hoàn toàn SQLi và RCE.
- `fail2ban_verify.log`: Bằng chứng Fail2ban tự động phát hiện brute-force và ban IP kẻ tấn công vào iptables.
- `auditd_verify.log`: Bằng chứng Linux Kernel Auditd ghi nhận đầy đủ dấu vết can thiệp tệp tin hệ thống mật.
- `project_summary.md`: Ma trận tổng hợp đạt chuẩn phòng thủ toàn diện 100% PASS.

---

## 5. Đóng gói hồ sơ nghiệm thu
```bash
cd /media/sf_.shared/scripts/lab99/volumes/reports
zip -q ../Nhom6_Lab99_BaoCao.zip project_summary.md compare_report.md lab02_verify* lab03_verify* lab04_verify* lab05_verify* fail2ban_verify* auditd_verify* metrics_* validate_* nmap_* 2>/dev/null
ls -lh ../Nhom6_Lab99_BaoCao.zip
```
