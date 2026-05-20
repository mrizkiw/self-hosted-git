# Self-Hosted Git Server

Server Git pribadi menggunakan **Gitea** — alternatif GitHub yang ringan, aman, dan sepenuhnya dalam kendali kamu.

## Kenapa Self-Hosted?

- **Privasi penuh** — kode hanya ada di server kamu
- **Tidak bergantung** pada layanan pihak ketiga
- **Kontrol penuh** atas keamanan dan akses
- **Tidak ada batasan** repository private
- **Backup** sesuai keinginan kamu

## Arsitektur

```
Internet
    │
    ├── HTTPS (443) ──→ Nginx ──→ Gitea (port 3000)
    │
    └── SSH (2222) ──→ Gitea SSH
    
Docker Containers:
    ├── gitea (application)
    └── gitea-db (PostgreSQL)
```

## Prerequisites

- VPS dengan minimal 1GB RAM (recommended 2GB)
- Ubuntu 22.04 / Debian 12
- Domain yang sudah di-pointing ke IP VPS (A record)
- Akses root ke VPS

## Quick Start

### 1. Clone/Upload ke VPS

```bash
# Upload folder ini ke VPS
scp -r self-hosted-git/ root@YOUR_VPS_IP:/opt/self-hosted-git

# Atau clone jika sudah di repo
ssh root@YOUR_VPS_IP
cd /opt
git clone <your-repo> self-hosted-git
```

### 2. Konfigurasi

```bash
cd /opt/self-hosted-git

# Copy dan edit konfigurasi
cp .env.example .env
nano .env
```

Edit `.env` dengan nilai yang sesuai:

```env
DOMAIN=git.yourdomain.com
DB_PASSWORD=<password_kuat>
SECRET_KEY=<hasil dari: openssl rand -hex 32>
INTERNAL_TOKEN=<hasil dari: openssl rand -hex 32>
DISABLE_REGISTRATION=true
```

### 3. Pointing Domain

Pastikan domain sudah di-pointing ke IP VPS:

| Type | Name | Value |
|------|------|-------|
| A | git | IP_VPS_KAMU |

Tunggu propagasi DNS (biasanya 5-15 menit).

### 4. Jalankan Setup

```bash
chmod +x scripts/*.sh
sudo ./scripts/setup.sh
```

Script akan otomatis:
- Install Docker, Nginx, Certbot
- Setup firewall (UFW)
- Konfigurasi Nginx reverse proxy
- Generate SSL certificate (Let's Encrypt)
- Start Gitea + PostgreSQL
- Setup auto-renewal SSL

### 5. Buat Admin User

```bash
docker exec -it gitea gitea admin user create \
    --username admin \
    --password YOUR_SECURE_PASSWORD \
    --email admin@yourdomain.com \
    --admin
```

### 6. Akses

- **Web UI**: https://git.yourdomain.com
- **Git SSH**: `git clone ssh://git@git.yourdomain.com:2222/user/repo.git`
- **Git HTTPS**: `git clone https://git.yourdomain.com/user/repo.git`

## Penggunaan Sehari-hari

### Clone Repository

```bash
# Via HTTPS
git clone https://git.yourdomain.com/username/repo.git

# Via SSH (setelah setup SSH key di profile)
git clone ssh://git@git.yourdomain.com:2222/username/repo.git
```

### Migrasi dari GitHub

1. Login ke Gitea
2. Klik **"+"** → **"New Migration"**
3. Pilih **GitHub**
4. Masukkan URL repository
5. Jika private, masukkan GitHub Personal Access Token
6. Klik **"Migrate Repository"**

Atau via API:
```bash
curl -X POST "https://git.yourdomain.com/api/v1/repos/migrate" \
    -H "Authorization: token YOUR_GITEA_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "clone_addr": "https://github.com/username/repo.git",
        "auth_token": "GITHUB_PAT",
        "repo_name": "repo",
        "mirror": false,
        "private": true
    }'
```

### Setup SSH Key

```bash
# Generate SSH key (jika belum punya)
ssh-keygen -t ed25519 -C "your@email.com"

# Copy public key
cat ~/.ssh/id_ed25519.pub
```

Paste di: **Settings** → **SSH / GPG Keys** → **Add Key**

### Konfigurasi SSH Client

Tambahkan di `~/.ssh/config`:

```
Host gitea
    HostName git.yourdomain.com
    Port 2222
    User git
    IdentityFile ~/.ssh/id_ed25519
```

Sekarang bisa clone dengan:
```bash
git clone gitea:username/repo.git
```

## Backup & Restore

### Manual Backup

```bash
cd /opt/self-hosted-git
sudo ./scripts/backup.sh
```

### Automated Backup (Daily)

```bash
sudo cp cron/gitea-backup /etc/cron.d/gitea-backup
```

Backup otomatis setiap hari jam 2 pagi, menyimpan 7 backup terakhir.

### Restore

```bash
sudo ./scripts/restore.sh backups/gitea_backup_20240101_020000.tar.gz
```

### Offsite Backup (Recommended)

Tambahkan sync ke cloud storage setelah backup:

```bash
# Contoh: sync ke Backblaze B2
b2 sync /opt/self-hosted-git/backups/ b2://your-bucket/gitea-backups/

# Contoh: sync ke remote server
rsync -avz /opt/self-hosted-git/backups/ user@backup-server:/backups/gitea/
```

## Maintenance

### Update Gitea

```bash
cd /opt/self-hosted-git

# Backup dulu!
sudo ./scripts/backup.sh

# Pull image terbaru
docker compose pull

# Restart
docker compose up -d
```

### Lihat Logs

```bash
# Semua logs
docker compose logs -f

# Hanya Gitea
docker compose logs -f gitea

# Hanya database
docker compose logs -f db
```

### Restart Services

```bash
docker compose restart
```

### Disk Usage

```bash
# Cek ukuran data Gitea
docker exec gitea du -sh /var/lib/gitea/

# Cek ukuran database
docker exec gitea-db psql -U gitea -c "SELECT pg_size_pretty(pg_database_size('gitea'));"
```

## Security Hardening

### Yang Sudah Termasuk

- ✅ HTTPS dengan Let's Encrypt (auto-renewal)
- ✅ Firewall (UFW) — hanya port yang diperlukan terbuka
- ✅ Registration disabled by default
- ✅ Require sign-in to view content
- ✅ Security headers di Nginx
- ✅ PostgreSQL tidak exposed ke public
- ✅ Gitea rootless container

### Tambahan yang Disarankan

1. **Fail2Ban** untuk brute-force protection:
```bash
apt install fail2ban
# Konfigurasi untuk Gitea akan ditambahkan nanti
```

2. **SSH key-only authentication** di VPS:
```bash
# Disable password auth
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
```

3. **2FA** — aktifkan di Gitea Settings → Security → Two-Factor Authentication

4. **IP Whitelist** (jika hanya diakses dari IP tertentu):
```nginx
# Tambahkan di nginx config
allow 1.2.3.4;  # IP kantor
allow 5.6.7.8;  # IP rumah
deny all;
```

## Struktur File

```
self-hosted-git/
├── .env.example          # Template konfigurasi
├── docker-compose.yml    # Container orchestration
├── nginx/
│   └── gitea.conf        # Nginx reverse proxy config
├── scripts/
│   ├── setup.sh          # Main setup script
│   ├── backup.sh         # Backup script
│   └── restore.sh        # Restore script
├── cron/
│   └── gitea-backup      # Cron job untuk auto backup
├── backups/              # Backup files (auto-created)
└── README.md             # Dokumentasi ini
```

## Troubleshooting

### Gitea tidak bisa diakses

```bash
# Cek status container
docker compose ps

# Cek logs
docker compose logs gitea

# Cek nginx
systemctl status nginx
nginx -t
```

### SSL certificate error

```bash
# Renew manual
certbot renew --force-renewal
systemctl reload nginx
```

### Database connection error

```bash
# Cek database container
docker compose logs db

# Restart database
docker compose restart db
```

### Port 2222 tidak bisa diakses

```bash
# Cek firewall
ufw status

# Pastikan port terbuka
ufw allow 2222/tcp
```

## Perbandingan dengan GitHub

| Fitur | GitHub (Free) | Self-Hosted Gitea |
|-------|--------------|-------------------|
| Private repos | Unlimited | Unlimited |
| Collaborators | Unlimited | Unlimited |
| Storage | 500MB/repo | Sesuai disk VPS |
| CI/CD | GitHub Actions | Gitea Actions / Drone |
| Data ownership | GitHub | Kamu sendiri |
| Uptime | 99.9% SLA | Tergantung VPS |
| Biaya | $0 (limited) | ~$5-10/bulan VPS |
| Breach risk | Third-party | Kamu yang kontrol |
