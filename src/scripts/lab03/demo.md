# HƯỚNG DẪN DEMO LAB 03: DNS CACHE POISONING (KAMINSKY ATTACK)

- Máy Host (Server VM): 192.168.117.13
- Attacker Container: 10.2.6.1
- User Container: 10.2.6.5
- Local DNS Server Container: 10.2.6.53
- Attacker Nameserver Container: 10.2.6.153

---

## Chuẩn bị hệ thống

### 1. Trên máy Host (Server VM)
```bash
sudo ip route del default via 192.168.117.2 dev enp0s3 2>/dev/null || true
cd ~/lab03
docker-compose down 2>/dev/null || true
docker-compose up -d
docker ps
```

---

## 4.1. Triển khai hệ thống

### 1. Kiểm tra kết nối mạng giữa các container
```bash
docker exec user-10.2.6.5 ping -c 2 10.2.6.53
docker exec user-10.2.6.5 ping -c 2 10.2.6.153
docker exec user-10.2.6.5 ping -c 2 10.2.6.1
```

### 2. Bắt lưu lượng mạng trên card mạng ảo của Docker (trên máy Host)
```bash
BR_IF=$(docker network inspect seed-net -f '{{.Id}}' | head -c 12 | awk '{print "br-"$1}')
echo "Bridge interface: $BR_IF"
sudo dumpcap -i $BR_IF -w /tmp/task1_prep.pcap -q > /dev/null 2>&1 &
```

### 3. Kiểm tra dịch vụ DNS từ máy User
```bash
docker exec user-10.2.6.5 dig ns.attacker32.com
docker exec user-10.2.6.5 dig www.example.com
docker exec user-10.2.6.5 dig @ns.attacker32.com www.example.com
```

### 4. Dừng bắt gói tin phần chuẩn bị
```bash
sudo pkill -INT -x dumpcap 2>/dev/null || true
sudo chown $USER:$USER /tmp/task1_prep.pcap 2>/dev/null || true
```

---

## 4.2. Tạo thông điệp DNS Query truy vấn

### 1. Sinh file binary truy vấn DNS trên máy Attacker
```bash
docker exec attacker-10.2.6.1 bash -c "cd /attack && python3 gen_query.py"
ls -lh ~/lab03/attack/ip_req.bin
```

---

## 4.3. Tạo thông điệp DNS Response giả mạo

### 1. Sinh file binary phản hồi DNS giả mạo trên máy Attacker
```bash
docker exec attacker-10.2.6.1 bash -c "cd /attack && python3 gen_response.py 108.162.192.162"
ls -lh ~/lab03/attack/ip_resp.bin
```

---

## 4.4. Thực hiện tấn công DNS Cache Poisoning

### 1. Biên dịch mã nguồn tấn công trên máy Host
```bash
cd ~/lab03/attack
gcc -O2 -static attack.c -o attack
chmod +x attack
```

### 2. Xóa cache trên Local DNS Server trước khi tấn công
```bash
docker exec local-dns-server-10.2.6.53 rndc flush
```

### 3. Bắt gói tin trên máy Attacker và Local DNS Server
```bash
docker exec attacker-10.2.6.1 bash -c "tcpdump -i eth0 -n -w /attack/attacker.pcap > /dev/null 2>&1 &"
docker exec local-dns-server-10.2.6.53 bash -c "tcpdump -i eth0 -n -w /var/cache/bind/local_dns_server.pcap > /dev/null 2>&1 &"
```

### 4. Kích hoạt tấn công trên máy Attacker
```bash
docker exec attacker-10.2.6.1 bash -c "cd /attack && ./attack"
```
*(Chờ chương trình chạy khoảng 10-20 giây để bắn các đợt truy vấn và phản hồi giả mạo)*

### 5. Kiểm tra kết quả từ máy User
```bash
docker exec user-10.2.6.5 dig www.example.com
docker exec user-10.2.6.5 dig @ns.attacker32.com www.example.com
```

### 6. Trích xuất nội dung bộ đệm dịch vụ trên Local DNS Server
```bash
docker exec local-dns-server-10.2.6.53 rndc dumpdb -cache
docker exec local-dns-server-10.2.6.53 grep -A 4 -B 1 "attacker32.com" /var/cache/bind/dump.db
```

### 7. Dừng tấn công và thu thập file pcap
```bash
docker exec attacker-10.2.6.1 pkill -9 -f attack 2>/dev/null || true
docker exec attacker-10.2.6.1 pkill -INT -x tcpdump 2>/dev/null || true
docker exec local-dns-server-10.2.6.53 pkill -INT -x tcpdump 2>/dev/null || true
docker cp local-dns-server-10.2.6.53:/var/cache/bind/local_dns_server.pcap ~/lab03/
cp ~/lab03/attack/attacker.pcap ~/lab03/
ls -lh ~/lab03/*.pcap
```

---

## 4.5. Phòng chống tấn công (Randomize Source Port)

### 1. Cấu hình Local DNS Server ngẫu nhiên hóa cổng gửi truy vấn
```bash
docker exec local-dns-server-10.2.6.53 sed -i '/query-source port 44444;/d' /etc/bind/named.conf.options
docker restart local-dns-server-10.2.6.53
```

### 2. Xóa sạch cache và kiểm tra lại
```bash
docker exec local-dns-server-10.2.6.53 rndc flush
docker exec user-10.2.6.5 dig www.example.com
```

---

## Đóng gói bài nộp

### 1. Nén file kết quả theo định dạng nhóm
```bash
cd ~/lab03
zip -q Nhom6_Lab03_BaoCao.zip attacker.pcap local_dns_server.pcap
ls -lh Nhom6_Lab03_BaoCao.zip
```

