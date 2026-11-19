#!/usr/bin/env python3
"""
Lightweight Web Server for Lab 05 (SQL Injection)
Supports both vulnerable endpoints (sqli1.php, sqli2.php) and fixed versions (sqli1_fixed.php, sqli2_fixed.php).
Includes simulated MySQL engine matching webvul database.
"""

import sys
import os
import re
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 80
DB_NAME = "webvul"
DB_VERSION = "10.5.15-MariaDB"

# Initial database products
PRODUCTS = [
    {"id": 1, "vendor": "HP", "model": "Probook 450 G3", "price": "500", "category": "laptop"},
    {"id": 3, "vendor": "Dell", "model": "XPS 13", "price": "1000", "category": "laptop"},
    {"id": 4, "vendor": "Dell", "model": "Precision M7510", "price": "1500", "category": "laptop"},
    {"id": 5, "vendor": "Apple", "model": "Macbook Retina 2017", "price": "2000", "category": "laptop"},
    {"id": 6, "vendor": "Secret", "model": "Secret 2017", "price": "10000000", "category": "secret"},
    {"id": 7, "vendor": "Logitech", "model": "M150", "price": "20", "category": "mouse"},
    {"id": 8, "vendor": "Genius", "model": "G400", "price": "70", "category": "keyboard"},
]

class SQLiHandler(BaseHTTPRequestHandler):
    def _send_html(self, content, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(content.encode("utf-8"))))
        self.end_headers()
        self.wfile.write(content.encode("utf-8"))

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        # Serve static HTML files if present
        if path.endswith(".html"):
            filename = os.path.basename(path)
            local_path = os.path.join(os.path.dirname(__file__), filename)
            if os.path.exists(local_path):
                with open(local_path, "r", encoding="utf-8") as f:
                    return self._send_html(f.read())
            return self._send_html(f"<h1>404 Not Found: {filename}</h1>", 404)

        # Endpoint: sqli1.php (Vulnerable SELECT)
        if path.endswith("/sqli1.php"):
            cat = query.get("cat", [""])[0]
            html = self.handle_sqli1(cat)
            return self._send_html(html)

        # Endpoint: sqli1_fixed.php (Fixed SELECT)
        if path.endswith("/sqli1_fixed.php"):
            cat = query.get("cat", [""])[0]
            html = self.handle_sqli1_fixed(cat)
            return self._send_html(html)

        # Default redirect / 404
        self._send_html("<h3>Lab 05 SQL Injection Target Server</h3><p><a href='/sqli/sqli1.html'>Example 1</a> | <a href='/sqli/sqli2.html'>Example 2</a></p>")

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8", errors="replace")
        data = urllib.parse.parse_qs(body)

        cat = data.get("cat", [""])[0]
        vendor = data.get("vendor", [""])[0]
        model = data.get("model", [""])[0]
        price = data.get("price", [""])[0]

        if path.endswith("/sqli2.php"):
            html = self.handle_sqli2(cat, vendor, model, price)
            return self._send_html(html)

        if path.endswith("/sqli2_fixed.php"):
            html = self.handle_sqli2_fixed(cat, vendor, model, price)
            return self._send_html(html)

        self._send_html("404 Not Found", 404)

    def handle_sqli1(self, cat):
        # Header template
        out = "<!doctype html><html><body><div class='container'>"
        
        # Check syntax error on unclosed single quote
        # E.g. cat=laptop' without comment
        if "'" in cat and not any(c in cat for c in ["#", "--", ";"]):
            out += "You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near '\\'' at line 1"
            out += "</div></body></html>"
            return out

        # Check ORDER BY injection
        order_match = re.search(r"order\s+by\s+(\d+)", cat, re.IGNORECASE)
        if order_match:
            col_num = int(order_match.group(1))
            if col_num > 4:
                out += f"Unknown column '{col_num}' in 'order clause'"
                out += "</div></body></html>"
                return out

        # Check UNION SELECT injection
        if "union" in cat.lower() and "select" in cat.lower():
            out += "<h4>-- Product Information -- </h4>"
            # Return injected union payload
            v_val = DB_NAME if "database()" in cat.lower() else "1"
            out += f"<p>Vendor : {v_val}</p>"
            out += "<p>Model : 3</p>"
            out += "<p>Price :4$</p>"
            out += "--------------------------------------------"
            out += "</div></body></html>"
            return out

        # Check Boolean-based blind injection
        # E.g. cat=laptop' and substring(database(),1,1)='w';#
        if "substring" in cat.lower():
            if "'w'" in cat or '"w"' in cat:
                # TRUE: display products
                items = [p for p in PRODUCTS if p["category"] == "laptop"]
            else:
                # FALSE: return empty
                items = []
        elif "or" in cat.lower() and ("1" in cat or "'1'='1'" in cat):
            # Tautology: display ALL products
            items = PRODUCTS
        else:
            clean_cat = cat.split("'")[0].strip()
            items = [p for p in PRODUCTS if p["category"] == clean_cat]

        if items:
            out += "<h4>-- Product Information -- </h4>"
            for row in items:
                out += f"<p>Vendor : {row['vendor']}</p>"
                out += f"<p>Model : {row['model']}</p>"
                out += f"<p>Price :{row['price']}$</p>"
                out += "--------------------------------------------"
        out += "</div></body></html>"
        return out

    def handle_sqli1_fixed(self, cat):
        out = "<!doctype html><html><body><div class='container'>"
        # Prepared statement strictly matches category
        items = [p for p in PRODUCTS if p["category"] == cat]
        if items:
            out += "<h4>-- Product Information -- </h4>"
            for row in items:
                out += f"<p>Vendor : {row['vendor']}</p>"
                out += f"<p>Model : {row['model']}</p>"
                out += f"<p>Price :{row['price']}$</p>"
                out += "--------------------------------------------"
        else:
            out += "<p>No products found in this category.</p>"
        out += "</div></body></html>"
        return out

    def handle_sqli2(self, cat, vendor, model, price):
        # Check syntax error on unclosed quote in vendor
        if "'" in vendor and not any(c in vendor for c in ["#", "--", ";", ")"]):
            return "You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near ')' at line 1"

        # Check SQL injection break out
        if "database()" in vendor.lower():
            new_item = {"id": len(PRODUCTS)+1, "vendor": "anyVendor", "model": DB_NAME, "price": "2", "category": "3"}
            PRODUCTS.append(new_item)
        elif "version()" in vendor.lower():
            new_item = {"id": len(PRODUCTS)+1, "vendor": "anyVendor", "model": DB_VERSION, "price": "2", "category": "3"}
            PRODUCTS.append(new_item)
        elif "anyvendor" in vendor.lower() and ("#" in vendor or ";" in vendor):
            new_item = {"id": len(PRODUCTS)+1, "vendor": "anyVendor", "model": "1", "price": "2", "category": "3"}
            PRODUCTS.append(new_item)
        else:
            new_item = {"id": len(PRODUCTS)+1, "vendor": vendor, "model": model, "price": price, "category": cat}
            PRODUCTS.append(new_item)

        return self._render_product_table()

    def handle_sqli2_fixed(self, cat, vendor, model, price):
        # Prepared statement safely parameterizes all values
        new_item = {"id": len(PRODUCTS)+1, "vendor": vendor, "model": model, "price": price, "category": cat}
        PRODUCTS.append(new_item)
        return self._render_product_table()

    def _render_product_table(self):
        out = "<!doctype html><html><body><center><h3>Product list:</h3><table>"
        out += "<tr height='30' bgcolor='#066923' align='center'>"
        out += "<td width='150'><b>Category</b></td><td width='150'><b>Vendor</b></td><td width='200'><b>Model</b></td><td width='100'><b>Price</b></td></tr>"
        for p in PRODUCTS:
            out += f"<tr height='40'><td>{p['category']}</td><td>{p['vendor']}</td><td>{p['model']}</td><td>{p['price']}</td></tr>"
        out += "</table></center></body></html>"
        return out

    def log_message(self, format, *args):
        pass # Quiet mode

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), SQLiHandler)
    print(f"[*] Lab 05 SQL Injection Web Server running on port {PORT}...")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("[!] Stopping server.")
        server.server_close()
