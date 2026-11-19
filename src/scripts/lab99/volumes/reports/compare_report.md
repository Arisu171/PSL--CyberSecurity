# Lab99 – Bao cao so sanh truoc/sau hardening

- Before: `20261119T154727Z`
- After: `20261119T155649Z`

| Chi so | Truoc | Sau |
|---|---|---|
| Diem lab99 | 5 | 12 |
| Lynis hardening index | NA | NA |
| SSH port | 22 | 2222 |
| PermitRootLogin | yes | no |
| PasswordAuthentication | yes | no |
| UFW | Status: inactive | Status: active |
| Fail2ban sshd | inactive | active |
| Auditd | no | yes |
| Unattended upgrades | yes | yes |
| rp_filter | 0 | 1 |
| tcp_syncookies | 1 | 1 |
| ASLR | 2 | 2 |
| Open TCP ports | 22,37467 | 2222,37467 |

## Ket luan

- Diem noi bo tang **7** (tu 5 len 12/12).
- Ky vong sau harden: SSH doi cong 2222, tat root/password login,
  UFW + Fail2ban bat, sysctl/ASLR/auditd/unattended co mat.
- Be mat cong hep hon; danh gia bang `surface_before.txt` / `surface_after.txt`.

## Goi y minh chung bao cao

1. Bang so sanh tren + file Lynis before/after.
2. `nmap_before.txt` / `nmap_after.txt` + `validate_*.txt`.
3. `sshd -T` (PermitRootLogin/PasswordAuthentication/Port).
4. `ufw status`, `fail2ban-client status sshd`.
5. Bang anh xa ky thuat cong khai: `audit/techniques_map.md`.
