#!/usr/bin/env python3
import socket
import sys

def run_server():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', 23))
    server.listen(128)
    print("[*] Telnet daemon listening on port 23...")
    sys.stdout.flush()
    while True:
        try:
            client, addr = server.accept()
            client.sendall(b"Ubuntu 20.04 LTS Telnet Server\r\nlogin: ")
            client.close()
        except Exception:
            pass

if __name__ == '__main__':
    run_server()
