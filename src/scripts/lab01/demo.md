# Demo trực tiếp – Bài thực hành số 1: Phân tích kỹ thuật do thám hệ thống

Thực hiện trên **máy Attack** (192.168.117.10), mục tiêu quét là **máy Server** (192.168.117.13).
Card mạng: `enp0s3`. Mỗi bước chỉ gõ **một lệnh hoặc một cụm lệnh**, chạy xong rồi mới sang bước kế tiếp.

```bash
sudo nmap -sV 192.168.100.20
```

---

## 0. Chuẩn bị

### Bước 0.1 – Kiểm tra card mạng

```bash
ip a show enp0s3
```

### Bước 0.2 – Vào group wireshark cho phiên hiện tại

```bash
newgrp wireshark
```

### Bước 0.3 – Tạo thư mục làm việc

```bash
mkdir -p ~/lab01 && cd ~/lab01
```

---

## 1. Kịch bản 1 – ARP Ping Scan (`nmap -sn`)

### Bước 1.1 – Bắt đầu bắt gói (chạy nền)

```bash
sudo ip neigh flush all
dumpcap -i enp0s3 -f "arp or net 192.168.117.0/24" -w task1.pcap -q &
sleep 2
```

### Bước 1.2 – Chạy lệnh quét cần demo

```bash
sudo nmap -sn 192.168.117.0/24
```

**Xuất ra:** danh sách các IP đang hoạt động trong dải 192.168.117.0/24, mỗi dòng dạng
`Nmap scan report for 192.168.117.x` kèm `Host is up`, địa chỉ MAC và tên hãng card mạng.
Dòng cuối `Nmap done: 256 IP addresses (N hosts up) scanned in ...` cho biết tổng số IP đã quét và số host sống.

### Bước 1.3 – Dừng bắt gói

```bash
sleep 2; pkill -INT -x dumpcap; sleep 1; ls -lh task1.pcap
```

### Bước 1.4 – Xem ARP Request quảng bá

```bash
wireshark -r task1.pcap -Y "arp.opcode==1" &
```

**Xuất ra:** danh sách các gói ARP Request, cột **Source** luôn là MAC máy Attack, cột **Destination** luôn là
`Broadcast`, cột **Protocol** là `ARP`, cột **Info** có dạng `Who has 192.168.117.x? Tell 192.168.117.10` với x
tăng dần lần lượt từ 1 đến 254 — thể hiện nmap dò hỏi MAC của từng địa chỉ IP trong dải mạng.

### Bước 1.5 – Xem ARP Reply từ host đang hoạt động

```bash
wireshark -r task1.pcap -Y "arp.opcode==2" &
```

**Xuất ra:** chỉ vài gói (đúng bằng số host đang sống), cột **Source** là MAC của từng host trả lời, cột
**Destination** là MAC máy Attack (không còn Broadcast), cột **Info** dạng
`192.168.117.x is at <MAC>`. Các IP ở đây phải trùng khớp với danh sách "Host is up" ở Bước 1.2.

### Bước 1.6 – Xem nhanh bằng tshark (không cần GUI)

```bash
tshark -r task1.pcap -Y "arp.opcode==2"
```

**Xuất ra:** cùng nội dung như Bước 1.5 nhưng dạng text một dòng mỗi gói, gồm số thứ tự, thời gian, Source,
Destination, Protocol, Length và Info — tiện để chụp màn hình terminal.

### Bước 1.7 – Kiểm tra không có gói TCP/ICMP nào

```bash
tshark -r task1.pcap -Y "tcp || icmp"
```

**Xuất ra:** không có dòng nào (rỗng). Đây là bằng chứng nmap chỉ dùng ARP để dò host, không gửi ping ICMP
hay quét cổng TCP trong kịch bản này.

---

## 2. Kịch bản 2 – TCP SYN Scan (`nmap -sS -F`)

### Bước 2.1 – Bắt đầu bắt gói

```bash
dumpcap -i enp0s3 -f "arp or host 192.168.117.13" -w task2.pcap -q &
sleep 2
```

### Bước 2.2 – Chạy lệnh quét cần demo

```bash
sudo nmap -sS -F 192.168.117.13
```

**Xuất ra:** bảng `PORT STATE SERVICE` liệt kê 100 cổng phổ biến nhất, mỗi dòng là một cổng ở trạng thái
`open`, `closed` hoặc bị gộp vào dòng `Not shown: N closed ports`. Đây là danh sách cổng đang mở trên Server.

### Bước 2.3 – Dừng bắt gói

```bash
sleep 2; pkill -INT -x dumpcap; sleep 1; ls -lh task2.pcap
```

### Bước 2.4 – Xem loạt gói SYN gửi tới nhiều cổng

```bash
wireshark -r task2.pcap -Y "ip.src==192.168.117.10 && tcp.flags.syn==1 && tcp.flags.ack==0" &
```

**Xuất ra:** rất nhiều gói TCP, cột **Source** luôn là 192.168.117.10, cột **Destination** luôn là
192.168.117.13, cột **Info** dạng `<cổng nguồn> → <cổng đích> [SYN] Seq=0 Win=1024 ...` với cổng đích thay
đổi liên tục (22, 80, 443, 3389...) — mỗi dòng là một lần dò một cổng.

### Bước 2.5 – Xem danh sách cổng open (SYN/ACK trả về)

```bash
wireshark -r task2.pcap -Y "tcp.flags.syn==1 && tcp.flags.ack==1" &
```

**Xuất ra:** số dòng ít hơn hẳn Bước 2.4, cột **Source** là 192.168.117.13, cột **Info** dạng
`<cổng> → <cổng nguồn> [SYN, ACK] Seq=0 ...`. Số cổng xuất hiện ở đây phải khớp với các cổng `open` ở Bước 2.2.
Ghi lại một cổng, ví dụ 22, dùng cho bước kế tiếp.

### Bước 2.6 – Xem chuỗi SYN → SYN/ACK → RST trên một cổng cụ thể

```bash
wireshark -r task2.pcap -Y "tcp.port==22" &
```

**Xuất ra:** đúng 3 gói cho cổng đó, theo thứ tự: `[SYN]` từ Attack → `[SYN, ACK]` từ Server → `[RST]` từ
Attack. Không có gói `[ACK]` nào ở giữa, khác với bắt tay 3 bước thông thường — đây chính là đặc trưng của
SYN Scan (half-open).

### Bước 2.7 – Xem các cổng đóng (RST/ACK ngay sau SYN)

```bash
tshark -r task2.pcap -Y "ip.src==192.168.117.13 && tcp.flags.reset==1"
```

**Xuất ra:** mỗi dòng là một gói `[RST, ACK]` từ 192.168.117.13, cột Info ghi rõ cổng đã gửi RST — đây là các
cổng đóng, không nằm trong danh sách `open` ở Bước 2.2.

---

## 3. Kịch bản 3 – TCP ACK Scan (`nmap -sA -F`)

### Bước 3.1 – Bắt đầu bắt gói

```bash
dumpcap -i enp0s3 -f "arp or host 192.168.117.13" -w task3.pcap -q &
sleep 2
```

### Bước 3.2 – Chạy lệnh quét cần demo

```bash
sudo nmap -sA -F 192.168.117.13
```

**Xuất ra:** không có cột STATE là open/closed như hai kịch bản trước, mà ghi `unfiltered` cho các cổng nhận
được phản hồi, hoặc dòng tổng hợp `Not shown: N unfiltered tcp ports (reset)`. ACK Scan chỉ phân biệt được
có firewall chặn hay không, không xác định cổng mở hay đóng.

### Bước 3.3 – Dừng bắt gói

```bash
sleep 2; pkill -INT -x dumpcap; sleep 1; ls -lh task3.pcap
```

### Bước 3.4 – Xem các gói chỉ mang cờ ACK

```bash
wireshark -r task3.pcap -Y "ip.src==192.168.117.10 && tcp.flags==0x010" &
```

**Xuất ra:** nhiều gói từ 192.168.117.10, cột Info dạng `<cổng nguồn> → <cổng đích> [ACK] Seq=0 ...`. Mở một
gói bất kỳ, bung mục **Transmission Control Protocol → Flags** ở khung dưới để thấy chỉ có ô "Acknowledgment"
được tick, không có "Syn" — khác hẳn Bước 2.4.

### Bước 3.5 – Xem gói RST trả lời

```bash
tshark -r task3.pcap -Y "ip.src==192.168.117.13 && tcp.flags.reset==1"
```

**Xuất ra:** mỗi dòng là một gói `[RST]` (không phải `[RST, ACK]`) từ 192.168.117.13 cho từng cổng — việc
nhận được RST (thay vì im lặng hoặc ICMP unreachable) chứng tỏ gói ACK đã tới đích, không bị firewall chặn.

### Bước 3.6 – Kiểm tra không có gói SYN nào

```bash
tshark -r task3.pcap -Y "tcp.flags.syn==1"
```

**Xuất ra:** không có dòng nào (rỗng) — khẳng định toàn bộ file chỉ chứa gói ACK và RST, không có bắt tay
SYN nào như ở Kịch bản 2.

---

## 4. Thu thập thông tin hệ thống (tìm và quét máy chủ email)

### Bước 4.1 – Bắt đầu bắt gói

```bash
dumpcap -i enp0s3 -f "arp or net 192.168.100.0/24" -w task4.pcap -q &
sleep 2
```

### Bước 4.2 – Tìm máy chủ email trong mạng 192.168.100.0/24

```bash
sudo nmap -p 25,110,143,465,587,993,995 --open 192.168.100.0/24
```

**Xuất ra:** chỉ liệt kê các host có ít nhất một trong các cổng mail (25, 110, 143, 465, 587, 993, 995) đang
mở, kèm bảng PORT/STATE/SERVICE cho từng host đó. Ghi lại địa chỉ IP của host này, dùng cho hai bước tiếp theo.

### Bước 4.3 – Xác định hệ điều hành của máy chủ email

```bash
sudo nmap -O 192.168.100.20
```

**Xuất ra:** các dòng `Device type`, `Running` (họ hệ điều hành và dải phiên bản, ví dụ `Linux 4.X|5.X`),
`OS CPE` và `OS details` (chuỗi mô tả cụ thể hơn, ví dụ `Linux 4.15 - 5.19`). Đây là kết quả nmap suy đoán
dựa trên đặc trưng phản hồi TCP/IP, không phải thông tin chính xác tuyệt đối.

### Bước 4.4 – Xác định phiên bản dịch vụ đang chạy

```bash
sudo nmap -sV 192.168.100.20
```

**Xuất ra:** bảng 4 cột `PORT STATE SERVICE VERSION`, cột VERSION ghi tên phần mềm và số phiên bản nếu dò
được (ví dụ `OpenSSH 9.9p1 Ubuntu 3ubuntu3.2`), hoặc chỉ tên dịch vụ nếu không lấy được banner phiên bản.

### Bước 4.5 – Dừng bắt gói

```bash
sleep 2; pkill -INT -x dumpcap; sleep 1; ls -lh task4.pcap
```

### Bước 4.6 – Xem banner SMTP bắt được trên Wireshark

```bash
wireshark -r task4.pcap -Y "smtp" &
```

**Xuất ra:** một gói Protocol = SMTP, cột Info bắt đầu bằng `S: 220 ...` — đây là dòng chào (banner) máy chủ
mail gửi về ngay khi kết nối tới cổng 25, thường chứa tên phần mềm (ví dụ `220 osboxes ESMTP Postfix`), khớp
với dịch vụ SMTP đã thấy ở Bước 4.4.

---

## 5. Đóng gói nộp bài

### Bước 5.1 – Kiểm tra dung lượng từng file (phải dưới 5MB)

```bash
ls -lh ~/lab01/task*.pcap
```

**Xuất ra:** 4 dòng, mỗi dòng gồm quyền file, chủ sở hữu, dung lượng và tên file `task1.pcap` đến `task4.pcap`.

### Bước 5.2 – Nén lại thành file nộp bài

```bash
cd ~/lab01
zip -q HoTenSV_MSSV_Lab01.zip task1.pcap task2.pcap task3.pcap task4.pcap Lab01_HoTenSV_MSSV_BaoCao.docx
```

### Bước 5.3 – Kiểm tra lại nội dung file nén

```bash
unzip -l HoTenSV_MSSV_Lab01.zip
```

**Xuất ra:** danh sách các file bên trong file nén kèm dung lượng từng file và tổng dung lượng — dùng để xác
nhận đã nén đủ 5 file (4 pcap + 1 báo cáo) trước khi nộp.
