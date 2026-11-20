#!/bin/bash
set -u
mkdir -p /var/run/sshd /volumes/reports /volumes/logs
service ssh start || /usr/sbin/sshd
# Khoi chay ung dung web demo kiem chung SQLi
python3 /usr/local/bin/lab99_app.py 8080 > /volumes/logs/lab99_app.log 2>&1 &
exec tail -f /dev/null
