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

| Lab | Container | Việc |
|-----|-----------|------|
| 02 | `lab02_user`, `lab02_server`, `lab02_attacker` | ARP poison → MITM → ARP tĩnh |
| 03 | user / attacker / local-dns / attacker-ns | Kaminsky → SPR |
| 04 | victim / attacker / user / dns | DoS (ICMP/SYN Flood, DNS Amp) → SYN Cookies & iptables |
| 05 | webserver / attacker / user | SQL Injection (SELECT/INSERT) → PDO Prepared Statements |

Lab99 harden (`lab99_target` + `lab99_assessor` trên `10.2.99.0/24`) là **nhánh tuỳ chọn** (hardening host), không thay thế Lab 02-05.

---

## Cách chạy chính (áp dụng kiểm chứng phòng thủ Lab 02 - Lab 05)

```bash
# 1) Chung minh ARP/MITM + ARP tinh (dung script Lab 02)
bash /media/sf_.shared/scripts/lab99/.lab/08_apply_lab02.sh

# 2) Chung minh Kaminsky + SPR (dung script Lab 03)
bash /media/sf_.shared/scripts/lab99/.lab/09_apply_lab03.sh

# 3) Chung minh DoS Defense + SYN Cookies / Rate Limit (dung script Lab 04)
bash /media/sf_.shared/scripts/lab99/.lab/11_apply_lab04.sh

# 4) Chung minh SQLi Defense + Prepared Statements (dung script Lab 05)
bash /media/sf_.shared/scripts/lab99/.lab/12_apply_lab05.sh

# 5) Tong hop bao cao toan dien
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

## Nhánh tuỳ chọn – Hardening Ubuntu (SSH/UFW/…)

Nếu cần thêm phần harden host/container riêng:

```bash
bash /media/sf_.shared/scripts/lab99/.lab/00_init.sh
bash /media/sf_.shared/scripts/lab99/.lab/01_baseline_audit.sh
bash /media/sf_.shared/scripts/lab99/.lab/02_assess_surface.sh before
bash /media/sf_.shared/scripts/lab99/.lab/07_validate_defense.sh before
bash /media/sf_.shared/scripts/lab99/.lab/03_harden.sh
bash /media/sf_.shared/scripts/lab99/.lab/04_verify_harden.sh
bash /media/sf_.shared/scripts/lab99/.lab/05_reassess.sh
bash /media/sf_.shared/scripts/lab99/.lab/07_validate_defense.sh after
bash /media/sf_.shared/scripts/lab99/.lab/06_compare_report.sh
bash /media/sf_.shared/scripts/lab99/.lab/99_down.sh
```

---

## Đóng gói nộp

```bash
cd /media/sf_.shared/scripts/lab99/volumes/reports
zip -q ../NhomX_Lab99_BaoCao.zip project_summary.md lab02_verify* lab03_verify* compare_report.md metrics_* validate_* nmap_* 2>/dev/null
```

Kèm báo cáo Word: nêu rõ đã **tái sử dụng** phương pháp Lab 02 & 03, kết quả tấn công trước phòng thủ / sau phòng thủ, và (nếu có) bảng harden Ubuntu.
