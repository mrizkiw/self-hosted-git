#!/bin/bash
set -e

echo "=== Setting up Gitea ==="

# Install Docker hanya jika belum ada
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
else
    echo "Docker already installed, skipping..."
fi

echo "=== Starting Gitea ==="
docker compose up -d

IP=$(curl -s ifconfig.me)

echo ""
echo "=== DONE ==="
echo ""
echo "Buka http://$IP:3000"
echo "Git SSH: ssh://git@$IP:2222"
echo ""
