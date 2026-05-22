#!/bin/bash
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/gitea-backup"
BACKUP_FILE="gitea-backup-${TIMESTAMP}.tar.gz"

echo "[$(date)] Starting Gitea backup..."
mkdir -p "$BACKUP_DIR"

echo "[$(date)] Creating backup from data volume..."
tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" -C /gitea-data .

echo "[$(date)] Backup file: ${BACKUP_FILE} ($(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1))"

echo "[$(date)] Uploading to Cloudflare R2..."
rclone copy "${BACKUP_DIR}/${BACKUP_FILE}" r2:backup-gitea/ --progress

echo "[$(date)] Upload complete!"
rm -rf "$BACKUP_DIR"
echo "[$(date)] Backup finished successfully!"
