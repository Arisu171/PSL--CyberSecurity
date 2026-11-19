# Phương pháp thử nghiệm Lab99: Tái sử dụng chuỗi tấn công & phòng thủ (Lab 02 - Lab 05)

Không viết tấn công mới. Lab99 **gọi lại** đúng script đã có trong `lab02/.lab`, `lab03/.lab`, `lab04/.lab` và `lab05/.lab`.

| Nguồn | Phương pháp tấn công đã học | Kịch bản kiểm thử | Biện pháp phòng thủ đã kiểm chứng | Wrapper Lab99 |
|---|---|---|---|---|
| **Lab 02** | ARP Reply/Request spoofing, MITM netcat | `01_scenario1` … `03_scenario3` | Cơ chế ARP tĩnh (Static ARP) `04_fix_server.sh` | `08_apply_lab02.sh` |
| **Lab 03** | Kaminsky DNS cache poisoning | `01_gen_query` … `03_test_attack` | Source Port Randomization (SPR) `04_test_defense.sh` | `09_apply_lab03.sh` |
| **Lab 04** | DoS ICMP Flood, TCP SYN Flood, DNS Amplification | `01_scenario1` … `03_scenario3` | TCP SYN Cookies, iptables Rate Limiting `04_test_defense.sh` | `11_apply_lab04.sh` |
| **Lab 05** | SQL Injection (SELECT Tautology, UNION, Blind, INSERT) | `01_example1_select` … `02_example2_insert` | Parameterized Prepared Statements PDO `03_test_defense.sh` | `12_apply_lab05.sh` |
| **Lab 99 (tuỳ chọn)** | Hardening host Ubuntu (SSH, UFW, Fail2ban, sysctl) | `.lab/01` → `.lab/07` | So sánh metrics trước/sau hardening | Nhánh song song độc lập |

## Luồng chứng minh tin cậy (Verification Flow)

1. **Lab 02:** Chạy `08_apply_lab02.sh` → log `volumes/reports/lab02_verify.log` (Kỳ vọng: ARP tĩnh chặn triệt để MITM).
2. **Lab 03:** Chạy `09_apply_lab03.sh` → log `volumes/reports/lab03_verify.log` (Kỳ vọng: SPR vô hiệu hóa Kaminsky attack).
3. **Lab 04:** Chạy `11_apply_lab04.sh` → log `volumes/reports/lab04_verify.log` (Kỳ vọng: SYN Cookies & iptables duy trì dịch vụ khi bị flood).
4. **Lab 05:** Chạy `12_apply_lab05.sh` → log `volumes/reports/lab05_verify.log` (Kỳ vọng: Prepared Statements ngăn chặn hoàn toàn SQLi).
5. **Tổng hợp:** Chạy `10_summary_project.sh` → gom toàn bộ kết quả vào `project_summary.md`.

*Subnet các bài lab chia sẻ là `10.2.6.0/24`: Mỗi script wrapper tự động chạy `99_down.sh` của các lab khác trước khi bắt đầu.*
