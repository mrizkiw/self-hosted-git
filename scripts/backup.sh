#!/bin/bash
set -e

# ============================================================
# Backup Script untuk Self-Hosted Git Server
# Backup repositories, database, dan konfigurasi
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="gitea_backup_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Load environment
if [ -f "${PROJECT_DIR}/.env" ]; then
    source "${PROJECT_DIR}/.env"
fi

# Retention: keep last N backups (default 7)
RETENTION_COUNT=${BACKUP_RETENTION:-7}

echo "============================================"
echo "  Gitea Backup - $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""

# Create backup directory
mkdir -p "$BACKUP_PATH"

# ---- Step 1: Backup PostgreSQL database ----
print_status "Backing up PostgreSQL database..."
docker exec gitea-db pg_dump -U gitea gitea | gzip > "${BACKUP_PATH}/database.sql.gz"
print_status "Database backup complete"

# ---- Step 2: Backup Gitea data (repositories, LFS, avatars, etc) ----
print_status "Backing up Gitea data..."
docker exec gitea sh -c 'cd /var/lib/gitea && tar czf - .' > "${BACKUP_PATH}/gitea_data.tar.gz"
print_status "Gitea data backup complete"

# ---- Step 3: Backup Gitea configuration ----
print_status "Backing up Gitea configuration..."
docker exec gitea sh -c 'cd /etc/gitea && tar czf - .' > "${BACKUP_PATH}/gitea_config.tar.gz"
print_status "Configuration backup complete"

# ---- Step 4: Backup docker-compose and .env ----
print_status "Backing up deployment files..."
cp "${PROJECT_DIR}/docker-compose.yml" "${BACKUP_PATH}/"
if [ -f "${PROJECT_DIR}/.env" ]; then
    cp "${PROJECT_DIR}/.env" "${BACKUP_PATH}/"
fi
print_status "Deployment files backup complete"

# ---- Step 5: Create final archive ----
print_status "Creating final archive..."
cd "$BACKUP_DIR"
tar czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_PATH"
print_status "Final archive: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"

# ---- Step 6: Calculate size ----
BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
print_status "Backup size: $BACKUP_SIZE"

# ---- Step 7: Cleanup old backups ----
print_status "Cleaning up old backups (keeping last $RETENTION_COUNT)..."
cd "$BACKUP_DIR"
ls -t gitea_backup_*.tar.gz 2>/dev/null | tail -n +$((RETENTION_COUNT + 1)) | xargs -r rm -f
REMAINING=$(ls gitea_backup_*.tar.gz 2>/dev/null | wc -l)
print_status "Remaining backups: $REMAINING"

echo ""
echo "============================================"
echo -e "  ${GREEN}Backup Complete!${NC}"
echo "============================================"
echo ""
echo "  File: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "  Size: $BACKUP_SIZE"
echo ""
echo "  Untuk restore, jalankan:"
echo "  ./scripts/restore.sh backups/${BACKUP_NAME}.tar.gz"
echo ""
