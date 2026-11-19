# Lab99 – Tong hop bai tap lon an ninh mang

## Phuong phap thu nghiem (tai su dung cac chuoi tan cong & phong thu Lab 02 - Lab 05)

| Nguon | Ky thuat tan cong da hoc | Bien phap phong thu da kiem chung | Ket qua |
|-------|--------------------------|------------------------------------|---------|
| **Lab 02** | ARP cache poisoning + MITM packet sniffing | Co che ARP tinh Static ARP (`04_fix_server.sh`) | PASS |
| **Lab 03** | Kaminsky DNS Cache Poisoning | Source Port Randomization SPR (`04_test_defense.sh`) | PASS |
| **Lab 04** | DoS ICMP/SYN Flood, DNS Amplification | TCP SYN Cookies, iptables Rate Limiting (`04_test_defense.sh`) | PASS |
| **Lab 05** | SQL Injection (SELECT Tautology, UNION, Blind, INSERT) | Parameterized Prepared Statements PDO (`03_test_defense.sh`) | PASS |
| **Lab 99** (tuy chon) | Hardening Ubuntu host/container | SSH Hardening, UFW, Fail2ban, sysctl kernel | CO_COMPARE_REPORT |

## File minh chung chi tiet

- `lab02_verify.log` / `lab02_verify_summary.txt`
- `lab03_verify.log` / `lab03_verify_summary.txt`
- `lab04_verify.log` / `lab04_verify_summary.txt`
- `lab05_verify.log` / `lab05_verify_summary.txt`
- `compare_report.md`, `metrics_*.json`, `validate_*.txt` (neu chay nhanh harden)

## Ket luan danh gia nang luc phong thu

1. **Lop Lien ket & Mang (Layer 2/3):** Co che ARP tinh da ngan chan hoan toan ke tan cong chen vao giua (MITM) de danh cap du lieu.
2. **Lop Dich vu Nen tang (DNS):** Ky thuat Source Port Randomization mo rong khong gian entropy tu 16-bit len 32-bit khien tan cong dau doc DNS tro nen bat kha thi ve mat xac suat.
3. **Lop San sang (DoS Defense):** Giai phap TCP SYN Cookies ket hop luat gioi han toc do luu luong (iptables Rate Limiting) duy tri dich vu on dinh ngay ca khi hung chiu tan cong tu choi dich vu quy mo lon.
4. **Lop Ung dung (AppSec):** Prepared Statements loai bo triet de nguy co chen ma doc SQL bang cach co lap hoan toan giua cau truc lenh va gia tri du lieu.

