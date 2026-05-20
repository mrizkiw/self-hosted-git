#!/bin/bash
set -e

# ============================================================
# Self-Hosted Git Server Setup Script
# Menginstall semua dependencies dan deploy Gitea + Nginx + SSL
# ============================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Script ini harus dijalankan sebagai root (gunakan sudo)"
    exit 1
fi

echo "============================================"
echo "  Self-Hosted Git Server Setup"
echo "============================================"
echo ""

# ---- Step 1: Get configuration ----
if [ -f .env ]; then
    source .env
    print_status "Loaded configuration from .env"
else
    print_error "File .env tidak ditemukan!"
    echo "Copy .env.example ke .env dan isi konfigurasinya:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    exit 1
fi

# Validate required variables
if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "git.yourdomain.com" ]; then
    print_error "DOMAIN belum dikonfigurasi di .env"
    exit 1
fi

if [ "$DB_PASSWORD" = "change_this_to_a_strong_password" ]; then
    print_error "DB_PASSWORD belum diganti di .env"
    exit 1
fi

if [ "$SECRET_KEY" = "change_this_generate_with_openssl_rand_hex_32" ]; then
    print_error "SECRET_KEY belum digenerate. Jalankan: openssl rand -hex 32"
    exit 1
fi

print_status "Configuration validated for domain: $DOMAIN"

# ---- Step 2: Update system ----
print_status "Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

# ---- Step 3: Install Docker ----
if ! command -v docker &> /dev/null; then
    print_status "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    print_status "Docker installed successfully"
else
    print_status "Docker already installed"
fi

# ---- Step 4: Install Docker Compose ----
if ! command -v docker compose &> /dev/null; then
    print_status "Installing Docker Compose plugin..."
    apt-get install -y -qq docker-compose-plugin
    print_status "Docker Compose installed successfully"
else
    print_status "Docker Compose already installed"
fi

# ---- Step 5: Install Nginx ----
if ! command -v nginx &> /dev/null; then
    print_status "Installing Nginx..."
    apt-get install -y -qq nginx
    systemctl enable nginx
    print_status "Nginx installed successfully"
else
    print_status "Nginx already installed"
fi

# ---- Step 6: Install Certbot ----
if ! command -v certbot &> /dev/null; then
    print_status "Installing Certbot..."
    apt-get install -y -qq certbot python3-certbot-nginx
    print_status "Certbot installed successfully"
else
    print_status "Certbot already installed"
fi

# ---- Step 7: Configure Firewall ----
print_status "Configuring firewall (UFW)..."
apt-get install -y -qq ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 2222/tcp  # Git SSH
ufw --force enable
print_status "Firewall configured (SSH, HTTP, HTTPS, Git SSH)"

# ---- Step 8: Setup Nginx configuration ----
print_status "Configuring Nginx..."
sed "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" nginx/gitea.conf > /etc/nginx/sites-available/gitea
ln -sf /etc/nginx/sites-available/gitea /etc/nginx/sites-enabled/gitea
rm -f /etc/nginx/sites-enabled/default

# Test nginx config (tanpa SSL dulu)
# Buat temporary config tanpa SSL untuk initial setup
cat > /etc/nginx/sites-available/gitea-temp << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/gitea-temp /etc/nginx/sites-enabled/gitea
mkdir -p /var/www/certbot
nginx -t && systemctl restart nginx
print_status "Nginx configured (temporary HTTP-only)"

# ---- Step 9: Get SSL Certificate ----
print_status "Obtaining SSL certificate for $DOMAIN..."
certbot certonly --webroot -w /var/www/certbot \
    -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    --email "admin@$DOMAIN" \
    --no-eff-email

# Now switch to full SSL config
sed "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" nginx/gitea.conf > /etc/nginx/sites-available/gitea
ln -sf /etc/nginx/sites-available/gitea /etc/nginx/sites-enabled/gitea
nginx -t && systemctl restart nginx
print_status "SSL certificate obtained and Nginx configured with HTTPS"

# ---- Step 10: Setup auto-renewal for SSL ----
print_status "Setting up SSL auto-renewal..."
cat > /etc/cron.d/certbot-renew << EOF
0 3 * * * root certbot renew --quiet --post-hook "systemctl reload nginx"
EOF
print_status "SSL auto-renewal configured (daily check at 3 AM)"

# ---- Step 11: Start Gitea ----
print_status "Starting Gitea..."
docker compose up -d
print_status "Gitea is starting up..."

# Wait for Gitea to be ready
echo -n "Waiting for Gitea to be ready"
for i in {1..30}; do
    if curl -s http://127.0.0.1:3000 > /dev/null 2>&1; then
        echo ""
        print_status "Gitea is ready!"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# ---- Step 12: Create admin user ----
echo ""
print_warning "PENTING: Buat admin user dengan command berikut:"
echo ""
echo "  docker exec -it gitea gitea admin user create \\"
echo "    --username admin \\"
echo "    --password YOUR_SECURE_PASSWORD \\"
echo "    --email admin@$DOMAIN \\"
echo "    --admin"
echo ""

# ---- Done! ----
echo ""
echo "============================================"
echo -e "  ${GREEN}Setup Complete!${NC}"
echo "============================================"
echo ""
echo "  Web UI:    https://$DOMAIN"
echo "  Git SSH:   ssh://git@$DOMAIN:2222"
echo "  Git HTTP:  https://$DOMAIN/user/repo.git"
echo ""
echo "  Next steps:"
echo "  1. Buat admin user (lihat command di atas)"
echo "  2. Login ke https://$DOMAIN"
echo "  3. Buat repository pertama"
echo "  4. Setup SSH key di profile settings"
echo ""
echo "  Backup:    ./scripts/backup.sh"
echo "  Restore:   ./scripts/restore.sh <backup_file>"
echo ""
print_status "Selesai! Server git kamu sudah siap digunakan."
