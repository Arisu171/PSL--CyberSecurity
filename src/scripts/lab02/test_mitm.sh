#!/bin/bash
sudo docker exec lab02_user ip neigh flush all
sudo docker exec lab02_server ip neigh flush all
sudo docker exec lab02_attacker ip neigh flush all

# 1. Thu nghiem binh thuong truoc tan cong
sudo docker exec -d lab02_server sh -c 'nc -lp 10101 > /tmp/nc_normal.txt'
sleep 1
sudo docker exec lab02_user sh -c 'echo "Hello Server from Nguyen Bao Long 223001756" | nc -w 2 10.2.6.20 10101'
sleep 1
echo "=== TRUOC TAN CONG ==="
sudo docker exec lab02_server cat /tmp/nc_normal.txt

# 2. Thu nghiem khi co tan cong MITM
sudo docker exec lab02_attacker sysctl net.ipv4.ip_forward=1
sudo docker exec lab02_attacker iptables -A FORWARD -p tcp --dport 10101 -j DROP 2>/dev/null || true
sudo docker exec -d lab02_attacker python3 /attack/mitm.py
sleep 3

sudo docker exec -d lab02_server sh -c 'nc -lp 10101 > /tmp/nc_mitm.txt'
sleep 1
sudo docker exec lab02_user sh -c 'echo "Hello Server from Nguyen Bao Long 223001756" | nc -w 3 10.2.6.20 10101'
sleep 2

echo "=== SAU KHI BI MITM ==="
sudo docker exec lab02_server cat /tmp/nc_mitm.txt
sudo docker exec lab02_attacker pkill -f mitm.py || true

