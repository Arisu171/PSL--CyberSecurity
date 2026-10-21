#!/bin/bash
set -e

echo "=== [1/4] Cai dat Docker va Docker Compose ==="
sudo apt-get update
sudo apt-get install -y docker.io docker-compose wireshark tshark tcpdump net-tools

sudo usermod -aG docker $USER || true

echo "=== [2/4] Cau hinh aliases vao ~/.bashrc ==="
if ! grep -q "dockps" ~/.bashrc; then
    cat << 'EOF' >> ~/.bashrc

alias dockps='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
docksh() {
    docker exec -it "$1" /bin/bash
}
EOF
fi

echo "=== [3/4] Build va khoi chay cac container ==="
cd ~/it4263lab/lab02
sudo docker-compose down 2>/dev/null || true
sudo docker-compose build
sudo docker-compose up -d

echo "=== [4/4] Kiem tra container ==="
sudo docker ps
