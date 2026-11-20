#!/usr/bin/env python3
"""
Lab99 Target Demo Application:
Cung cap dich vu Web va co so du lieu de kiem chung phong thu:
1. SQL Injection: Vulnerable (String concatenation) vs Safe (Parameterized Prepared Statements)
2. OS Command Injection: Vulnerable (shell=True) vs Safe (Whitelist Regex + shell=False)
"""

import http.server
import json
import os
import re
import sqlite3
import subprocess
import sys
import urllib.parse

DB_PATH = "/var/lib/lab99_db.sqlite"


def init_db():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("DROP TABLE IF EXISTS users")
    cur.execute(
        """
        CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE,
            password TEXT,
            role TEXT
        )
    """
    )
    cur.executemany(
        "INSERT INTO users (username, password, role) VALUES (?, ?, ?)",
        [
            ("admin", "AdminSecret123!", "administrator"),
            ("alice", "AlicePass456", "user"),
            ("bob", "BobPass789", "user"),
        ],
    )
    conn.commit()
    conn.close()


class Lab99Handler(http.server.BaseHTTPRequestHandler):

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)

        # 1. Health check
        if parsed.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"healthy","service":"lab99-target"}')
            return

        # 2. SQLi - Vulnerable endpoint
        if parsed.path == "/sqli_vuln":
            user_input = params.get("user", [""])[0]
            conn = sqlite3.connect(DB_PATH)
            cur = conn.cursor()
            query = f"SELECT id, username, role FROM users WHERE username = '{user_input}'"
            try:
                cur.execute(query)
                rows = cur.fetchall()
                data = {
                    "mode": "vulnerable",
                    "query_executed": query,
                    "count": len(rows),
                    "results": [
                        {"id": r[0], "username": r[1], "role": r[2]}
                        for r in rows
                    ],
                }
                status = 200
            except Exception as e:
                data = {"mode": "vulnerable", "error": str(e)}
                status = 500
            conn.close()

            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(data).encode("utf-8"))
            return

        # 3. SQLi - Safe endpoint (Prepared Statements)
        if parsed.path == "/sqli_safe":
            user_input = params.get("user", [""])[0]
            conn = sqlite3.connect(DB_PATH)
            cur = conn.cursor()
            query = "SELECT id, username, role FROM users WHERE username = ?"
            try:
                cur.execute(query, (user_input,))
                rows = cur.fetchall()
                data = {
                    "mode": "prepared_statement_safe",
                    "query_template": query,
                    "count": len(rows),
                    "results": [
                        {"id": r[0], "username": r[1], "role": r[2]}
                        for r in rows
                    ],
                }
                status = 200
            except Exception as e:
                data = {"mode": "prepared_statement_safe", "error": str(e)}
                status = 500
            conn.close()

            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(data).encode("utf-8"))
            return

        # 4. Command Injection - Vulnerable endpoint
        if parsed.path == "/cmd_vuln":
            host_input = params.get("host", ["127.0.0.1"])[0]
            # Loi: Noi chuoi truc tiep vao lenh shell
            cmd = f"ping -c 1 {host_input}"
            try:
                output = os.popen(cmd).read()
                data = {
                    "mode": "vulnerable_shell",
                    "command_executed": cmd,
                    "output": output,
                }
                status = 200
            except Exception as e:
                data = {"mode": "vulnerable_shell", "error": str(e)}
                status = 500

            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(data).encode("utf-8"))
            return

        # 5. Command Injection - Safe endpoint (Input Sanitization + shell=False)
        if parsed.path == "/cmd_safe":
            host_input = params.get("host", ["127.0.0.1"])[0]
            # Phong thu 1: Regex whitelist chi cho phep hostname/IP hop le
            if not re.match(r"^[0-9a-zA-Z.-]+$", host_input):
                data = {
                    "mode": "sanitized_safe",
                    "error": "Phat hien ky tu dac biet nguy hiem! Yeu cau bi tu choi.",
                    "status": "blocked",
                }
                status = 400
            else:
                # Phong thu 2: Truyen mang tham so, khong qua shell interpreter
                try:
                    res = subprocess.run(
                        ["ping", "-c", "1", host_input],
                        shell=False,
                        capture_output=True,
                        text=True,
                        timeout=3,
                    )
                    data = {
                        "mode": "sanitized_safe",
                        "output": res.stdout,
                        "status": "allowed",
                    }
                    status = 200
                except Exception as e:
                    data = {"mode": "sanitized_safe", "error": str(e)}
                    status = 500

            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(data).encode("utf-8"))
            return

        self.send_response(404)
        self.end_headers()
        self.wfile.write(b'{"error":"not_found"}')

    def log_message(self, format, *args):
        # Quiet logger
        pass


if __name__ == "__main__":
    init_db()
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    server = http.server.HTTPServer(("0.0.0.0", port), Lab99Handler)
    server.serve_forever()
