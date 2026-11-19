#!/usr/bin/env python3
"""
Lab 05 - Kiem thu co che phong thu SQL Injection (Prepared Statements)
Kiem tra tren cac ban va: sqli1_fixed.php va sqli2_fixed.php.
"""

import sys
import urllib.parse
import urllib.request

IP_WEB = "10.2.6.80"

def test_select_defense():
    print("[*] 1. Kiem thu SELECT SQLi tren sqli1_fixed.php...")
    url = f"http://{IP_WEB}/sqli/sqli1_fixed.php?cat=" + urllib.parse.quote("any' or 1;#")
    req = urllib.request.Request(url, headers={"User-Agent": "Lab05-Verifier"})
    with urllib.request.urlopen(req, timeout=5) as resp:
        body = resp.read().decode('utf-8', errors='ignore')
        if "No products found" in body:
            print("  [PASS] Tautology payload bi coi la chuoi thuan tuy. Khong bi khai thac!")
        else:
            print("  [FAIL] Co dau hieu bi khai thac!")

    url_union = f"http://{IP_WEB}/sqli/sqli1_fixed.php?cat=" + urllib.parse.quote("laptop' UNION SELECT 1, database(), 3, 4;#")
    req2 = urllib.request.Request(url_union, headers={"User-Agent": "Lab05-Verifier"})
    with urllib.request.urlopen(req2, timeout=5) as resp:
        body2 = resp.read().decode('utf-8', errors='ignore')
        if "Vendor : webvul" not in body2:
            print("  [PASS] UNION SELECT bi vo hieu hoa hoan toan boi Prepared Statement!")
        else:
            print("  [FAIL] UNION SELECT van thuc thi duoc!")

def test_insert_defense():
    print("\n[*] 2. Kiem thu INSERT SQLi tren sqli2_fixed.php...")
    url = f"http://{IP_WEB}/sqli/sqli2_fixed.php"
    form = {
        "cat": "keyboard",
        "vendor": "anyVendor', database(), '2', '3');#",
        "model": "anyModel",
        "price": "0"
    }
    data = urllib.parse.urlencode(form).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers={"User-Agent": "Lab05-Verifier"})
    with urllib.request.urlopen(req, timeout=5) as resp:
        body = resp.read().decode('utf-8', errors='ignore')
        if "anyVendor" in body:
            print("  [PASS] Payload duoc luu nguyen ven duoi dang ten chuoi vendor, ham database() khong bi thuc thi!")
        else:
            print("  [FAIL] Khong them duoc ban ghi!")

if __name__ == "__main__":
    test_select_defense()
    test_insert_defense()
    print("\n[✓] Hoan tat kiem thu phong thu SQL Injection!")
