#!/bin/bash
# Dung va giai phong toan bo container va mang cua Lab 04

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAB="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_LAB}/docker-compose.yml"

if [[ -f "$COMPOSE_FILE" ]]; then
  echo "[-] Dang tat Lab 04 containers..."
  sudo docker compose -f "$COMPOSE_FILE" --project-directory "$PROJECT_LAB" down
fi

sudo docker network rm net-10.2.6.0 2>/dev/null || true
echo "[✓] DA GIAI PHONG SUBNET 10.2.6.0/24 VA HA LAB 04."
