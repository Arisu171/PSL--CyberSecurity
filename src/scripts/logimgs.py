#!/usr/bin/env python3
"""
Script tạo ảnh minh chứng thực tế cho bài Lab từ log thực nghiệm SSH.
Đọc file kết quả thực nghiệm (bin/{lab}_results.json) và file cấu hình ảnh
(src/scripts/{lab}/images.json), override phần lines[] của ảnh terminal
bằng output thực từ log, sau đó render bằng engine genimgs.py.

Cách sử dụng:
    python src/scripts/log2imgs.py --lab lab03
    python src/scripts/log2imgs.py --lab lab03 --results bin/lab03_results.json
"""

import argparse
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFont

# ==================== CẤU HÌNH MẶC ĐỊNH ====================
CONFIG = {
    "lab": "lab03",
    "results_file": None,            # None -> tự động: bin/{lab}_results.json
    "images_filename": "images.json",
    "output_base_dir": "bin/imgs",
    "font_path": "C:/Windows/Fonts/consola.ttf",
    "font_bold_path": "C:/Windows/Fonts/consolab.ttf",
    "font_size": 14,
    "line_height": 20,
}
# ==========================================================

# Map: image_id -> key trong results.json (log thực tế cần override)
# Key = None: giữ nguyên nội dung images.json (đã đủ, không cần log)
LOG_OVERRIDE_MAP = {
    "lab03": {
        "image1":  "step11_dig_attacker_ns",   # dig ns.attacker32.com - thực
        "image2":  "step12_dig_example_legit",  # dig www.example.com ban đầu
        "image3":  "step13_dig_example_direct", # dig @attacker www.example.com
        "image4":  "step42_gen_query",           # gen_query.py output
        "image5":  "step43_gen_response",        # gen_response.py output
        "image6":  None,                         # wireshark - giữ spec JSON
        "image7":  None,
        "image8":  None,
        "image9":  None,
        "image10": "step44_dump_cache",          # cache dump
        "image11": "step44_dig_poisoned",        # dig sau tấn công
        "image12": "step45_defense_verify",      # dig sau phòng thủ
    }
}

# Bảng màu Ubuntu Terminal
COLORS = {
    "bg":     "#300a24",
    "green":  "#8ae234",
    "blue":   "#729fcf",
    "white":  "#ffffff",
    "gray":   "#d3d7cf",
    "yellow": "#fce94f",
    "red":    "#ef2929",
    "cyan":   "#34e2e2",
}


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Tạo ảnh minh chứng thực tế từ log SSH thực nghiệm bài Lab."
    )
    parser.add_argument("--lab", "-l", default=CONFIG["lab"],
                        help="Tên bài lab (vd: lab03)")
    parser.add_argument("--results", "-r", default=None,
                        help="Đường dẫn file results JSON (mặc định: bin/{lab}_results.json)")
    parser.add_argument("--out", "-o", default=None,
                        help="Thư mục lưu ảnh (mặc định: bin/imgs/{lab})")
    parser.add_argument("--config", "-c", default=CONFIG["images_filename"],
                        help="Tên file images.json trong thư mục lab")
    return parser.parse_args()


def locate_json(lab_name, filename):
    possible = [
        os.path.join(lab_name, filename),
        os.path.join("src", "scripts", lab_name, filename),
        os.path.join(os.path.dirname(__file__), lab_name, filename),
    ]
    for p in possible:
        if os.path.exists(p):
            return os.path.abspath(p)
    return None


def load_fonts():
    try:
        font      = ImageFont.truetype(CONFIG["font_path"],      CONFIG["font_size"])
        font_bold = ImageFont.truetype(CONFIG["font_bold_path"], CONFIG["font_size"])
        return font, font_bold
    except Exception as e:
        print(f"[!] Không tìm thấy font Consolas: {e}. Dùng font mặc định.")
        return ImageFont.load_default(), ImageFont.load_default()


# ------------------------------------------------------------------ #
#  Chuyển output text thực (string) thành list lines[] cho terminal   #
# ------------------------------------------------------------------ #
def log_to_lines(raw_log: str, cmd_hint: str, theme: dict) -> list:
    """
    raw_log  : stdout/stderr thực từ SSH (có thể nhiều dòng)
    cmd_hint : lệnh đã chạy (để hiển thị dòng prompt đầu tiên)
    theme    : dict user/default_path từ images.json
    """
    lines = []
    # Dòng prompt đầu tiên với lệnh thực
    if cmd_hint:
        lines.append({"prompt": cmd_hint, "user": theme.get("user", "orias@osboxes"),
                      "path": theme.get("default_path", "~")})

    if raw_log:
        for line in raw_log.splitlines():
            line = line.rstrip()
            # Tô màu theo nội dung
            if any(kw in line for kw in ("NOERROR", "ANSWER", "OK", "successfully", "done", "[+]")):
                lines.append({"text": line, "color": "green"})
            elif any(kw in line for kw in ("SERVFAIL", "REFUSED", "error", "ERROR", "timed out", "[!]")):
                lines.append({"text": line, "color": "red"})
            elif any(kw in line for kw in ("QUESTION", "AUTHORITY", "ADDITIONAL", "flags:", "SERVER:", "WHEN:")):
                lines.append({"text": line, "color": "cyan"})
            elif line.startswith(";;") or line.startswith(";"):
                lines.append({"text": line, "color": "yellow"})
            else:
                lines.append(line)
    else:
        lines.append({"text": "(Không có output / lệnh thành công không có stdout)", "color": "yellow"})

    # Dòng prompt trống ở cuối
    lines.append({"prompt": "", "user": theme.get("user", "orias@osboxes"),
                  "path": theme.get("default_path", "~")})
    return lines


# ------------------------------------------------------------------ #
#  Map lệnh SSH từ scripts.json theo key để hiện dòng prompt đúng    #
# ------------------------------------------------------------------ #
def build_cmd_map(lab_name: str) -> dict:
    """Trả về {key: command_string} từ scripts.json"""
    scripts_path = locate_json(lab_name, "scripts.json")
    if not scripts_path:
        return {}
    with open(scripts_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    return {step["key"]: step.get("command", "") for step in data.get("steps", [])}


# ------------------------------------------------------------------ #
#  Render terminal                                                     #
# ------------------------------------------------------------------ #
def render_terminal(img_spec, theme, out_dir, font, font_bold):
    lines_spec = img_spec.get("lines", [])
    default_user = theme.get("user", "orias@osboxes")
    default_path = theme.get("default_path", "~")
    width   = img_spec.get("width", 860)
    line_h  = CONFIG["line_height"]
    height  = len(lines_spec) * line_h + 24

    img  = Image.new("RGB", (width, height), color=COLORS["bg"])
    draw = ImageDraw.Draw(img)
    y = 12

    for item in lines_spec:
        if isinstance(item, str):
            draw.text((14, y), item, font=font, fill=COLORS["gray"])
        elif isinstance(item, dict):
            if "prompt" in item:
                cmd    = item["prompt"]
                p_path = item.get("path", default_path)
                p_user = item.get("user", default_user)
                x = 14
                draw.text((x, y), p_user,  font=font_bold, fill=COLORS["green"])
                x += font_bold.getlength(p_user)
                draw.text((x, y), ":",      font=font,      fill=COLORS["white"])
                x += font.getlength(":")
                draw.text((x, y), p_path,  font=font_bold, fill=COLORS["blue"])
                x += font_bold.getlength(p_path)
                draw.text((x, y), "$ ",    font=font,      fill=COLORS["white"])
                x += font.getlength("$ ")
                draw.text((x, y), cmd,     font=font,      fill=COLORS["white"])
            elif "text" in item:
                txt  = item["text"]
                col  = COLORS.get(item.get("color", "gray"), item.get("color", COLORS["gray"]))
                f    = font_bold if item.get("bold", False) else font
                draw.text((14, y), txt, font=f, fill=col)
        y += line_h

    out_path = os.path.join(out_dir, img_spec["filename"])
    img.save(out_path)
    print(f"      [+] Terminal: {out_path}")


# ------------------------------------------------------------------ #
#  Render topology (giữ nguyên từ genimgs.py)                         #
# ------------------------------------------------------------------ #
def render_topology(img_spec, out_dir, font, font_bold):
    w     = img_spec.get("width", 860)
    h     = img_spec.get("height", 250)
    title = img_spec.get("title", "Mạng ảo LAN Docker")
    nodes = img_spec.get("nodes", [])

    img  = Image.new("RGB", (w, h), color="#ffffff")
    draw = ImageDraw.Draw(img)
    draw.rectangle([40, 40, w - 40, 48], fill="#204a87")
    draw.text((310, 15), title, font=font_bold, fill="#204a87")

    total_nodes = len(nodes)
    step_x = (w - 80) // (total_nodes + 1)

    for i, node in enumerate(nodes):
        cx   = 40 + step_x * (i + 1)
        name = node.get("name", "")
        ip   = node.get("ip", "")
        mac  = node.get("mac", "")
        host = node.get("host", "")

        draw.line([(cx, 48), (cx, 85)], fill="#204a87", width=3)
        draw.rectangle([cx - 120, 85, cx + 120, 220], outline="#204a87", width=2, fill="#f2f5f9")
        draw.text((cx - 95, 95),  name,         font=font_bold, fill="#a40000" if "Attacker" in name else "#204a87")
        draw.text((cx - 95, 125), f"IP  : {ip}", font=font,      fill="#000000")
        draw.text((cx - 95, 150), f"MAC : {mac}", font=font,     fill="#555753")
        draw.text((cx - 95, 175), f"Host: {host}", font=font,    fill="#75507b")

    out_path = os.path.join(out_dir, img_spec["filename"])
    img.save(out_path)
    print(f"      [+] Topology: {out_path}")


# ------------------------------------------------------------------ #
#  Render wireshark (giữ nguyên từ genimgs.py)                        #
# ------------------------------------------------------------------ #
def render_wireshark(img_spec, out_dir, font, font_bold):
    rows       = img_spec.get("rows", [])
    details    = img_spec.get("details", [])
    w          = img_spec.get("width", 920)
    filter_txt = img_spec.get("filter", "dns")

    row_count  = len(rows)
    det_count  = len(details)
    header_h   = 52
    rows_h     = max(60, row_count * 20 + 6)
    details_h  = max(80, det_count * 18 + 20)
    status_h   = 24
    h = max(img_spec.get("height", 320), header_h + rows_h + details_h + status_h)

    img  = Image.new("RGB", (w, h), color="#f6f6f6")
    draw = ImageDraw.Draw(img)

    # Filter bar
    draw.rectangle([0, 0, w, 28], fill="#e8e8e8")
    filter_box_w = min(w - 30, max(220, int(font.getlength(filter_txt)) + 24))
    draw.rectangle([10, 4, 10 + filter_box_w, 24], fill="#ccffcc", outline="#888888")
    draw.text((15, 6), filter_txt, font=font, fill="#000000")

    # Header row
    draw.rectangle([0, 28, w, 50], fill="#e0e0e0")
    for title, hx in [("No.", 10), ("Time", 60), ("Source", 150), ("Destination", 310),
                       ("Protocol", 470), ("Length", 540), ("Info", 600)]:
        draw.text((hx, 32), title, font=font_bold, fill="#333333")

    # Packet rows
    ry = 52
    if row_count == 0:
        draw.rectangle([0, ry, w, ry + rows_h], fill="#ffffff")
        draw.text((20, ry + 18), f"[ Không có gói tin nào khớp bộ lọc: \"{filter_txt}\" ]",
                  font=font, fill="#777777")
        ry += rows_h
    else:
        for r in rows:
            selected = r.get("selected", False)
            bg       = "#4b7fb5" if selected else ("#ffffff" if int(r.get("no", 0)) % 2 == 1 else "#f0f0f0")
            tc       = "#ffffff" if selected else "#000000"
            draw.rectangle([0, ry, w, ry + 20], fill=bg)
            draw.text((10,  ry + 2), str(r.get("no",    "")), font=font, fill=tc)
            draw.text((60,  ry + 2), str(r.get("time",  "")), font=font, fill=tc)
            draw.text((150, ry + 2), str(r.get("src",   "")), font=font, fill=tc)
            draw.text((310, ry + 2), str(r.get("dst",   "")), font=font, fill=tc)
            draw.text((470, ry + 2), str(r.get("proto", "")), font=font, fill=tc)
            draw.text((540, ry + 2), str(r.get("len",   "")), font=font, fill=tc)
            draw.text((600, ry + 2), str(r.get("info",  "")), font=font, fill=tc)
            ry += 20
        ry = max(ry, 52 + rows_h)

    # Details pane
    split_y = ry + 2
    draw.rectangle([0, split_y, w, h - status_h], fill="#ffffff")
    draw.line([(0, split_y), (w, split_y)], fill="#aaaaaa", width=2)
    dy = split_y + 6
    for line in details:
        col = ("#a40000" if ("FAKE" in line or "SPOOFED" in line or "RST" in line or "MATCHED" in line)
               else "#204a87" if (line.startswith(">") or line.startswith("v"))
               else "#333333")
        f   = font_bold if ("FAKE" in line or "SPOOFED" in line or line.startswith("v") or "MATCHED" in line) else font
        draw.text((15, dy), line, font=f, fill=col)
        dy += 18

    # Status bar
    draw.rectangle([0, h - status_h, w, h], fill="#e8e8e8")
    pct = round(row_count / max(row_count, 120) * 100, 1) if row_count else 0.0
    status_txt = f"Packets: {max(row_count, 120)} · Displayed: {row_count} ({pct}%) · Profile: Default"
    draw.text((10, h - status_h + 4), status_txt, font=font, fill="#555555")

    out_path = os.path.join(out_dir, img_spec["filename"])
    img.save(out_path)
    print(f"      [+] Wireshark: {out_path}")


# ------------------------------------------------------------------ #
#  Main                                                                #
# ------------------------------------------------------------------ #
def main():
    args     = parse_arguments()
    lab_name = args.lab
    out_dir  = args.out or os.path.join(CONFIG["output_base_dir"], lab_name)

    results_path = args.results or f"bin/{lab_name}_results.json"

    print("==========================================================")
    print("   LOG2IMGS - TẠO ẢNH THỰC NGHIỆM TỪ LOG SSH BÀI LAB    ")
    print("==========================================================")
    print(f"[*] Bài Lab     : {lab_name}")
    print(f"[*] Log thực    : {results_path}")
    print(f"[*] Thư mục xuất: {out_dir}")

    # --- Đọc log thực nghiệm ---
    if not os.path.exists(results_path):
        print(f"[!] LỖI: Không tìm thấy file log '{results_path}'!")
        sys.exit(1)
    with open(results_path, "r", encoding="utf-8") as f:
        results = json.load(f)

    # --- Đọc images.json ---
    json_path = locate_json(lab_name, args.config)
    if not json_path:
        print(f"[!] LỖI: Không tìm thấy file '{lab_name}/{args.config}'!")
        sys.exit(1)
    print(f"[*] images.json : {json_path}")
    print("----------------------------------------------------------")

    with open(json_path, "r", encoding="utf-8") as f:
        cfg = json.load(f)

    theme  = cfg.get("theme", {})
    images = cfg.get("images", [])

    # --- Lấy map lệnh thực từ scripts.json ---
    cmd_map      = build_cmd_map(lab_name)
    override_map = LOG_OVERRIDE_MAP.get(lab_name, {})

    total = len(images)
    print(f"[*] Tổng số ảnh : {total}\n")

    os.makedirs(out_dir, exist_ok=True)
    font, font_bold = load_fonts()

    for idx, img_spec in enumerate(images, start=1):
        img_id   = img_spec.get("id", f"image{idx}")
        img_type = img_spec.get("type", "terminal")
        fname    = img_spec.get("filename", f"image_{idx}.png")
        log_key  = override_map.get(img_id)

        print(f"[{idx}/{total}] {fname} (loại: {img_type}, log_key: {log_key or 'N/A - dùng spec JSON'})")

        # Override lines[] nếu là terminal và có log key
        if img_type == "terminal" and log_key and log_key in results:
            raw_log  = results[log_key]
            # Lấy lệnh gốc từ scripts.json để hiển thị ở prompt
            cmd_hint = cmd_map.get(log_key, "")
            # Rút gọn lệnh sudo docker exec ... bash -c '...' -> chỉ lấy phần trong bash -c
            if "bash -c" in cmd_hint:
                try:
                    cmd_hint = cmd_hint.split("bash -c '")[1].rstrip("'")
                except Exception:
                    pass
            elif "sudo docker exec" in cmd_hint and "dig" in cmd_hint:
                # Chỉ lấy phần dig ...
                parts = cmd_hint.split()
                try:
                    dig_idx = parts.index("dig")
                    cmd_hint = " ".join(parts[dig_idx:])
                except ValueError:
                    pass
            img_spec = dict(img_spec)  # shallow copy để không mutate gốc
            img_spec["lines"] = log_to_lines(raw_log, cmd_hint, theme)
            print(f"      -> Override bằng log thực ({len(raw_log.splitlines())} dòng raw)")
        elif img_type == "terminal" and log_key:
            print(f"      -> [!] Key '{log_key}' không có trong results (output rỗng) - giữ spec JSON")

        # Render
        if img_type == "topology":
            render_topology(img_spec, out_dir, font, font_bold)
        elif img_type == "wireshark":
            render_wireshark(img_spec, out_dir, font, font_bold)
        else:
            render_terminal(img_spec, theme, out_dir, font, font_bold)

    print(f"\n==========================================================")
    print(f"[+] HOÀN TẤT! Đã tạo {total} ảnh thực nghiệm tại: {out_dir}")
    print(f"==========================================================")


if __name__ == "__main__":
    main()
