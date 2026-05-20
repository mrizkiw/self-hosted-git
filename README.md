# Self-Hosted Git (Minimal, No Domain)

Git server pribadi. Akses via IP. Push, pull, lihat commit history.

## Setup

```bash
# Upload folder ini ke VPS, lalu:
sudo ./setup.sh
```

Itu saja. Tidak perlu domain, tidak perlu SSL, tidak perlu Nginx.

## Setelah Setup

1. Buka `http://IP_VPS:3000`
2. Buat admin account (pertama kali)
3. Buat repository
4. Push code:

```bash
git remote add origin http://IP_VPS:3000/username/repo.git
git push -u origin main
```

Atau via SSH:
```bash
git remote add origin ssh://git@IP_VPS:2222/username/repo.git
git push -u origin main
```

## Maintenance

```bash
# Update Gitea
docker compose pull && docker compose up -d

# Backup (copy folder data)
tar czf backup.tar.gz data/

# Lihat logs
docker compose logs -f
```
