#!/usr/bin/env python3
"""So sanh metrics before/after va sinh bao cao Markdown."""
from __future__ import annotations

import json
import sys
from pathlib import Path

KEYS = [
    ("lab99_score", "Diem lab99"),
    ("lynis_hardening_index", "Lynis hardening index"),
    ("ssh_port", "SSH port"),
    ("permit_rootlogin", "PermitRootLogin"),
    ("password_authentication", "PasswordAuthentication"),
    ("ufw", "UFW"),
    ("fail2ban_sshd", "Fail2ban sshd"),
    ("auditd", "Auditd"),
    ("unattended_upgrades", "Unattended upgrades"),
    ("rp_filter", "rp_filter"),
    ("tcp_syncookies", "tcp_syncookies"),
    ("aslr", "ASLR"),
    ("open_tcp_ports", "Open TCP ports"),
]


def load(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def main() -> int:
    if len(sys.argv) < 4:
        print(
            "Usage: compare_report.py metrics_before.json metrics_after.json out.md",
            file=sys.stderr,
        )
        return 1
    before = load(Path(sys.argv[1]))
    after = load(Path(sys.argv[2]))
    out = Path(sys.argv[3])

    lines = [
        "# Lab99 – Bao cao so sanh truoc/sau hardening",
        "",
        f"- Before: `{before.get('timestamp_utc', 'NA')}`",
        f"- After: `{after.get('timestamp_utc', 'NA')}`",
        "",
        "| Chi so | Truoc | Sau |",
        "|---|---|---|",
    ]
    for key, label in KEYS:
        lines.append(
            f"| {label} | {before.get(key, 'NA')} | {after.get(key, 'NA')} |"
        )

    b_score = int(before.get("lab99_score", 0) or 0)
    a_score = int(after.get("lab99_score", 0) or 0)
    delta = a_score - b_score
    lines.extend(
        [
            "",
            "## Ket luan",
            "",
            f"- Diem noi bo tang **{delta}** (tu {b_score} len {a_score}/"
            f"{after.get('lab99_score_max', 12)}).",
            "- Ky vong sau harden: SSH doi cong 2222, tat root/password login,",
            "  UFW + Fail2ban bat, sysctl/ASLR/auditd/unattended co mat.",
            "- Be mat cong hep hon; danh gia bang `surface_before.txt` / "
            "`surface_after.txt`.",
            "",
            "## Goi y minh chung bao cao",
            "",
            "1. Bang so sanh tren + file Lynis before/after.",
            "2. `nmap_before.txt` / `nmap_after.txt` + `validate_*.txt`.",
            "3. `sshd -T` (PermitRootLogin/PasswordAuthentication/Port).",
            "4. `ufw status`, `fail2ban-client status sshd`.",
            "5. Bang anh xa ky thuat cong khai: `audit/techniques_map.md`.",
            "",
        ]
    )
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {out}")
    print(f"SCORE_DELTA={delta} ({b_score} -> {a_score})")
    return 0 if a_score > b_score else 2


if __name__ == "__main__":
    raise SystemExit(main())
