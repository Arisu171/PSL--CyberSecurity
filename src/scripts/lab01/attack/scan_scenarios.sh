#!/bin/bash
# Script thuc thi tu dong cac kich ban quet mang cho Lab 01 (Attack Scenarios)
# Su dung cac ky thuat: ARP Ping Scan, TCP SYN Scan, TCP ACK Scan, Mail Server Recon.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET_IP="${1:-192.168.117.13}"
TARGET_NET="${2:-192.168.117.0/24}"
MAIL_TARGET="${3:-192.168.100.20}"

echo "=========================================================="
echo "   LAB 01: NMAP SCANNING AUTOMATION - ATTACK MODULE       "
echo "   Target IP:   $TARGET_IP"
echo "   Target Net:  $TARGET_NET"
echo "   Mail Target: $MAIL_TARGET"
echo "=========================================================="

echo -e "\n[1/4] Thuc hien ARP Ping Scan (nmap -sn)..."
sudo nmap -sn "$TARGET_NET"

echo -e "\n[2/4] Thuc hien TCP SYN Scan (nmap -sS -F)..."
sudo nmap -sS -F "$TARGET_IP"

echo -e "\n[3/4] Thuc hien TCP ACK Scan (nmap -sA -F)..."
sudo nmap -sA -F "$TARGET_IP"

echo -e "\n[4/4] Thuc hien Do tham May chu Mail (Ports, OS, Service)..."
sudo nmap -p 25,110,143,465,587,993,995 --open "$TARGET_NET" || true
sudo nmap -sV -O "$TARGET_IP" || true

echo -e "\n[✓] Hoan thanh tat ca kich ban quet tham do mang!"
