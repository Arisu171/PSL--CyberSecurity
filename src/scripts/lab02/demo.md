# HƯỚNG DẪN DEMO

---

## GIAI ĐOẠN 0: DỰNG MÔI TRƯỜNG DOCKER

Trước khi chạy các lệnh kiểm tra, bạn cần di chuyển vào thư mục chứa `docker-compose.yml` và khởi động 3 container:

```bash
cd ~/it4263lab/lab02
sudo docker compose up -d
# cd /media/sf_.shared/scripts/lab02
```

---

## GIAI ĐOẠN 1: KIỂM TRA THÔNG SỐ BAN ĐẦU CỦA HỆ THỐNG

### Bước 1: Kiểm tra danh sách container đang chạy

```bash
sudo docker ps
```

*(Yêu cầu: Thấy đủ 3 container `lab02_attacker`, `lab02_user`, `lab02_server` ở trạng thái Up).*

### Bước 2: Lấy thông số IP và MAC của máy User (Nạn nhân)

```bash
sudo docker exec lab02_user ifconfig eth0
```

*(Ghi nhận: IP `10.2.6.10` và địa chỉ MAC của User).*

### Bước 3: Lấy thông số IP và MAC của máy Server (Máy chủ đích)

```bash
sudo docker exec lab02_server ifconfig eth0
```

*(Ghi nhận: IP `10.2.6.20` và địa chỉ MAC thật của Server).*

### Bước 4: Lấy thông số IP và MAC của máy Attacker (Kẻ tấn công)

```bash
sudo docker exec lab02_attacker ifconfig eth0
```

*(Ghi nhận: IP `10.2.6.51` và địa chỉ MAC của Attacker).*

### Bước 5: Ping kiểm tra kết nối ban đầu từ User đến Server

```bash
sudo docker exec lab02_user ping -c 2 10.2.6.20
```

### Bước 6: Kiểm tra bảng ARP cache ban đầu của User

```bash
sudo docker exec lab02_user arp -n
```

*(Kết quả: IP `10.2.6.20` ánh xạ đúng với MAC thật của Server).*

### Bước 7: Kiểm tra bảng ARP cache ban đầu của Server

```bash
sudo docker exec lab02_server arp -n
```

*(Kết quả: IP `10.2.6.10` ánh xạ đúng với MAC thật của User).*

---

## GIAI ĐOẠN 2: KỊCH BẢN 1 - TẤN CÔNG ARP REPLY SPOOFING

### Bước 8: Bật tcpdump bắt gói tin ARP trên User

```bash
sudo docker exec -d lab02_user tcpdump -i eth0 -n -w /tmp/scenario1.pcap arp
```

### Bước 9: Kẻ tấn công chạy script giả mạo ARP Reply

```bash
sudo docker exec -d lab02_attacker python3 /attack/scenario1.py
```

*(Đợi 3 - 5 giây để script gửi các gói tin ARP Reply giả mạo).*

### Bước 10: Dừng script tấn công và tcpdump

```bash
sudo docker exec lab02_attacker pkill -f scenario1.py || true; sudo docker exec lab02_user pkill -f tcpdump || true
```

### Bước 11: Kiểm tra bảng ARP cache của User (Xác nhận bị đầu độc)

```bash
sudo docker exec lab02_user arp -n
```

*(Quan sát: Địa chỉ MAC ứng với IP `10.2.6.20` đã bị đổi thành MAC của Attacker).*

### Bước 12: Thử ping từ User tới Server khi đang bị đầu độc

```bash
sudo docker exec lab02_user ping -c 3 10.2.6.20
```

*(Quan sát: Gói tin ICMP bị gửi tới Attacker thay vì Server, gây packet loss hoặc redirect).*

### Bước 13: Đọc chi tiết gói tin ARP giả mạo bắt được từ pcap

```bash
sudo docker exec lab02_user tcpdump -nn -e -r /tmp/scenario1.pcap arp
```

---

## GIAI ĐOẠN 3: KỊCH BẢN 2 - TẤN CÔNG ARP REQUEST SPOOFING

### Bước 14: Làm sạch ARP cache cũ và ping để khôi phục trạng thái chuẩn

```bash
sudo docker exec lab02_user ip neigh flush all; sudo docker exec lab02_user ping -c 1 10.2.6.20
```

### Bước 15: Bật tcpdump bắt gói tin trên User

```bash
sudo docker exec -d lab02_user tcpdump -i eth0 -n -w /tmp/scenario2.pcap arp
```

### Bước 16: Kẻ tấn công chạy script giả mạo ARP Request

```bash
sudo docker exec -d lab02_attacker python3 /attack/scenario2.py
```

*(Đợi 3 - 5 giây).*

### Bước 17: Dừng script kịch bản 2 và tcpdump

```bash
sudo docker exec lab02_attacker pkill -f scenario2.py || true; sudo docker exec lab02_user pkill -f tcpdump || true
```

### Bước 18: Kiểm tra bảng ARP cache của User bị nhiễm độc bởi Request

```bash
sudo docker exec lab02_user arp -n
```

*(Quan sát: Bảng ARP của User bị cập nhật MAC của Attacker ngay cả khi User chỉ nhận ARP Request quảng bá).*

### Bước 19: Đọc gói tin ARP Request giả mạo từ file pcap

```bash
sudo docker exec lab02_user tcpdump -nn -e -r /tmp/scenario2.pcap arp
```

---

## GIAI ĐOẠN 4: KỊCH BẢN 3 - TẤN CÔNG LEO THANG MITM (SỬA ĐỔI DỮ LIỆU)

### Bước 20: Làm mới lại ARP cache của cả 3 container

```bash
sudo docker exec lab02_user ip neigh flush all; sudo docker exec lab02_server ip neigh flush all; sudo docker exec lab02_attacker ip neigh flush all
```

### Bước 21: Kiểm tra truyền tin Netcat bình thường TRƯỚC tấn công

```bash
sudo docker exec -d lab02_server sh -c 'nc -lp 10101 > /tmp/nc_normal.txt'; sleep 1; sudo docker exec lab02_user sh -c 'echo "Hello Server from Nguyen Bao Long 223001756" | nc -w 2 10.2.6.20 10101'
```

### Bước 22: Đọc thông điệp Server nhận được trước tấn công

```bash
sudo docker exec lab02_server cat /tmp/nc_normal.txt
```

*(Kết quả: `Hello Server from Nguyen Bao Long 223001756` - Nguyên vẹn).*

### Bước 23: Attacker bật IP Forward và chạy script MITM can thiệp gói tin

```bash
sudo docker exec lab02_attacker sysctl net.ipv4.ip_forward=1; sudo docker exec -d lab02_attacker python3 /attack/mitm.py
```

*(Đợi 2 - 3 giây để Attacker đầu độc hai chiều User và Server).*

### Bước 24: User truyền tin lại trong khi Attacker đang chặn giữa

```bash
sudo docker exec -d lab02_server sh -c 'nc -lp 10101 > /tmp/nc_mitm.txt'; sleep 1; sudo docker exec lab02_user sh -c 'echo "Hello Server from Nguyen Bao Long 223001756" | nc -w 3 10.2.6.20 10101'
```

### Bước 25: Đọc thông điệp Server nhận được sau khi bị MITM can thiệp

```bash
sudo docker exec lab02_server cat /tmp/nc_mitm.txt; sudo docker exec lab02_attacker pkill -f mitm.py || true
```

*(Kết quả: Nội dung thông điệp đã bị script MITM can thiệp/thay thế trên đường truyền).*

---

## GIAI ĐOẠN 5: PHÒNG CHỐNG BẰNG ÁNH XẠ ARP TĨNH (STATIC ARP)

### Bước 26: Thiết lập ánh xạ ARP tĩnh cho Server trên máy User

*(Lưu ý: Thay `9e:21:00:d4:d0:ed` bằng địa chỉ MAC thật của Server thu được ở Bước 3 nếu khác)*

```bash
sudo docker exec lab02_user arp -s 10.2.6.20 9e:21:00:d4:d0:ed
```

### Bước 27: Kiểm tra cờ CM (Permanent) của ánh xạ tĩnh

```bash
sudo docker exec lab02_user arp -n
```

*(Quan sát: Cột Flags hiển thị `CM`, chứng minh đây là bản ghi tĩnh không thể bị ghi đè tự động).*

### Bước 28: Attacker thử tấn công lại bằng scenario1.py

```bash
sudo docker exec -d lab02_attacker python3 /attack/scenario1.py
```

*(Đợi 5 giây).*

### Bước 29: Dừng script tấn công kiểm tra

```bash
sudo docker exec lab02_attacker pkill -f scenario1.py || true
```

### Bước 30: Xác nhận bảng ARP của User KHÔNG bị thay đổi

```bash
sudo docker exec lab02_user arp -n
```

*(Quan sát: Địa chỉ MAC của `10.2.6.20` vẫn giữ nguyên MAC thật của Server với cờ `CM`).*

### Bước 31: Kiểm tra kết nối User tới Server vẫn thông suốt

```bash
sudo docker exec lab02_user ping -c 3 10.2.6.20
```

*(Kết quả: 0% packet loss, giải pháp phòng chống thành công).*

---

## GIAI ĐOẠN 6: DỌN DẸP MÔI TRƯỜNG KHI KẾT THÚC DEMO

Khi buổi demo kết thúc, bạn có thể tắt các container để giải phóng tài nguyên:

```bash
cd ~/it4263lab/lab02
sudo docker compose down
```

*(Hoặc `sudo docker-compose down`).*
