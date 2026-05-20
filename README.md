# Self-Hosted Git (Minimal)

Git server pribadi. Push, pull, lihat commit history — selesai.

## Setup (1 command)

```bash
# Upload folder ini ke VPS, lalu:
sudo ./setup.sh git.domainmu.com
```

Syarat:
- Domain sudah pointing ke IP VPS (A record)
- VPS Ubuntu/Debian dengan akses root

## Setelah Setup

1. Buka `https://git.domainmu.com`
2. Buat admin account (pertama kali)
3. Buat repository
4. Push code:

```bash
git remote add origin https://git.domainmu.com/username/repo.git
git push -u origin main
```

Atau via SSH:
```bash
git remote add origin ssh://git@git.domainmu.com:2222/username/repo.git
git push -u origin main
```

## Fitur

- ✅ git push / pull / clone
- ✅ Commit history (web UI)
- ✅ File browser
- ✅ HTTPS + SSH
- ✅ Private by default (registration disabled)

## Maintenance

```bash
# Update Gitea
docker compose pull && docker compose up -d

# Backup (copy folder data)
tar czf backup.tar.gz data/

# Lihat logs
docker compose logs -f
```
