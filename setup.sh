#!/bin/bash
set -e

echo "=== Installing Docker ==="
curl -fsSL https://get.docker.com | sh

echo "=== Starting Gitea ==="
docker compose up -d

IP=$(curl -s ifconfig.me)

echo ""
echo "=== DONE ==="
echo ""
echo "Buka http://$IP:3000"
echo "Git SSH: ssh://git@$IP:2222"
echo ""
