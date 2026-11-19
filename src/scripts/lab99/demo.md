# LAB99 – Bài tập lớn: kiểm chứng phòng thủ bằng Lab 02 & Lab 03

**Ý tưởng:** dùng đúng phương pháp thử nghiệm đã làm ở Lab 02 (ARP/MITM) và Lab 03 (Kaminsky DNS) — script sẵn có — để chứng minh phòng thủ trên môi trường lab sở hữu. Không nghiên cứu/ viết exploit mới.

- Share: `/media/sf_.shared/scripts/lab99`
- Wrapper gọi lại: `/media/sf_.shared/scripts/lab02/.lab/*` và `lab03/.lab/*`
- Báo cáo gom: `volumes/reports/`

---

## Máy ảo cần bật

Chỉ cần **Ubuntu Server** (Docker + share) — nơi từng chạy Lab 02/03.
Ubuntu Desktop chỉ để SSH điều khiển nếu muốn.

Docker khi chạy Lab 02 / Lab 03 vẫn như cũ (không phải 2 container Lab99 harden):

| Lab | Container                                            | Việc                                                    |
| --- | ---------------------------------------------------- | -------------------------------------------------------- |
| 02  | `lab02_user`, `lab02_server`, `lab02_attacker` | ARP poison → MITM → ARP tĩnh                          |
| 03  | user / attacker / local-dns / attacker-ns            | Kaminsky → SPR                                          |
| 04  | victim / attacker / user / dns                       | DoS (ICMP/SYN Flood, DNS Amp) → SYN Cookies & iptables  |
| 05  | webserver / attacker / user                          | SQL Injection (SELECT/INSERT) → PDO Prepared Statements |

Lab99 harden (`lab99_target` + `lab99_assessor` trên `10.2.99.0/24`) là **nhánh tuỳ chọn** (hardening host), không thay thế Lab 02-05.

---

## 1. Kết nối SSH từ máy Windows lên Ubuntu Server
```bash
ssh orias@192.168.117.13
```

## 2. Di chuyển vào thư mục bài Lab trên Server
```bash
cd /media/sf_.shared/scripts/lab99
```

## 3. Cách chạy chính (Áp dụng kiểm chứng phòng thủ Lab 02 - Lab 05)

```bash
# 1) Chứng minh ARP/MITM + ARP tĩnh (dùng script Lab 02)
bash .lab/08_apply_lab02.sh

# 2) Chứng minh Kaminsky + SPR (dùng script Lab 03)
bash .lab/09_apply_lab03.sh

# 3) Chứng minh DoS Defense + SYN Cookies / Rate Limit (dùng script Lab 04)
bash .lab/11_apply_lab04.sh

# 4) Chứng minh SQLi Defense + Prepared Statements (dùng script Lab 05)
bash .lab/12_apply_lab05.sh

# 5) Tổng hợp ma trận báo cáo toàn diện 5 lab
bash .lab/10_summary_project.sh
```

*(Hoặc chạy trực tiếp từ bất kỳ đâu bằng đường dẫn tuyệt đối):*
```bash
bash /media/sf_.shared/scripts/lab99/.lab/08_apply_lab02.sh
bash /media/sf_.shared/scripts/lab99/.lab/09_apply_lab03.sh
bash /media/sf_.shared/scripts/lab99/.lab/11_apply_lab04.sh
bash /media/sf_.shared/scripts/lab99/.lab/12_apply_lab05.sh
bash /media/sf_.shared/scripts/lab99/.lab/10_summary_project.sh
```

Mỗi bước `08`/`09`/`11`/`12` sẽ tự động tắt các lab khác để tránh trùng subnet `10.2.6.0/24`, rồi chạy nguyên chuỗi:

- Lab 02: `00_init` → `01` → `02` → `03` → `04_fix_server`
- Lab 03: `00_init` → `01` → `02` → `03_test_attack` → `04_test_defense`
- Lab 04: `00_init` → `01` → `02` → `03` → `04_test_defense` → `99_down`
- Lab 05: `00_init` → `01` → `02` → `03_test_defense` → `99_down`

Minh chứng: `volumes/reports/lab02_verify.log`, `lab03_verify.log`, `lab04_verify.log`, `lab05_verify.log`, `project_summary.md`.

Ánh xạ kỹ thuật: `audit/techniques_map.md`.

---

## 4. Nhánh tuỳ chọn – Hardening Ubuntu (SSH/UFW/…)

Nếu cần thêm phần harden host/container riêng:

```bash
cd /media/sf_.shared/scripts/lab99

bash .lab/00_init.sh
bash .lab/01_baseline_audit.sh
bash .lab/02_assess_surface.sh before
bash .lab/07_validate_defense.sh before
bash .lab/03_harden.sh
bash .lab/04_verify_harden.sh
bash .lab/05_reassess.sh
bash .lab/07_validate_defense.sh after
bash .lab/06_compare_report.sh
bash .lab/99_down.sh
```

---

## Đóng gói nộp

```bash
cd /media/sf_.shared/scripts/lab99/volumes/reports
zip -q ../NhomX_Lab99_BaoCao.zip project_summary.md lab02_verify* lab03_verify* compare_report.md metrics_* validate_* nmap_* 2>/dev/null
```

Kèm báo cáo Word: nêu rõ đã **tái sử dụng** phương pháp Lab 02 & 03, kết quả tấn công trước phòng thủ / sau phòng thủ, và (nếu có) bảng harden Ubuntu.
