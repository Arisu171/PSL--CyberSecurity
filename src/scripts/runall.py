#!/usr/bin/env python3
"""
Script thực thi kịch bản bài Lab tổng quát (Generic Lab Runner).
Không hardcode lệnh trong code: Script sẽ đọc lần lượt danh sách lệnh từ file
'{lab_name}/scripts.json', gửi qua SSH tới máy ảo để thực thi, thu thập kết quả
và lưu vào file JSON kết quả để phục vụ tạo báo cáo.

Cách sử dụng:
1. Chạy với cấu hình mặc định:
   python runall.py

2. Chạy với bài lab hoặc máy ảo tùy chỉnh:
   python runall.py --lab lab02 --host 192.168.117.13 --user orias

3. Chế độ kiểm tra danh sách lệnh mà không thực thi (Dry-run):
   python runall.py --lab lab02 --dry-run
"""

import subprocess
import argparse
import json
import time
import os
import sys

# ==================== CẤU HÌNH MẶC ĐỊNH ====================
CONFIG = {
    "lab": "lab02",                                 # Tên bài lab - thư mục chứa scripts.json
    "host": "192.168.117.13",                       # Địa chỉ IP của máy chủ/máy ảo
    "user": "orias",                                # Tên người dùng SSH
    "port": 22,                                     # Cổng SSH
    "key_file": None,                               # Đường dẫn SSH key riêng - None = mặc định
    "output_file": "bin/results.json",  # File lưu kết quả thực nghiệm
    "scripts_filename": "scripts.json"              # Tên file kịch bản trong thư mục lab
}
# ==========================================================

def parse_arguments():
    parser = argparse.ArgumentParser(description="Trình thực thi kịch bản bài Lab tự động qua SSH từ file JSON.")
    parser.add_argument("--lab", "-l", default=CONFIG["lab"], help="Tên bài lab (tên thư mục chứa scripts.json, vd: lab02)")
    parser.add_argument("--host", "-H", default=CONFIG["host"], help="Địa chỉ IP của máy ảo/máy chủ")
    parser.add_argument("--user", "-u", default=CONFIG["user"], help="Tên người dùng SSH")
    parser.add_argument("--port", "-P", type=int, default=CONFIG["port"], help="Cổng SSH (mặc định 22)")
    parser.add_argument("--key", "-i", default=CONFIG["key_file"], help="Đường dẫn file khóa SSH IdentityFile")
    parser.add_argument("--output", "-o", default=CONFIG["output_file"], help="Đường dẫn file lưu kết quả đầu ra")
    parser.add_argument("--dry-run", action="store_true", help="Chỉ hiển thị danh sách lệnh, không thực thi thật")
    return parser.parse_args()

def locate_scripts_json(lab_name, filename="scripts.json"):
    """Tìm file scripts.json trong các vị trí tương đối phổ biến"""
    possible_paths = [
        os.path.join(lab_name, filename),
        os.path.join("src", "scripts", lab_name, filename),
        os.path.join(os.path.dirname(__file__), lab_name, filename),
        os.path.join(os.path.dirname(__file__), "..", "scripts", lab_name, filename)
    ]
    for p in possible_paths:
        if os.path.exists(p):
            return os.path.abspath(p)
    return None

def execute_ssh(host, user, port, cmd_str, key_file=None, timeout=60):
    ssh_cmd = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-p", str(port)]
    if key_file:
        ssh_cmd.extend(["-i", key_file])
    ssh_cmd.append(f"{user}@{host}")
    ssh_cmd.append(cmd_str)
    
    try:
        res = subprocess.run(ssh_cmd, capture_output=True, text=True, timeout=timeout)
        return res.stdout.strip(), res.stderr.strip(), res.returncode
    except subprocess.TimeoutExpired:
        return "", f"Timeout sau {timeout}s", 124
    except Exception as e:
        return "", str(e), 1

def main():
    args = parse_arguments()
    lab_name = args.lab
    host = args.host
    user = args.user
    port = args.port
    key_file = args.key
    output_path = args.output
    dry_run = args.dry_run

    print("==========================================================")
    print("      GENERIC LAB RUNNER - THỰC THI BÀI LAB TỰ ĐỘNG       ")
    print("==========================================================")
    print(f"[*] Bài Lab       : {lab_name}")
    print(f"[*] Máy chủ SSH   : {user}@{host}:{port}")

    # Tìm file scripts.json
    json_path = locate_scripts_json(lab_name, CONFIG["scripts_filename"])
    if not json_path:
        print(f"[!] LỖI: Không tìm thấy file '{lab_name}/{CONFIG['scripts_filename']}'!")
        print("    Vui lòng kiểm tra lại thư mục của bài lab.")
        sys.exit(1)

    print(f"[*] File kịch bản : {json_path}")
    if dry_run:
        print("[!] Chế độ DRY-RUN: Chỉ in danh sách lệnh, không thực thi.")
    print("----------------------------------------------------------")

    with open(json_path, "r", encoding="utf-8") as f:
        try:
            lab_data = json.load(f)
        except Exception as e:
            print(f"[!] Lỗi khi đọc file JSON: {e}")
            sys.exit(1)

    steps = lab_data.get("steps", [])
    total_steps = len(steps)
    print(f"[*] Tìm thấy {total_steps} bước thực thi trong kịch bản.\n")

    results = {}

    for idx, step in enumerate(steps, start=1):
        key = step.get("key", f"step_{idx}")
        name = step.get("name", f"Bước {idx}")
        command = step.get("command", "")
        sleep_after = step.get("sleep_after", 0)
        timeout = step.get("timeout", 60)

        print(f"[{idx}/{total_steps}] {name}")
        print(f"      Lệnh : {command}")

        if dry_run:
            if sleep_after > 0:
                print(f"      Chờ  : {sleep_after}s")
            print()
            continue

        # Thực thi lệnh qua SSH
        stdout, stderr, code = execute_ssh(host, user, port, command, key_file, timeout=timeout)
        
        # Lưu kết quả theo key
        results[key] = stdout if stdout else stderr

        if code == 0:
            if stdout:
                # In rút gọn 3 dòng đầu nếu output dài
                lines = stdout.splitlines()
                preview = lines[0] if len(lines) == 1 else f"{lines[0]} ... ({len(lines)} dòng)"
                print(f"      -> OK: {preview}")
            else:
                print(f"      -> OK")
        else:
            print(f"      -> [!] Code {code}: {stderr[:120] if stderr else 'Lỗi'}")

        # Chờ nếu bước yêu cầu
        if sleep_after > 0:
            print(f"      (Đang chờ {sleep_after} giây...)")
            time.sleep(sleep_after)

        print()

    if not dry_run:
        # Tạo thư mục chứa file kết quả nếu chưa có
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(results, f, ensure_ascii=False, indent=2)

        print("==========================================================")
        print(f"[+] HOÀN THÀNH TOÀN BỘ {total_steps} BƯỚC THỰC HIỆN!")
        print(f"[+] Đã lưu toàn bộ dữ liệu thực nghiệm vào: {output_path}")
        print("==========================================================")

if __name__ == "__main__":
    main()
