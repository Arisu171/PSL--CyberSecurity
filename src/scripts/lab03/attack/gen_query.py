#!/usr/bin/env python3
from scapy.all import IP, UDP, DNS, DNSQR

IP_packet = IP(dst="10.2.6.53", src="10.2.6.1")
UDP_packet = UDP(dport=53, sport=12345, chksum=0)
Qdsec = DNSQR(qname='twysw.example.com')
dns = DNS(id=0xAAAA, qr=0, qdcount=1, ancount=0, nscount=0, arcount=0, qd=Qdsec)

pkt = IP_packet/UDP_packet/dns
with open('ip_req.bin', 'wb') as f:
    f.write(bytes(pkt))

print("Created ip_req.bin successfully.")

