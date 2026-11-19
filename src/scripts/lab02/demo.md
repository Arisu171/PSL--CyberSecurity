# HƯỚNG DẪN THỰC HÀNH VÀ DEMO LAB 02 – ARP SPOOFING

## 1. Kết nối SSH từ máy Windows lên Ubuntu Server
```bash
ssh orias@192.168.117.13
```

## 2. Di chuyển vào thư mục bài Lab trên Server
```bash
cd /media/sf_.shared/scripts/lab02
```

## 3. Chạy tự động qua các script trong thư mục `.lab`:
```bash
bash .lab/00_init.sh
bash .lab/01_scenario1.sh
bash .lab/02_scenario2.sh
bash .lab/03_scenario3.sh
bash .lab/04_fix_server.sh
# Kết thúc demo Lab 02, giải phóng subnet:
bash .lab/99_down.sh
```

*(Hoặc chạy trực tiếp từ bất kỳ đâu bằng đường dẫn tuyệt đối):*
```bash
bash /media/sf_.shared/scripts/lab02/.lab/00_init.sh
bash /media/sf_.shared/scripts/lab02/.lab/01_scenario1.sh
bash /media/sf_.shared/scripts/lab02/.lab/02_scenario2.sh
bash /media/sf_.shared/scripts/lab02/.lab/03_scenario3.sh
bash /media/sf_.shared/scripts/lab02/.lab/04_fix_server.sh
bash /media/sf_.shared/scripts/lab02/.lab/99_down.sh
```

---

## GIAI ĐOẠN 0: DỰNG MÔI TRƯỜNG DOCKER

Trước khi chạy các lệnh kiểm tra, bạn cần di chuyển vào thư mục chứa `docker-compose.yml` và khởi động 3 container:

```bash
cd /media/sf_.shared/scripts/lab02
sudo docker compose up -d
```

---

## GIAI ĐOẠN 1: KIỂM TRA THÔNG SỐ BAN ĐẦU CỦA HỆ THỐNG

### Bước 1: Kiểm tra danh sách container đang chạy

```bash
sudo docker ps
```

*(Yêu cầu: Thấy đủ 3 container* `lab02_attacker`*,* `lab02_user`*,* `lab02_server` *ở trạng thái Up).*

*(MAC đổi mỗi lần tạo lại container. Không chép MAC vào lệnh. Khối lệnh nào cần MAC thì đọc lại ngay trong khối đó, vì biến shell không giữ sang khối sau. Nguồn MAC hiện tại là file* `/sys/class/net/eth0/address` *trong từng container. IP không đổi: User* `10.2.6.10`*, Server* `10.2.6.20`*, Attacker* `10.2.6.51`*).*

### Bước 2: Lấy thông số IP và MAC của máy User (Nạn nhân)

```bash
sudo docker exec lab02_user ifconfig eth0
echo "USER_MAC=$(sudo docker exec lab02_user cat /sys/class/net/eth0/address)"
```

*(Dòng* `USER_MAC=` *là MAC đang dùng sau lần khởi động này).*

### Bước 3: Lấy thông số IP và MAC của máy Server (Máy chủ đích)

```bash
sudo docker exec lab02_server ifconfig eth0
echo "SERVER_MAC=$(sudo docker exec lab02_server cat /sys/class/net/eth0/address)"
```

*(Dòng* `SERVER_MAC=` *là MAC thật của Server, dùng để đối chiếu bảng ARP và để gán ARP tĩnh ở bước 26).*

### Bước 4: Lấy thông số IP và MAC của máy Attacker (Kẻ tấn công)

```bash
sudo docker exec lab02_attacker ifconfig eth0
echo "ATTACKER_MAC=$(sudo docker exec lab02_attacker cat /sys/class/net/eth0/address)"
```

*(Dòng* `ATTACKER_MAC=` *là MAC dùng để nhận ra bảng ARP đã bị đầu độc).*

### Bước 5: Ping kiểm tra kết nối ban đầu từ User đến Server

```bash
sudo docker exec lab02_user ping -c 2 10.2.6.20
```

### Bước 6: Kiểm tra bảng ARP cache ban đầu của User

```bash
echo "SERVER_MAC=$(sudo docker exec lab02_server cat /sys/class/net/eth0/address)"
sudo docker exec lab02_user arp -n
```

*(Kết quả: IP* `10.2.6.20` *ánh xạ đúng với* `SERVER_MAC` *vừa in).*

### Bước 7: Kiểm tra bảng ARP cache ban đầu của Server

```bash
echo "USER_MAC=$(sudo docker exec lab02_user cat /sys/class/net/eth0/address)"
sudo docker exec lab02_server arp -n
```

*(Kết quả: IP* `10.2.6.10` *ánh xạ đúng với* `USER_MAC` *vừa in).*

---

## GIAI ĐOẠN 2: KỊCH BẢN 1 - TẤN CÔNG ARP REPLY SPOOFING

### Bước 8: Bật tcpdump bắt gói tin ARP trên User

```bash
sudo docker exec lab02_user rm -f /tmp/scenario1.pcap
sudo docker exec -d lab02_user tcpdump -i eth0 -n -U -w /tmp/scenario1.pcap arp
```

*(Xóa pcap cũ trước khi bắt. tcpdump trong container bỏ quyền root, không ghi đè file lần chạy trước; nếu giữ file cũ thì bước 13 sẽ đọc nhầm gói tin của phiên trước. Cờ* `-U` *ghi từng gói xuống đĩa ngay).*

### Bước 9: Kẻ tấn công chạy script giả mạo ARP Reply

```bash
sudo docker exec lab02_attacker sysctl -w net.ipv4.ip_forward=0
sudo docker exec -d lab02_attacker python3 /attack/scenario1.py
sleep 6
```

*(Lệnh* `sleep 6` *chờ Scapy nạp xong và gửi vài ARP Reply.* `ip_forward=0` *để Attacker không chuyển tiếp ICMP).*

### Bước 10: Dừng script tấn công và tcpdump

```bash
sudo docker exec lab02_attacker pkill -f scenario1.py || true
sudo docker exec lab02_user pkill -INT -f tcpdump || true
sleep 1
```

### Bước 11: Kiểm tra bảng ARP cache của User (Xác nhận bị đầu độc)

```bash
echo "ATTACKER_MAC=$(sudo docker exec lab02_attacker cat /sys/class/net/eth0/address)"
sudo docker exec lab02_user arp -n
```

*(Quan sát: MAC ứng với IP* `10.2.6.20` *trùng* `ATTACKER_MAC` *vừa in).*

### Bước 12: Thử ping từ User tới Server khi đang bị đầu độc

```bash
sudo docker exec lab02_user ping -c 3 -W 1 10.2.6.20
```

*(Kết quả:* `3 packets transmitted, 0 received, 100% packet loss`*. Bảng ARP vẫn trỏ* `10.2.6.20` *tới MAC của Attacker, và Attacker không chuyển tiếp gói tin).*

### Bước 13: Đọc chi tiết gói tin ARP giả mạo bắt được từ pcap

```bash
sudo docker exec lab02_user tcpdump -nn -e -r /tmp/scenario1.pcap arp
```

---

## GIAI ĐOẠN 3: KỊCH BẢN 2 - TẤN CÔNG ARP REQUEST SPOOFING

### Bước 14: Làm sạch ARP cache cũ và ping để khôi phục trạng thái chuẩn

```bash
sudo docker exec lab02_user arp -d 10.2.6.20 2>/dev/null || true; sudo docker exec lab02_user ip neigh flush all; sudo docker exec lab02_user ping -c 1 10.2.6.20
```

### Bước 15: Bật tcpdump bắt gói tin trên User

```bash
sudo docker exec lab02_user rm -f /tmp/scenario2.pcap
sudo docker exec -d lab02_user tcpdump -i eth0 -n -U -w /tmp/scenario2.pcap arp
```

*(Cùng lý do với bước 8: xóa pcap cũ để tcpdump tạo file mới).*

### Bước 16: Kẻ tấn công chạy script giả mạo ARP Request

```bash
sudo docker exec -d lab02_attacker python3 /attack/scenario2.py
sleep 6
```

*(*`sleep 6` *chờ script gửi đủ ARP Request giả mạo).*

### Bước 17: Dừng script kịch bản 2 và tcpdump

```bash
sudo docker exec lab02_attacker pkill -f scenario2.py || true
sudo docker exec lab02_user pkill -INT -f tcpdump || true
sleep 1
```

### Bước 18: Kiểm tra bảng ARP cache của User bị nhiễm độc bởi Request

```bash
echo "ATTACKER_MAC=$(sudo docker exec lab02_attacker cat /sys/class/net/eth0/address)"
sudo docker exec lab02_user arp -n
```

*(Quan sát: MAC ứng với IP* `10.2.6.20` *trùng* `ATTACKER_MAC` *vừa in, dù User chỉ nhận ARP Request quảng bá).*

### Bước 19: Đọc gói tin ARP Request giả mạo từ file pcap

```bash
sudo docker exec lab02_user tcpdump -nn -e -r /tmp/scenario2.pcap arp
```

---

## GIAI ĐOẠN 4: KỊCH BẢN 3 - TẤN CÔNG LEO THANG MITM (SỬA ĐỔI DỮ LIỆU)

### Bước 20: Làm mới lại ARP cache của cả 3 container và thiết lập kết nối ban đầu

```bash
sudo docker exec lab02_user arp -d 10.2.6.20 2>/dev/null || true; sudo docker exec lab02_server arp -d 10.2.6.10 2>/dev/null || true; sudo docker exec lab02_user ping -c 1 10.2.6.20 >/dev/null 2>&1; sudo docker exec lab02_server ping -c 1 10.2.6.10 >/dev/null 2>&1
```

### Bước 21: Kiểm tra truyền tin Netcat bình thường TRƯỚC tấn công

```bash
sudo docker exec lab02_server rm -f /tmp/nc_normal.txt; sudo docker exec -d lab02_server sh -c 'nc -d -lp 10101 > /tmp/nc_normal.txt'; sleep 1; sudo docker exec lab02_user sh -c 'echo "Hello Server from Nguyen Bao Long 223001756" | nc -w 2 10.2.6.20 10101'
```

### Bước 22: Đọc thông điệp Server nhận được trước tấn công

```bash
sudo docker exec lab02_server cat /tmp/nc_normal.txt; sudo docker exec lab02_server pkill -9 nc 2>/dev/null || true
```

*(Kết quả:* `Hello Server from Nguyen Bao Long 223001756` *- Nguyên vẹn).*

### Bước 23: Attacker bật IP Forward và chạy script MITM can thiệp gói tin

```bash
sudo docker exec lab02_attacker sysctl net.ipv4.ip_forward=1; sudo docker exec lab02_attacker iptables -F FORWARD 2>/dev/null || true; sudo docker exec lab02_attacker iptables -A FORWARD -p tcp --dport 10101 -j DROP 2>/dev/null || true; sudo docker exec lab02_attacker iptables -A FORWARD -p tcp --sport 10101 -j DROP 2>/dev/null || true; sudo docker exec -d lab02_attacker python3 /attack/mitm.py
sleep 4
```

*(*`sleep 4` *chờ Attacker đầu độc ARP hai chiều trước khi User gửi dữ liệu).*

### Bước 24: User truyền tin lại trong khi Attacker đang chặn giữa

```bash
sudo docker exec lab02_server rm -f /tmp/nc_mitm.txt; sudo docker exec -d lab02_server sh -c 'nc -d -lp 10101 > /tmp/nc_mitm.txt'; sleep 1; sudo docker exec lab02_user sh -c 'echo "Hello Server from Nguyen Bao Long 223001756" | nc -w 3 10.2.6.20 10101'
```

### Bước 25: Đọc thông điệp Server nhận được sau khi bị MITM can thiệp

```bash
sudo docker exec lab02_server cat /tmp/nc_mitm.txt; sudo docker exec lab02_attacker pkill -f mitm.py || true; sudo docker exec lab02_server pkill -9 nc 2>/dev/null || true; sudo docker exec lab02_attacker iptables -F FORWARD 2>/dev/null || true
```

*(Kết quả:* `XXXXX XXXXXX XXXX XXXXXX XXX XXXX XXXXXXXXX` *- Toàn bộ ký tự chữ cái và số bị script MITM chặn và thay thế).*

*(Lưu ý: Có thể chạy kiểm tra tự động toàn bộ Kịch bản 3 bằng script:* `bash test_mitm.sh`*).*

---

## GIAI ĐOẠN 5: PHÒNG CHỐNG BẰNG ÁNH XẠ ARP TĨNH (STATIC ARP)

### Bước 26: Thiết lập ánh xạ ARP tĩnh cho Server trên máy User

```bash
SERVER_MAC=$(sudo docker exec lab02_server cat /sys/class/net/eth0/address)
echo "Gan ARP tinh 10.2.6.20 -> $SERVER_MAC"
sudo docker exec lab02_user arp -s 10.2.6.20 "$SERVER_MAC"
```

### Bước 27: Kiểm tra cờ CM (Permanent) của ánh xạ tĩnh

```bash
echo "SERVER_MAC=$(sudo docker exec lab02_server cat /sys/class/net/eth0/address)"
sudo docker exec lab02_user arp -n
```

*(Quan sát: MAC của* `10.2.6.20` *trùng* `SERVER_MAC` *vừa in và cột Flags là* `CM`*).*

### Bước 28: Attacker thử tấn công lại bằng scenario1.py

```bash
sudo docker exec -d lab02_attacker python3 /attack/scenario1.py
sleep 6
```

### Bước 29: Dừng script tấn công kiểm tra

```bash
sudo docker exec lab02_attacker pkill -f scenario1.py || true
```

### Bước 30: Xác nhận bảng ARP của User KHÔNG bị thay đổi

```bash
echo "SERVER_MAC=$(sudo docker exec lab02_server cat /sys/class/net/eth0/address)"
sudo docker exec lab02_user arp -n
```

*(Quan sát: MAC của* `10.2.6.20` *vẫn là* `SERVER_MAC` *vừa in, cờ* `CM`*).*

### Bước 31: Kiểm tra kết nối User tới Server vẫn thông suốt

```bash
sudo docker exec lab02_user ping -c 3 -W 1 10.2.6.20
```

*(Kết quả:* `0% packet loss`*, giải pháp phòng chống thành công).*

### Bước 32: Đảo ngược/xóa bản ghi tĩnh để hệ thống trở lại trạng thái động

```bash
sudo docker exec lab02_user arp -d 10.2.6.20
```

*(Quan sát: Xóa bản ghi tĩnh để tránh ảnh hưởng đến các thử nghiệm mạng khác sau này).*

---

## GIAI ĐOẠN 6: DỌN DẸP MÔI TRƯỜNG KHI KẾT THÚC DEMO

Khi buổi demo kết thúc, bạn có thể tắt các container để giải phóng tài nguyên:

```bash
cd ~/it4263lab/lab02
sudo docker compose down
```

*(Hoặc* `sudo docker-compose down`*).*
