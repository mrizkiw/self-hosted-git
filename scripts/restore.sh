#!/bin/bash
set -e

# ============================================================
# Restore Script untuk Self-Hosted Git Server
# Restore dari backup file
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check argument
if [ -z "$1" ]; then
    print_error "Usage: $0 <backup_file.tar.gz>"
    echo ""
    echo "Available backups:"
    ls -la "${PROJECT_DIR}/backups/"gitea_backup_*.tar.gz 2>/dev/null || echo "  No backups found"
    exit 1
fi

BACKUP_FILE="$1"

# Resolve relative path
if [[ ! "$BACKUP_FILE" = /* ]]; then
    BACKUP_FILE="${PROJECT_DIR}/${BACKUP_FILE}"
fi

if [ ! -f "$BACKUP_FILE" ]; then
    print_error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "============================================"
echo "  Gitea Restore - $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""
print_warning "PERINGATAN: Ini akan menimpa data yang ada saat ini!"
echo ""
read -p "Lanjutkan restore? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Restore dibatalkan."
    exit 0
fi

# Create temp directory for extraction
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# ---- Step 1: Extract backup ----
print_status "Extracting backup..."
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"
BACKUP_DIR=$(ls "$TEMP_DIR")
RESTORE_PATH="${TEMP_DIR}/${BACKUP_DIR}"
print_status "Backup extracted"

# ---- Step 2: Stop Gitea ----
print_status "Stopping Gitea..."
cd "$PROJECT_DIR"
docker compose stop gitea
print_status "Gitea stopped"

# ---- Step 3: Restore database ----
print_status "Restoring database..."
gunzip -c "${RESTORE_PATH}/database.sql.gz" | docker exec -i gitea-db psql -U gitea -d gitea --quiet
print_status "Database restored"

# ---- Step 4: Restore Gitea data ----
print_status "Restoring Gitea data..."
docker exec gitea sh -c 'rm -rf /var/lib/gitea/*'
cat "${RESTORE_PATH}/gitea_data.tar.gz" | docker exec -i gitea sh -c 'cd /var/lib/gitea && tar xzf -'
print_status "Gitea data restored"

# ---- Step 5: Restore configuration ----
print_status "Restoring configuration..."
cat "${RESTORE_PATH}/gitea_config.tar.gz" | docker exec -i gitea sh -c 'cd /etc/gitea && tar xzf -'
print_status "Configuration restored"

# ---- Step 6: Restart Gitea ----
print_status "Restarting Gitea..."
docker compose restart gitea
print_status "Gitea restarted"

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

echo ""
echo "============================================"
echo -e "  ${GREEN}Restore Complete!${NC}"
echo "============================================"
echo ""
echo "  Gitea telah di-restore dari: $(basename $BACKUP_FILE)"
echo "  Silakan cek https://${DOMAIN:-your-domain} untuk verifikasi"
echo ""
