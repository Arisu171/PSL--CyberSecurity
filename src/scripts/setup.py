#!/usr/bin/env python3
"""
Script thiết lập quyền Sudo không cần mật khẩu (NOPASSWD) và phân quyền nhóm trên máy ảo Linux.
Hỗ trợ khai báo biến mặc định ở đầu file hoặc truyền tham số qua dòng lệnh (CLI arguments).

Cách sử dụng:
1. Chạy với cấu hình mặc định:
   python setup.py

2. Chạy với tham số tùy chỉnh:
   python setup.py --host 192.168.117.13 --user orias --password orias --port 22 --groups vboxsf docker
"""

import subprocess
import argparse
import sys

# ==================== CẤU HÌNH MẶC ĐỊNH ====================
CONFIG = {
    "host": "192.168.117.13",               # Địa chỉ IP của máy ảo
    "user": "orias",                        # Tên người dùng cần cấp quyền
    "password": "orias",                    # Mật khẩu hiện tại của user (dùng cho lệnh sudo -S)
    "port": 22,                             # Cổng SSH
    "groups": ["vboxsf", "docker"],         # Danh sách các nhóm cần gán thêm cho user
    "key_file": None,                       # Đường dẫn file SSH key riêng (None = dùng mặc định ~/.ssh)
    "sudoers_file": None                    # Tên file trong /etc/sudoers.d/ (None = trùng tên user)
}
# ==========================================================

def parse_arguments():
    parser = argparse.ArgumentParser(description="Thiết lập quyền sudo NOPASSWD và nhóm người dùng từ xa qua SSH.")
    parser.add_argument("--host", "-H", default=CONFIG["host"], help="Địa chỉ IP của máy chủ/máy ảo")
    parser.add_argument("--user", "-u", default=CONFIG["user"], help="Tên người dùng trên máy ảo")
    parser.add_argument("--password", "-p", default=CONFIG["password"], help="Mật khẩu của người dùng")
    parser.add_argument("--port", "-P", type=int, default=CONFIG["port"], help="Cổng kết nối SSH (mặc định 22)")
    parser.add_argument("--groups", "-g", nargs="+", default=CONFIG["groups"], help="Danh sách nhóm cần thêm (vd: vboxsf docker)")
    parser.add_argument("--key", "-i", default=CONFIG["key_file"], help="Đường dẫn khóa SSH IdentityFile (nếu có)")
    parser.add_argument("--sudoers-file", default=CONFIG["sudoers_file"], help="Tên file cấu hình trong /etc/sudoers.d/")
    return parser.parse_args()

def execute_ssh(host, user, port, cmd_str, key_file=None):
    ssh_cmd = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-p", str(port)]
    if key_file:
        ssh_cmd.extend(["-i", key_file])
    ssh_cmd.append(f"{user}@{host}")
    ssh_cmd.append(cmd_str)
    
    return subprocess.run(ssh_cmd, capture_output=True, text=True)

def main():
    args = parse_arguments()
    
    host = args.host
    user = args.user
    password = args.password
    port = args.port
    groups_list = args.groups
    key_file = args.key
    sudoers_name = args.sudoers_file or user
    groups_str = ",".join(groups_list)

    print("==================================================")
    print("      THIẾT LẬP QUYỀN SUDO & USER TRÊN MÁY ẢO     ")
    print("==================================================")
    print(f"[*] Target Host    : {user}@{host}:{port}")
    print(f"[*] Groups to add  : {groups_str}")
    print(f"[*] Sudoers Config : /etc/sudoers.d/{sudoers_name}")
    print("--------------------------------------------------")

    # Script shell thực thi trên máy ảo
    remote_script = f"""
echo '{password}' | sudo -S bash -c '
# 1. Ghi cau hinh NOPASSWD vao /etc/sudoers.d/
echo "{user} ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/{sudoers_name}
chmod 0440 /etc/sudoers.d/{sudoers_name}

# 2. Them user vao cac nhom duoc chi dinh (tao nhom neu chua co)
for grp in {" ".join(groups_list)}; do
    if ! getent group "$grp" >/dev/null 2>&1; then
        groupadd "$grp" 2>/dev/null || true
    fi
    usermod -aG "$grp" {user} 2>/dev/null || true
done
'
"""

    print("[*] Đang gửi lệnh thiết lập qua SSH...")
    res = execute_ssh(host, user, port, remote_script, key_file)
    
    if res.returncode != 0:
        print(f"[!] Lỗi khi thực thi: {res.stderr.strip()}")
        sys.exit(1)

    # Kiểm tra lại quyền sudo không mật khẩu
    check_res = execute_ssh(host, user, port, "sudo whoami", key_file)
    if check_res.stdout.strip() == "root":
        print("[+] THÀNH CÔNG: User đã có quyền sudo không cần mật khẩu (NOPASSWD)!")
    else:
        print(f"[!] Cảnh báo kiểm tra sudo: {check_res.stderr.strip()}")

    # Kiểm tra danh sách nhóm của user
    id_res = execute_ssh(host, user, port, f"id {user}", key_file)
    print(f"[+] Thông tin phân quyền hiện tại: {id_res.stdout.strip()}")
    print("==================================================")

if __name__ == "__main__":
    main()

    print("[*] Đang gửi lệnh thiết lập qua SSH...")
    res = execute_ssh(host, user, port, remote_script, key_file)
    
    if res.returncode != 0:
        print(f"[!] Lỗi khi thực thi: {res.stderr.strip()}")
        sys.exit(1)

    # Kiểm tra lại quyền sudo không mật khẩu
    check_res = execute_ssh(host, user, port, "sudo whoami", key_file)
    if check_res.stdout.strip() == "root":
        print("[+] THÀNH CÔNG: User đã có quyền sudo không cần mật khẩu (NOPASSWD)!")
    else:
        print(f"[!] Cảnh báo kiểm tra sudo: {check_res.stderr.strip()}")

    # Kiểm tra danh sách nhóm của user
    id_res = execute_ssh(host, user, port, f"id {user}", key_file)
    print(f"[+] Thông tin phân quyền hiện tại: {id_res.stdout.strip()}")
    print("==================================================")

if __name__ == "__main__":
    main()

