#!/bin/bash
# 📦 Backup Script для your-domain.com
# Создает бэкапы базы данных и файлов

set -e

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENVIRONMENT="${1:-prod}"

if [ "$ENVIRONMENT" == "prod" ]; then
    SSH_USER="$PROD_SSH_USER"
    SSH_HOST="$PROD_SSH_HOST"
    WEBROOT="$PROD_WEBROOT"
    BACKUP_DIR="$PROD_BACKUP_DIR"
    DB_NAME="$PROD_DB_NAME"
    DB_USER="$PROD_DB_USER"
    DB_PASS="$PROD_DB_PASS"
else
    SSH_USER="$DEV_SSH_USER"
    SSH_HOST="$DEV_SSH_HOST"
    WEBROOT="$DEV_WEBROOT"
    BACKUP_DIR="$DEV_BACKUP_DIR"
    DB_NAME="$DEV_DB_NAME"
    DB_USER="$DEV_DB_USER"
    DB_PASS="$DEV_DB_PASS"
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo -e "${BLUE}Creating backup for ${ENVIRONMENT^^}...${NC}"
echo ""

# ============================================
# 1. Database Backup
# ============================================
echo -e "${BLUE}[1/2]${NC} Backing up database..."

ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
# Создаем директорию для бэкапов, если не существует
mkdir -p ${BACKUP_DIR}

cd ${WEBROOT}

# Экспорт базы данных
BACKUP_FILE="${BACKUP_DIR}/backup-${TIMESTAMP}.sql.gz"

echo "Exporting database ${DB_NAME}..."
wp db export - | gzip > \${BACKUP_FILE}

if [ \$? -eq 0 ]; then
    BACKUP_SIZE=\$(du -h \${BACKUP_FILE} | cut -f1)
    echo "✓ Database backup created: \$(basename \${BACKUP_FILE}) (\${BACKUP_SIZE})"
else
    echo "✗ Database backup failed"
    exit 1
fi

# Удаляем старые бэкапы (оставляем последние N)
cd ${BACKUP_DIR}
ls -t backup-*.sql.gz | tail -n +$((BACKUP_KEEP_COUNT + 1)) | xargs -r rm
echo "  Kept last ${BACKUP_KEEP_COUNT} backups"
ENDSSH

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Database backup failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Database backed up"
echo ""

# ============================================
# 2. Files Backup (theme)
# ============================================
echo -e "${BLUE}[2/2]${NC} Backing up theme files..."

ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
cd ${WEBROOT}/..

BACKUP_FILE="${BACKUP_DIR}/files-${TIMESTAMP}.tar.gz"

echo "Creating theme backup..."
tar -czf \${BACKUP_FILE} \
    -C ${WEBROOT} \
    wp-content/themes/your-theme \
    --exclude='*.log' \
    --exclude='node_modules'

if [ \$? -eq 0 ]; then
    BACKUP_SIZE=\$(du -h \${BACKUP_FILE} | cut -f1)
    echo "✓ Files backup created: \$(basename \${BACKUP_FILE}) (\${BACKUP_SIZE})"
else
    echo "✗ Files backup failed"
    exit 1
fi

# Удаляем старые бэкапы файлов
cd ${BACKUP_DIR}
ls -t files-*.tar.gz | tail -n +$((BACKUP_KEEP_COUNT + 1)) | xargs -r rm
ENDSSH

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Files backup failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Files backed up"
echo ""

# ============================================
# Summary
# ============================================
echo -e "${GREEN}✓ Backup completed successfully${NC}"
echo "  Timestamp: ${TIMESTAMP}"
echo ""

exit 0
