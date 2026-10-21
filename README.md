# Cybersecurity Labs Automation Framework

Hệ thống tự động hóa thực nghiệm, mô phỏng minh chứng và biên dịch báo cáo các bài thực hành môn **An toàn & Bảo mật Thông tin / An ninh Mạng**.

---

## 📌 Tổng quan dự án

Dự án này cung cấp một bộ khung tự động hóa tổng quát (**Generic Engine Architecture**) được thiết kế theo nguyên lý tách biệt hoàn toàn giữa **mã nguồn thực thi** và **dữ liệu kịch bản bài lab (Data-driven)**.

Hệ thống cho phép:

1. **Thiết lập môi trường từ xa:** Cấu hình tự động SSH keyless và phân quyền `sudo NOPASSWD` trên máy ảo thí nghiệm.
2. **Thực thi kịch bản tự động:** Điều khiển máy ảo qua SSH để chạy tuần tự các lệnh thực nghiệm (Docker, Nmap, Scapy, Tcpdump,...), hỗ trợ chế độ **Dry-run**.
3. **Mô phỏng minh chứng chất lượng cao:** Tự động sinh hình ảnh chụp màn hình cực kỳ chân thực (Ubuntu GNOME Terminal, giao diện phân tích gói tin Wireshark với bộ lọc chuẩn, sơ đồ mạng Topology).
4. **Biên dịch báo cáo học thuật:** Tự động tổng hợp dữ liệu, chèn ảnh minh chứng và định dạng bảng biểu để xuất ra file Microsoft Word (`.docx`) hoàn chỉnh theo đúng tiêu chuẩn báo cáo.

---

## 📂 Cấu trúc thư mục

```text
PSL--CyberSecurity/
├── bin/                                # Thư mục chứa các tệp đầu ra (Artifacts)
│   ├── docs/                           # Báo cáo Word hoàn chỉnh (.docx)
│   │   ├── NguyenBaoLong_223001756_Lab01.docx
│   │   └── NguyenBaoLong_223001756_Lab02.docx
│   ├── imgs/                           # Hình ảnh minh chứng đã xuất bản
│   │   ├── lab01/                      # 17 ảnh Terminal & Wireshark của Lab 01
│   │   └── lab02/                      # 15 ảnh Topology, Terminal & Wireshark của Lab 02
│   └── results.json                    # Nhật ký kết quả lệnh thực thi qua SSH
├── doc/                                # Tài liệu hướng dẫn gốc của môn học
│   ├── Lab01_HD.pdf                    # Hướng dẫn Lab 01: Thăm dò mạng
│   └── Lab02_HD.pdf                    # Hướng dẫn Lab 02: Tấn công ARP Cache Poisoning
├── src/                                # Mã nguồn dự án
│   ├── remote/                         # Script tiện ích truy cập nhanh SSH / Docker
│   │   ├── remote.ps1                  # Menu điều khiển nhanh cho Windows PowerShell
│   │   └── remote.sh                   # Script Bash tiện ích cho Linux/macOS
│   └── scripts/                        # Bộ công cụ thực thi tổng quát
│       ├── setup.py                    # Cấu hình SSH và sudo NOPASSWD trên máy ảo
│       ├── runall.py                   # Generic Runner: Chạy lệnh từ scripts.json qua SSH
│       ├── genimgs.py                  # Generic Image Generator: Sinh ảnh minh chứng
│       ├── gendocs.py                  # Generic Docx Generator: Biên dịch báo cáo Word
│       ├── lab01/                      # Dữ liệu kịch bản bài Lab 01
│       │   ├── scripts.json            # Danh mục lệnh Nmap & bắt gói tin PCAP
│       │   ├── images.json             # Đặc tả 17 ảnh Terminal & Wireshark
│       │   └── docxs.json              # Nội dung phân tích kỹ thuật & bảng CVEs
│       └── lab02/                      # Dữ liệu kịch bản bài Lab 02
│           ├── attack/                 # Scripts Scapy tấn công (scenario1, scenario2, mitm)
│           ├── image/                  # Dockerfile build môi trường User/Server/Attacker
│           ├── docker-compose.yml      # Cấu hình mạng bridge ảo 10.2.6.0/24
│           ├── setup_vm.sh             # Script cài Docker và dựng container
│           ├── test_mitm.sh            # Script kiểm thử tấn công can thiệp dữ liệu
│           ├── scripts.json            # 27 bước kịch bản tấn công & phòng thủ
│           ├── images.json             # Đặc tả 15 ảnh sơ đồ mạng, Terminal & Wireshark
│           └── docxs.json              # Nội dung báo cáo Lab 02 hoàn chỉnh
├── .gitignore
└── README.md
```

---

## 🛠️ Yêu cầu môi trường & Cài đặt

### 1. Môi trường yêu cầu

* **Hệ điều hành:** Windows 10/11, Linux (Ubuntu/Debian) hoặc macOS.
* **Python:** Phiên bản `Python 3.10+`.
* **Phông chữ hệ thống:** Đã cài sẵn font `Consolas` (mặc định trên Windows).

### 2. Cài đặt thư viện Python phụ thuộc

Chỉ cần cài đặt 2 thư viện hỗ trợ xử lý ảnh và biên tập Word:

```bash
pip install python-docx pillow
```

---

## 🚀 Hướng dẫn sử dụng bộ công cụ

Tất cả các công cụ trong `src/scripts/` đều nhận tham số `--lab <tên_lab>` (mặc định: `lab02`). Khi cần chạy bài nào, chỉ cần truyền tên thư mục tương ứng (`lab01` hoặc `lab02`).

### 1. Kiểm tra kịch bản lệnh (`runall.py`)

Chế độ **Dry-run** cho phép kiểm tra toàn bộ chuỗi lệnh mà không cần kết nối máy ảo:

```bash
# Kiểm tra kịch bản Lab 01
python src/scripts/runall.py --lab lab01 --dry-run

# Kiểm tra kịch bản Lab 02
python src/scripts/runall.py --lab lab02 --dry-run
```

Khi chạy thực tế trên máy ảo:

```bash
python src/scripts/runall.py --lab lab02 --host 192.168.117.13 --user orias
```

---

### 2. Tự động sinh hình ảnh minh chứng (`genimgs.py`)

Script sẽ đọc cấu hình từ `src/scripts/{lab}/images.json`, tự động tính toán bố cục, độ dài bộ lọc Wireshark, vẽ thanh trạng thái và xuất vào `bin/imgs/{lab}/`:

```bash
# Sinh toàn bộ 17 ảnh minh chứng chuẩn cho Lab 01
python src/scripts/genimgs.py --lab lab01

# Sinh toàn bộ 15 ảnh minh chứng chuẩn cho Lab 02
python src/scripts/genimgs.py --lab lab02
```

---

### 3. Tự động biên dịch file Báo cáo Word (`gendocs.py`)

Script đọc `src/scripts/{lab}/docxs.json`, thiết lập lề học thuật (0.8 inch), định dạng tiêu đề, danh sách, khối lệnh, bảng màu chuyên nghiệp, tự động định vị và chèn ảnh minh chứng từ `bin/imgs/{lab}/`:

```bash
# Biên dịch file: bin/docs/NguyenBaoLong_223001756_Lab01.docx
python src/scripts/gendocs.py --lab lab01

# Biên dịch file: bin/docs/NguyenBaoLong_223001756_Lab02.docx
python src/scripts/gendocs.py --lab lab02
```

---

### 4. Thiết lập máy ảo tự động (`setup.py`)

Cấu hình SSH Public Key và thiết lập phân quyền `sudo NOPASSWD` trên máy ảo Ubuntu để cho phép chạy lệnh không bị chặn mật khẩu:

```bash
python src/scripts/setup.py --host 192.168.117.13 --user orias
```

---

## 📑 Danh mục các bài Lab đã triển khai

### [Lab 01: Phân tích một số kỹ thuật thăm dò mạng và quét cổng Nmap](file:///e:/Data/Devdata/Educations/PSL--CyberSecurity/src/scripts/lab01/)

* **Kịch bản 1 (ARP Ping Scan):** `sudo nmap -sn 192.168.117.0/24` — Phân tích các gói ARP Request broadcast (`arp.opcode == 1`), ARP Reply (`arp.opcode == 2`) và minh chứng không có gói TCP/ICMP trên mạng nội bộ LAN.
* **Kịch bản 2 (TCP SYN Scan):** `sudo nmap -sS -F 192.168.117.13` — Phân tích cơ chế quét nửa mở (Half-open), chuỗi SYN → SYN/ACK → RST không hoàn tất bắt tay 3 bước, phản hồi RST/ACK từ cổng đóng.
* **Kịch bản 3 (TCP ACK Scan):** `sudo nmap -sA -F 192.168.117.13` — Kỹ thuật kiểm tra Firewall/Lọc gói tin bằng cờ ACK mồ côi (`tcp.flags == 0x010`) và nhận phản hồi RST từ cổng `unfiltered`.
* **Kịch bản 4 (Thu thập thông tin hệ thống & Dịch vụ):**
  * Quét tìm máy chủ Mail: `sudo nmap -p 25,110,143,465,587,993,995 --open 192.168.100.0/24`.
  * Nhận diện hệ điều hành: `sudo nmap -O 192.168.100.20`.
  * Quét phiên bản dịch vụ & Banner: `sudo nmap -sV 192.168.100.20` và phân tích gói tin SMTP banner của Postfix trên Wireshark.
  * Bảng tổng hợp các lỗ hổng bảo mật đã công bố (CVE-2025-26466, CVE-2025-26465, CVE-2023-51764, CVE-2024-23184, CVE-2024-23185).

### [Lab 02: Tấn công và phòng chống ARP Cache Poisoning trong mạng LAN](file:///e:/Data/Devdata/Educations/PSL--CyberSecurity/src/scripts/lab02/)

* **Mô hình thực hành:** Dựng mạng ảo hóa 3 Docker containers (`User`, `Attacker`, `Server`) kết nối cùng subnet `10.2.6.0/24` thông qua Docker Compose.
* **Kịch bản 1 (ARP Reply Spoofing):** Attacker liên tục gửi gói tin ARP Reply giả mạo để đầu độc bảng ánh xạ IP-MAC của User, kiểm tra chuyển hướng lưu lượng Ping và Packet Loss.
* **Kịch bản 2 (ARP Request Spoofing):** Đầu độc bảng ARP cache ngay cả khi máy nạn nhân chưa hề có mục tương ứng, khai thác hành vi cập nhật tự động của nhân Linux khi nhận ARP Request.
* **Kịch bản 3 (Man-In-The-Middle - MITM can thiệp dữ liệu):** Bật `ip_forward`, giả mạo hai chiều, can thiệp luồng truyền tin Netcat (Port 10101) để thay thế nội dung thông điệp mà các bên không phát hiện.
* **Giải pháp phòng chống:** Cấu hình ánh xạ ARP tĩnh (`arp -s`) với cờ `CM (Permanent)` và chứng minh tính kháng đầu độc trước kịch bản tấn công.

---

## 💡 Hướng dẫn mở rộng bài Lab mới (Ví dụ: Lab 03)

Nhờ kiến trúc tách rời dữ liệu, để bổ sung một bài lab mới bạn không cần viết thêm mã nguồn Python, chỉ cần:

1. Tạo thư mục `src/scripts/lab03/`.
2. Tạo 3 file cấu hình:
   * `scripts.json`: Chứa các lệnh cần thực thi trên máy ảo.
   * `images.json`: Khai báo nội dung Terminal, Wireshark hoặc Topology.
   * `docxs.json`: Định nghĩa cấu trúc nội dung báo cáo Word.
3. Chạy lệnh sinh tự động:
   ```bash
   python src/scripts/genimgs.py --lab lab03
   python src/scripts/gendocs.py --lab lab03
   ```

Toàn bộ hình ảnh sẽ được lưu tại `bin/imgs/lab03/` và báo cáo Word sẽ được tạo tại `bin/docs/`.

---

## 📜 Bản quyền

Dự án được xây dựng phục vụ học tập, nghiên cứu và thực hành bảo mật thông tin.
Mọi hình thức khai thác cho mục đích tấn công vào hệ thống mạng thực tế chưa được cấp phép đều vi phạm pháp luật.
