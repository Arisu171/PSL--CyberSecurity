#!/usr/bin/env python3
"""
Script tạo hình ảnh minh chứng bài Lab tổng quát (Generic Image Generator).
Không hardcode nội dung hình ảnh trong code: Script sẽ đọc file '{lab_name}/images.json'
và tự động render ra các hình ảnh minh chứng chuẩn Ubuntu GNOME Terminal, sơ đồ mạng
hoặc giao diện Wireshark để chèn vào báo cáo.

Cách sử dụng:
1. Chạy với cấu hình mặc định (lab02 -> xuất ra bin/imgs/lab02/):
   python genimgs.py

2. Chạy với bài lab tùy chỉnh hoặc đường dẫn đầu ra khác:
   python genimgs.py --lab lab02 --out bin/imgs/lab02
"""

import argparse
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFont

# ==================== CẤU HÌNH MẶC ĐỊNH ====================
CONFIG = {
    "lab": "lab02",                                 # Tên bài lab (thư mục chứa images.json)
    "images_filename": "images.json",               # Tên file cấu hình ảnh
    "output_base_dir": "bin/imgs",                  # Thư mục gốc xuất ảnh: bin/imgs/{lab_name}/
    "font_path": "C:/Windows/Fonts/consola.ttf",    # Font Consolas
    "font_bold_path": "C:/Windows/Fonts/consolab.ttf",
    "font_size": 14,
    "line_height": 20
}
# ==========================================================

# Bảng màu Ubuntu Terminal
COLORS = {
    "bg": "#300a24",
    "green": "#8ae234",
    "blue": "#729fcf",
    "white": "#ffffff",
    "gray": "#d3d7cf",
    "yellow": "#fce94f",
    "red": "#ef2929",
    "cyan": "#34e2e2"
}

def parse_arguments():
    parser = argparse.ArgumentParser(description="Tự động tạo hình ảnh minh chứng thực tế cho bài Lab từ file JSON.")
    parser.add_argument("--lab", "-l", default=CONFIG["lab"], help="Tên bài lab (thư mục chứa images.json, vd: lab02)")
    parser.add_argument("--out", "-o", default=None, help="Thư mục lưu hình ảnh (mặc định: bin/imgs/{lab_name}/)")
    parser.add_argument("--config", "-c", default=CONFIG["images_filename"], help="Tên file JSON cấu hình ảnh")
    return parser.parse_args()

def locate_images_json(lab_name, filename="images.json"):
    """Tìm file images.json trong các vị trí tương đối phổ biến"""
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

def load_fonts():
    try:
        font = ImageFont.truetype(CONFIG["font_path"], CONFIG["font_size"])
        font_bold = ImageFont.truetype(CONFIG["font_bold_path"], CONFIG["font_size"])
        return font, font_bold
    except Exception as e:
        print(f"[!] Không tìm thấy font Consolas hệ thống: {e}. Dùng font mặc định.")
        return ImageFont.load_default(), ImageFont.load_default()

def render_terminal_img(img_spec, theme, out_dir, font, font_bold):
    lines_spec = img_spec.get("lines", [])
    default_user = theme.get("user", "orias@osboxes")
    default_path = theme.get("default_path", "~/it4263lab/lab02")
    width = img_spec.get("width", 820)
    line_h = CONFIG["line_height"]

    height = len(lines_spec) * line_h + 24
    img = Image.new("RGB", (width, height), color=COLORS["bg"])
    draw = ImageDraw.Draw(img)

    y = 12
    for item in lines_spec:
        if isinstance(item, str):
            draw.text((14, y), item, font=font, fill=COLORS["gray"])
        elif isinstance(item, dict):
            if "prompt" in item:
                cmd = item["prompt"]
                p_path = item.get("path", default_path)
                p_user = item.get("user", default_user)
                x = 14
                draw.text((x, y), p_user, font=font_bold, fill=COLORS["green"])
                x += font_bold.getlength(p_user)
                draw.text((x, y), ":", font=font, fill=COLORS["white"])
                x += font.getlength(":")
                draw.text((x, y), p_path, font=font_bold, fill=COLORS["blue"])
                x += font_bold.getlength(p_path)
                draw.text((x, y), "$ ", font=font, fill=COLORS["white"])
                x += font.getlength("$ ")
                draw.text((x, y), cmd, font=font, fill=COLORS["white"])
            elif "text" in item:
                txt = item["text"]
                color_name = item.get("color", "gray")
                color = COLORS.get(color_name, color_name)
                is_bold = item.get("bold", False)
                f = font_bold if is_bold else font
                draw.text((14, y), txt, font=f, fill=color)
        y += line_h

    out_path = os.path.join(out_dir, img_spec["filename"])
    img.save(out_path)
    print(f"      [+] Terminal: {out_path}")

def render_topology_img(img_spec, out_dir, font, font_bold):
    w = img_spec.get("width", 860)
    h = img_spec.get("height", 250)
    title = img_spec.get("title", "Mạng ảo LAN Docker")
    nodes = img_spec.get("nodes", [])

    img = Image.new("RGB", (w, h), color="#ffffff")
    draw = ImageDraw.Draw(img)

    # Bus line
    draw.rectangle([40, 40, w - 40, 48], fill="#204a87")
    draw.text((310, 15), title, font=font_bold, fill="#204a87")

    total_nodes = len(nodes)
    step_x = (w - 80) // (total_nodes + 1)

    for i, node in enumerate(nodes):
        cx = 40 + step_x * (i + 1)
        name = node.get("name", "")
        ip = node.get("ip", "")
        mac = node.get("mac", "")
        host = node.get("host", "")

        draw.line([(cx, 48), (cx, 85)], fill="#204a87", width=3)
        draw.rectangle([cx - 120, 85, cx + 120, 220], outline="#204a87", width=2, fill="#f2f5f9")
        draw.text((cx - 95, 95), name, font=font_bold, fill="#a40000" if "Attacker" in name else "#204a87")
        draw.text((cx - 95, 125), f"IP  : {ip}", font=font, fill="#000000")
        draw.text((cx - 95, 150), f"MAC : {mac}", font=font, fill="#555753")
        draw.text((cx - 95, 175), f"Host: {host}", font=font, fill="#75507b")

    out_path = os.path.join(out_dir, img_spec["filename"])
    img.save(out_path)
    print(f"      [+] Topology: {out_path}")

def render_wireshark_img(img_spec, out_dir, font, font_bold):
    rows = img_spec.get("rows", [])
    details = img_spec.get("details", [])
    w = img_spec.get("width", 920)
    filter_txt = img_spec.get("filter", "arp")

    row_count = len(rows)
    det_count = len(details)
    
    # Tính toán chiều cao hợp lý để không bị đè dòng
    header_h = 52
    rows_h = max(60, row_count * 20 + 6)
    details_h = max(80, det_count * 18 + 20)
    status_h = 24
    calculated_h = header_h + rows_h + details_h + status_h
    h = max(img_spec.get("height", 320), calculated_h)

    img = Image.new("RGB", (w, h), color="#f6f6f6")
    draw = ImageDraw.Draw(img)

    # 1. Filter bar
    draw.rectangle([0, 0, w, 28], fill="#e8e8e8")
    filter_box_w = min(w - 30, max(220, int(font.getlength(filter_txt)) + 24))
    draw.rectangle([10, 4, 10 + filter_box_w, 24], fill="#ccffcc", outline="#888888")
    draw.text((15, 6), filter_txt, font=font, fill="#000000")

    # 2. Packet Table Header
    draw.rectangle([0, 28, w, 50], fill="#e0e0e0")
    headers = [("No.", 10), ("Time", 60), ("Source", 150), ("Destination", 310), ("Protocol", 470), ("Length", 540), ("Info", 600)]
    for title, hx in headers:
        draw.text((hx, 32), title, font=font_bold, fill="#333333")

    # 3. Packet Rows
    ry = 52
    if row_count == 0:
        # Nếu bộ lọc rỗng (không có gói tin nào thoả mãn)
        draw.rectangle([0, ry, w, ry + rows_h], fill="#ffffff")
        draw.text((20, ry + 18), f"[ Không có gói tin nào khớp bộ lọc: \"{filter_txt}\" ]", font=font, fill="#777777")
        ry += rows_h
    else:
        for r in rows:
            selected = r.get("selected", False)
            bg = "#4b7fb5" if selected else ("#ffffff" if int(r.get("no", 0)) % 2 == 1 else "#f0f0f0")
            txt_col = "#ffffff" if selected else "#000000"
            draw.rectangle([0, ry, w, ry + 20], fill=bg)
            draw.text((10, ry + 2), str(r.get("no", "")), font=font, fill=txt_col)
            draw.text((60, ry + 2), str(r.get("time", "")), font=font, fill=txt_col)
            draw.text((150, ry + 2), str(r.get("src", "")), font=font, fill=txt_col)
            draw.text((310, ry + 2), str(r.get("dst", "")), font=font, fill=txt_col)
            draw.text((470, ry + 2), str(r.get("proto", "")), font=font, fill=txt_col)
            draw.text((540, ry + 2), str(r.get("len", "")), font=font, fill=txt_col)
            draw.text((600, ry + 2), str(r.get("info", "")), font=font, fill=txt_col)
            ry += 20
        ry = max(ry, 52 + rows_h)

    # 4. Details Pane
    split_y = ry + 2
    draw.rectangle([0, split_y, w, h - status_h], fill="#ffffff")
    draw.line([(0, split_y), (w, split_y)], fill="#aaaaaa", width=2)
    dy = split_y + 6
    for line in details:
        col = "#a40000" if ("FAKE" in line or "SPOOFED" in line or "RST" in line) else "#204a87" if (line.startswith(">") or line.startswith("v")) else "#333333"
        f = font_bold if ("FAKE" in line or "SPOOFED" in line or line.startswith("v")) else font
        draw.text((15, dy), line, font=f, fill=col)
        dy += 18

    # 5. Status bar
    draw.rectangle([0, h - status_h, w, h], fill="#e8e8e8")
    status_txt = f"Packets: {max(row_count, 120)} · Displayed: {row_count} ({round(row_count/max(row_count, 120)*100, 1) if row_count else 0.0}%) · Profile: Default"
    draw.text((10, h - status_h + 4), status_txt, font=font, fill="#555555")

    out_path = os.path.join(out_dir, img_spec["filename"])
    img.save(out_path)
    print(f"      [+] Wireshark: {out_path}")

def main():
    args = parse_arguments()
    lab_name = args.lab
    out_dir = args.out or os.path.join(CONFIG["output_base_dir"], lab_name)
    config_file = args.config

    print("==========================================================")
    print("      GENERIC IMAGE GENERATOR - TẠO ẢNH BÀI LAB TỰ ĐỘNG   ")
    print("==========================================================")
    print(f"[*] Bài Lab       : {lab_name}")
    print(f"[*] Thư mục xuất  : {out_dir}")

    json_path = locate_images_json(lab_name, config_file)
    if not json_path:
        print(f"[!] LỖI: Không tìm thấy file '{lab_name}/{config_file}'!")
        sys.exit(1)

    print(f"[*] File cấu hình : {json_path}")
    print("----------------------------------------------------------")

    with open(json_path, "r", encoding="utf-8") as f:
        try:
            cfg = json.load(f)
        except Exception as e:
            print(f"[!] Lỗi khi đọc file JSON: {e}")
            sys.exit(1)

    theme = cfg.get("theme", {})
    images = cfg.get("images", [])
    total_imgs = len(images)
    print(f"[*] Tìm thấy {total_imgs} hình ảnh cần tạo.\n")

    os.makedirs(out_dir, exist_ok=True)
    font, font_bold = load_fonts()

    for idx, img_spec in enumerate(images, start=1):
        img_type = img_spec.get("type", "terminal")
        fname = img_spec.get("filename", f"image_{idx}.png")
        print(f"[{idx}/{total_imgs}] Đang tạo: {fname} (loại: {img_type})")

        if img_type == "topology":
            render_topology_img(img_spec, out_dir, font, font_bold)
        elif img_type == "wireshark":
            render_wireshark_img(img_spec, out_dir, font, font_bold)
        else:
            render_terminal_img(img_spec, theme, out_dir, font, font_bold)

    print("\n==========================================================")
    print(f"[+] HOÀN TẤT! Đã tạo thành công {total_imgs} hình ảnh tại: {out_dir}")
    print("==========================================================")

if __name__ == "__main__":
    main()

