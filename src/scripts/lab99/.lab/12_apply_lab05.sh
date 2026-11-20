#!/bin/bash
# Lab99: Kiem chung phong thu Ung dung Web: SQL Injection & OS Command Injection (OWASP Top 10).
# Thuc hien truc tiep tren moi truong Lab 99: Assessor (10.2.99.20) tan cong kiem thu Target (10.2.99.10:8080).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_TARGET="lab99_target"
CONTAINER_ASSESSOR="lab99_assessor"
IP_TARGET="10.2.99.10"
IP_ASSESSOR="10.2.99.20"
APP_PORT="8080"
REPORT_DIR="${PROJECT_LAB}/volumes/reports"
LOG="${REPORT_DIR}/lab05_verify.log"
SUMMARY="${REPORT_DIR}/lab05_verify_summary.txt"
fail=0

note() { printf '\n===== %s =====\n' "$1"; }
pass() { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; fail=1; }

mkdir -p "$REPORT_DIR"

note "Kiem tra trang thai container Lab 99"
if ! sudo docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_TARGET"; then
  echo "[-] Container $CONTAINER_TARGET chua chay. Khoi dong .lab/00_init.sh truoc!"
  exit 1
fi
if ! sudo docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_ASSESSOR"; then
  echo "[-] Container $CONTAINER_ASSESSOR chua chay. Khoi dong .lab/00_init.sh truoc!"
  exit 1
fi

# Dam bao ung dung web demo dang chay tren Target
if ! sudo docker exec "$CONTAINER_TARGET" pgrep -f lab99_app.py >/dev/null 2>&1; then
  sudo docker exec -d "$CONTAINER_TARGET" python3 /usr/local/bin/lab99_app.py "$APP_PORT"
  sleep 1
fi

{
  echo "=========================================================="
  echo " LAB99 -> KIEM CHUNG PHONG THU UNG DUNG: SQLi & RCE"
  echo " Thoi gian thuc hien: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo " Target: ${IP_TARGET}:${APP_PORT} | Assessor: ${IP_ASSESSOR}"
  echo "=========================================================="
  echo

  echo "[*] Buoc 1: Kiem tra ket noi Web App tren Target"
  HEALTH_RESP=$(sudo docker exec "$CONTAINER_ASSESSOR" curl -s -m 3 "http://${IP_TARGET}:${APP_PORT}/health" 2>/dev/null || echo "")
  echo "  - Response /health: ${HEALTH_RESP}"
  if echo "$HEALTH_RESP" | grep -q '"status":"healthy"'; then
    echo "  [+] Dich vu Web tren Target (${IP_TARGET}:${APP_PORT}) san sang."
  else
    echo "  [-] Khong the ket noi toi Web App tren ${IP_TARGET}:${APP_PORT}."
    fail=1
  fi
  echo

  echo "----------------------------------------------------------"
  echo " PHAN 1: KIEM CHUNG PHONG THU SQL INJECTION (LAB 05)"
  echo "----------------------------------------------------------"

  echo "[*] Buoc 2: Assessor tan cong SQLi Tautology tren endpoint CHUA PHONG THU (/sqli_vuln)"
  PAYLOAD_TAUTOLOGY="admin' OR '1'='1"
  ENCODED_TAUTOLOGY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$PAYLOAD_TAUTOLOGY'''))")
  VULN_RESP=$(sudo docker exec "$CONTAINER_ASSESSOR" curl -s "http://${IP_TARGET}:${APP_PORT}/sqli_vuln?user=${ENCODED_TAUTOLOGY}")
  echo "  - Payload: ${PAYLOAD_TAUTOLOGY}"
  echo "  - Ket qua tra ve:"
  echo "    ${VULN_RESP}"

  VULN_COUNT=$(echo "$VULN_RESP" | grep -o '"count": [0-9]*' | awk '{print $2}' || echo "0")
  if [[ "$VULN_COUNT" -ge 2 ]]; then
    echo "  [!] Xac nhan: Endpoint chua phong thu bi khai thac thanh cong (dump duoc ${VULN_COUNT} tai khoan)."
  else
    echo "  [-] Endpoint khong tra ve du lieu ky vong."
  fi
  echo

  echo "[*] Buoc 3: Assessor tan cong SQLi Tautology tren endpoint DA PHONG THU (/sqli_safe)"
  SAFE_RESP=$(sudo docker exec "$CONTAINER_ASSESSOR" curl -s "http://${IP_TARGET}:${APP_PORT}/sqli_safe?user=${ENCODED_TAUTOLOGY}")
  echo "  - Payload thu nghiem: ${PAYLOAD_TAUTOLOGY}"
  echo "  - Ket qua tra ve tu endpoint Prepared Statements:"
  echo "    ${SAFE_RESP}"

  SAFE_COUNT=$(echo "$SAFE_RESP" | grep -o '"count": [0-9]*' | awk '{print $2}' || echo "0")
  if [[ "$SAFE_COUNT" -eq 0 && "$SAFE_RESP" =~ "prepared_statement_safe" ]]; then
    echo "  [+] PHONG THU SQLi THANH CONG: Payload duoc Parameterized Query coi la chuoi gia tri thuan."
  else
    echo "  [-] Phong thu SQLi that bai hoac tra ve du lieu trai phep."
    fail=1
  fi
  echo

  echo "----------------------------------------------------------"
  echo " PHAN 2: KIEM CHUNG PHONG THU OS COMMAND INJECTION (RCE)"
  echo "----------------------------------------------------------"

  echo "[*] Buoc 4: Assessor tan cong Command Injection tren endpoint CHUA PHONG THU (/cmd_vuln)"
  CMD_PAYLOAD="127.0.0.1; whoami"
  ENCODED_CMD=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$CMD_PAYLOAD'''))")
  VULN_CMD_RESP=$(sudo docker exec "$CONTAINER_ASSESSOR" curl -s "http://${IP_TARGET}:${APP_PORT}/cmd_vuln?host=${ENCODED_CMD}")
  echo "  - Payload Command Injection: ${CMD_PAYLOAD}"
  echo "  - Ket qua tu endpoint chua phong thu:"
  echo "    ${VULN_CMD_RESP}"

  if echo "$VULN_CMD_RESP" | grep -qiE "root|labuser"; then
    echo "  [!] Xac nhan: Endpoint chua phong thu bi thuc thi lenh he dieu hanh trai phep (RCE)!"
  else
    echo "  [-] Chua xac nhan duoc RCE tren endpoint test."
  fi
  echo

  echo "[*] Buoc 5: Assessor tan cong Command Injection tren endpoint DA PHONG THU (/cmd_safe)"
  SAFE_CMD_RESP=$(sudo docker exec "$CONTAINER_ASSESSOR" curl -s -w "\nHTTP_STATUS:%{http_code}" "http://${IP_TARGET}:${APP_PORT}/cmd_safe?host=${ENCODED_CMD}")
  echo "  - Payload thu nghiem: ${CMD_PAYLOAD}"
  echo "  - Ket qua tu endpoint da phong thu:"
  echo "    ${SAFE_CMD_RESP}"

  if echo "$SAFE_CMD_RESP" | grep -q "HTTP_STATUS:400" && echo "$SAFE_CMD_RESP" | grep -q "Phat hien ky tu dac biet nguy hiem"; then
    echo "  [+] PHONG THU COMMAND INJECTION THANH CONG: Ky tu doc hai bi chan boi Whitelist Regex & shell=False."
  else
    echo "  [-] Phong thu Command Injection that bai."
    fail=1
  fi

  echo
  if [[ "$fail" -eq 0 ]]; then
    echo "LAB05_VERIFY=PASS"
  else
    echo "LAB05_VERIFY=FAIL"
  fi
} 2>&1 | tee "$LOG"

if grep -q 'LAB05_VERIFY=PASS' "$LOG"; then
  pass "Kiem chung phong thu AppSec (SQLi & RCE) tren Lab 99: PASS"
  fail=0
else
  bad "Kiem chung phong thu AppSec (SQLi & RCE) tren Lab 99: FAIL"
  fail=1
fi

{
  echo "method=Lab05_AppSec_SQLi_PreparedStatements_And_CommandInjection_Sanitization"
  echo "target=${IP_TARGET}:${APP_PORT}"
  echo "assessor=${IP_ASSESSOR}"
  echo "log=$LOG"
  if [[ "$fail" -eq 0 ]]; then echo "result=PASS"; else echo "result=FAIL"; fi
} | tee "$SUMMARY"

echo
exit "$fail"
