#!/bin/bash
set -e

DOMAIN="$1"

if [ -z "$DOMAIN" ]; then
    echo "Usage: sudo ./setup.sh git.yourdomain.com"
    exit 1
fi

echo "=== Installing Docker ==="
curl -fsSL https://get.docker.com | sh

echo "=== Installing Nginx & Certbot ==="
apt-get install -y nginx certbot python3-certbot-nginx

echo "=== Getting SSL Certificate ==="
certbot certonly --standalone --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx" -d "$DOMAIN" --non-interactive --agree-tos --email admin@"$DOMAIN"

echo "=== Configuring Nginx ==="
sed "s/DOMAIN/$DOMAIN/g" nginx.conf > /etc/nginx/sites-enabled/gitea
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

echo "=== Starting Gitea ==="
export DOMAIN="$DOMAIN"
docker compose up -d

echo ""
echo "=== DONE ==="
echo ""
echo "Buka https://$DOMAIN untuk setup awal (buat admin account)"
echo "Git SSH: ssh://git@$DOMAIN:2222"
echo ""
