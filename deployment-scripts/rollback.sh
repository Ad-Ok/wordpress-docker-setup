#!/bin/bash
# 🔙 Rollback Script для your-domain.com
# Откат к предыдущей версии

set -e

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils/notifications.sh"

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
    WP_PATH="$PROD_WP_PATH"
else
    SSH_USER="$DEV_SSH_USER"
    SSH_HOST="$DEV_SSH_HOST"
    WEBROOT="$DEV_WEBROOT"
    BACKUP_DIR="$DEV_BACKUP_DIR"
    WP_PATH="$DEV_WP_PATH"
fi

ENV_UPPER=$(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              ROLLBACK - ${ENV_UPPER}                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# 1. Получить список доступных бэкапов
# ============================================
echo -e "${BLUE}Fetching available backups...${NC}"
echo ""

BACKUPS=$(ssh "${SSH_USER}@${SSH_HOST}" "ls -t ${BACKUP_DIR}/backup-*.sql.gz 2>/dev/null" || echo "")

if [ -z "$BACKUPS" ]; then
    echo -e "${RED}✗ No backups found${NC}"
    exit 1
fi

# Показать список бэкапов
echo "Available backups:"
echo ""

BACKUP_ARRAY=()
INDEX=1

while IFS= read -r backup; do
    BACKUP_NAME=$(basename "$backup")
    TIMESTAMP=$(echo "$BACKUP_NAME" | sed 's/backup-\(.*\)\.sql\.gz/\1/')
    
    # Преобразуем timestamp в читаемый формат
    FORMATTED_DATE=$(echo "$TIMESTAMP" | sed 's/\([0-9]\{8\}\)-\([0-9]\{6\}\)/\1 \2/' | \
        awk '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" "substr($2,1,2)":"substr($2,3,2)":"substr($2,5,2)}')
    
    # Вычислить, сколько времени прошло
    BACKUP_EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S" "$FORMATTED_DATE" +%s 2>/dev/null || echo "0")
    CURRENT_EPOCH=$(date +%s)
    DIFF_SECONDS=$((CURRENT_EPOCH - BACKUP_EPOCH))
    
    if [ $DIFF_SECONDS -lt 3600 ]; then
        TIME_AGO="$((DIFF_SECONDS / 60)) minutes ago"
    elif [ $DIFF_SECONDS -lt 86400 ]; then
        TIME_AGO="$((DIFF_SECONDS / 3600)) hours ago"
    else
        TIME_AGO="$((DIFF_SECONDS / 86400)) days ago"
    fi
    
    echo "[$INDEX] $BACKUP_NAME ($TIME_AGO)"
    BACKUP_ARRAY+=("$backup")
    ((INDEX++))
done <<< "$BACKUPS"

echo ""

# ============================================
# 2. Выбор бэкапа
# ============================================
read -p "Select backup to restore [1-$((INDEX-1))]: " -r SELECTION

if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -ge "$INDEX" ]; then
    echo -e "${RED}Invalid selection${NC}"
    exit 1
fi

SELECTED_BACKUP="${BACKUP_ARRAY[$((SELECTION-1))]}"
BACKUP_NAME=$(basename "$SELECTED_BACKUP")
TIMESTAMP=$(echo "$BACKUP_NAME" | sed 's/backup-\(.*\)\.sql\.gz/\1/')

echo ""
echo -e "${YELLOW}Selected backup: ${BACKUP_NAME}${NC}"
echo ""

# ============================================
# 3. Подтверждение
# ============================================
echo -e "${RED}⚠️  WARNING: This will OVERWRITE current database and files${NC}"
echo ""
read -p "Are you sure you want to rollback? (type 'yes' to confirm): " -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Rollback cancelled${NC}"
    exit 0
fi

echo ""

# ============================================
# 4. Enable Maintenance Mode
# ============================================
echo -e "${BLUE}[1/5]${NC} Enabling maintenance mode..."

ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
cd ${WEBROOT}
echo "<?php \\\$upgrading = time(); ?>" > .maintenance
ENDSSH

echo -e "${GREEN}✓${NC} Maintenance mode enabled"
echo ""

# ============================================
# 5. Restore Database
# ============================================
echo -e "${BLUE}[2/5]${NC} Restoring database..."

ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
cd ${WP_PATH}

echo "Importing database from ${BACKUP_NAME}..."
gunzip -c ${SELECTED_BACKUP} | wp db import -

if [ \$? -eq 0 ]; then
    echo "✓ Database restored"
else
    echo "✗ Database restore failed"
    rm -f ${WEBROOT}/.maintenance
    exit 1
fi
ENDSSH

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Database restore failed${NC}"
    send_notification "❌ ${ENV_UPPER} rollback failed: Database restore error"
    exit 1
fi

echo -e "${GREEN}✓${NC} Database restored"
echo ""

# ============================================
# 6. Restore Files
# ============================================
echo -e "${BLUE}[3/5]${NC} Restoring theme files..."

FILES_BACKUP="${BACKUP_DIR}/files-${TIMESTAMP}.tar.gz"

ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
if [ -f "${FILES_BACKUP}" ]; then
    echo "Extracting files from files-${TIMESTAMP}.tar.gz..."
    
    cd ${WEBROOT}
    tar -xzf ${FILES_BACKUP}
    
    if [ \$? -eq 0 ]; then
        echo "✓ Files restored"
    else
        echo "✗ Files restore failed"
        exit 1
    fi
else
    echo "⚠️  Files backup not found, skipping"
fi
ENDSSH

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Files restore failed${NC}"
    send_notification "❌ ${ENV_UPPER} rollback failed: Files restore error"
    exit 1
fi

echo -e "${GREEN}✓${NC} Files restored"
echo ""

# ============================================
# 7. Clear Cache
# ============================================
echo -e "${BLUE}[4/5]${NC} Clearing cache..."

ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
cd ${WP_PATH}

wp cache flush
wp rewrite flush

# Кеш плагины
wp plugin is-active wp-super-cache 2>/dev/null && wp super-cache flush
wp plugin is-active w3-total-cache 2>/dev/null && wp w3-total-cache flush
ENDSSH

echo -e "${GREEN}✓${NC} Cache cleared"
echo ""

# ============================================
# 8. Disable Maintenance Mode
# ============================================
echo -e "${BLUE}[5/5]${NC} Disabling maintenance mode..."

ssh "${SSH_USER}@${SSH_HOST}" "rm -f ${WEBROOT}/.maintenance"

echo -e "${GREEN}✓${NC} Maintenance mode disabled"
echo ""

# ============================================
# SUCCESS
# ============================================
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            ROLLBACK SUCCESSFUL! ✓               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✓${NC} Rollback completed successfully"
echo "  Restored to: ${TIMESTAMP}"
echo ""

send_notification "✅ ${ENV_UPPER} rolled back to ${TIMESTAMP}"

exit 0
