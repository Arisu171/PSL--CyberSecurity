#!/bin/bash
set -u
mkdir -p /var/run/sshd /volumes/reports /volumes/logs
service ssh start || /usr/sbin/sshd
# auditd/fail2ban se bat khi harden; baseline chi can SSH.
exec tail -f /dev/null
