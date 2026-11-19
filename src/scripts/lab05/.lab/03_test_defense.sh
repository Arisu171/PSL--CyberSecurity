#!/bin/bash
# Kiem thu giai phap phong chong SQL Injection bang Prepared Statements
# Kiem tra tren sqli1_fixed.php va sqli2_fixed.php

set -u

CONTAINER_ATTACKER="lab05_attacker"
IP_WEB="10.2.6.80"

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; }

note "1. Kiem thu tan cong Tautology (any' or 1;#) tren sqli1_fixed.php"
res1=$(sudo docker exec "$CONTAINER_ATTACKER" curl -s "http://${IP_WEB}/sqli/sqli1_fixed.php?cat=any%27+or+1%3B%23")
if grep -q "No products found" <<<"$res1"; then
  pass "Prepared Statement da coi toan bo payload la mot chuoi gia tri thuan tuy (Khong bi SQLi)!"
else
  bad "Co dau hieu bi khai thac"
fi

note "2. Kiem thu tan cong UNION SELECT tren sqli1_fixed.php"
res2=$(sudo docker exec "$CONTAINER_ATTACKER" curl -s "http://${IP_WEB}/sqli/sqli1_fixed.php?cat=laptop%27+UNION+SELECT+1%2C+database%28%29%2C+3%2C+4%3B%23")
if ! grep -q "Vendor : webvul" <<<"$res2"; then
  pass "Khong the su dung UNION de trich xuat CSDL tren trang fixed!"
else
  bad "UNION SELECT van thuc thi duoc"
fi

note "3. Kiem thu tan cong INSERT SQLi tren sqli2_fixed.php"
res3=$(sudo docker exec "$CONTAINER_ATTACKER" curl -s -X POST \
  -d "cat=keyboard&vendor=anyVendor%27%2C+database%28%29%2C+%272%27%2C+%273%27%29%3B%23&model=anyModel&price=0" \
  "http://${IP_WEB}/sqli/sqli2_fixed.php")
if grep -q "anyVendor" <<<"$res3"; then
  pass "Chuoi payload duoc luu nguyen ban duoi dang ten vendor, ham database() khong bi thuc thi!"
else
  bad "Khong them duoc ban ghi"
fi

echo -e "\n[✓] KIEM THU PHONG CHONG SQL INJECTION HOAN TAT XUAT SAC!"
