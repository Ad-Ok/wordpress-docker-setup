#!/bin/bash
# 🔧 Database Optimization Script
# Безопасная очистка и оптимизация базы данных WordPress
#
# Использование:
#   ./db-optimize.sh [local|dev|prod] [--dry-run]
#
# Операции:
#   - Удаление ревизий постов
#   - Удаление спам/trash комментариев
#   - Удаление expired transients
#   - Удаление trash постов
#   - Оптимизация таблиц (OPTIMIZE TABLE)
#
# По умолчанию: local

set -e

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Определяем среду и режим
ENVIRONMENT="${1:-local}"
DRY_RUN=false

# Проверка флага --dry-run
for arg in "$@"; do
    if [ "$arg" == "--dry-run" ]; then
        DRY_RUN=true
    fi
done

# Настройка подключения в зависимости от среды
if [ "$ENVIRONMENT" == "local" ]; then
    echo -e "${BLUE}═══ Database Optimization: LOCAL ═══${NC}"
    
    # Проверка Docker контейнера
    if ! docker ps | grep -q "${LOCAL_DB_CONTAINER}"; then
        echo -e "${RED}✗ Docker MySQL container '${LOCAL_DB_CONTAINER}' is not running${NC}"
        exit 1
    fi
    
    DB_NAME="$LOCAL_DB_NAME"
    DB_USER="$LOCAL_DB_USER"
    DB_PASS="$LOCAL_DB_PASS"
    DB_CONTAINER="$LOCAL_DB_CONTAINER"
    BACKUP_DIR="${LOCAL_PROJECT_ROOT}/backups"
    
elif [ "$ENVIRONMENT" == "dev" ]; then
    echo -e "${BLUE}═══ Database Optimization: DEV ═══${NC}"
    
    DB_NAME="$DEV_DB_NAME"
    DB_USER="$DEV_DB_USER"
    DB_PASS="$DEV_DB_PASS"
    SSH_USER="$DEV_SSH_USER"
    SSH_HOST="$DEV_SSH_HOST"
    BACKUP_DIR="${DEV_BACKUP_DIR:-/home/${DEV_SSH_USER}/backups}"
    
elif [ "$ENVIRONMENT" == "prod" ]; then
    echo -e "${BLUE}═══ Database Optimization: PROD ═══${NC}"
    echo -e "${RED}⚠️  WARNING: You are about to optimize PRODUCTION database!${NC}"
    echo -e "${YELLOW}This operation will be logged and backed up.${NC}"
    echo ""
    echo -e "Type 'yes' to continue: "
    read -r CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
    
    DB_NAME="$PROD_DB_NAME"
    DB_USER="$PROD_DB_USER"
    DB_PASS="$PROD_DB_PASS"
    SSH_USER="$PROD_SSH_USER"
    SSH_HOST="$PROD_SSH_HOST"
    BACKUP_DIR="${PROD_BACKUP_DIR:-/home/${PROD_SSH_USER}/backups}"
    
else
    echo -e "${RED}Invalid environment: $ENVIRONMENT${NC}"
    echo "Usage: $0 [local|dev|prod] [--dry-run]"
    exit 1
fi

echo ""
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}🔍 DRY RUN MODE - No changes will be made${NC}"
    echo ""
fi

# Функция выполнения SQL запроса
run_query() {
    local query="$1"
    if [ "$ENVIRONMENT" == "local" ]; then
        echo "$query" | docker exec -i "${DB_CONTAINER}" mysql -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -N 2>/dev/null
    else
        ssh "${SSH_USER}@${SSH_HOST}" "mysql -u'${DB_USER}' -p'${DB_PASS}' '${DB_NAME}' -N -e \"${query}\"" 2>/dev/null | grep -v "Using a password"
    fi
}

# Функция для подсчета записей перед удалением
count_records() {
    local query="$1"
    run_query "$query"
}

# Создание лог-файла
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/tmp/db-optimize-${ENVIRONMENT}-${TIMESTAMP}.log"

log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# ============================================
# СОЗДАНИЕ BACKUP (если не dry-run)
# ============================================
if [ "$DRY_RUN" = false ]; then
    echo -e "${CYAN}Creating backup before optimization...${NC}"
    
    BACKUP_NAME="pre-optimization-${ENVIRONMENT}-${TIMESTAMP}.sql"
    
    if [ "$ENVIRONMENT" == "local" ]; then
        mkdir -p "$BACKUP_DIR"
        docker exec "${DB_CONTAINER}" mysqldump -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" > "${BACKUP_DIR}/${BACKUP_NAME}" 2>/dev/null
        BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}" | cut -f1)
        echo -e "${GREEN}✓ Backup created: ${BACKUP_DIR}/${BACKUP_NAME} (${BACKUP_SIZE})${NC}"
    else
        ssh "${SSH_USER}@${SSH_HOST}" "mkdir -p ${BACKUP_DIR} && mysqldump -u'${DB_USER}' -p'${DB_PASS}' '${DB_NAME}' > ${BACKUP_DIR}/${BACKUP_NAME}" 2>/dev/null
        BACKUP_SIZE=$(ssh "${SSH_USER}@${SSH_HOST}" "du -h ${BACKUP_DIR}/${BACKUP_NAME} | cut -f1")
        echo -e "${GREEN}✓ Backup created: ${BACKUP_DIR}/${BACKUP_NAME} (${BACKUP_SIZE})${NC}"
    fi
    echo ""
fi

# ============================================
# АНАЛИЗ И ОЧИСТКА
# ============================================

log "═══════════════════════════════════════════════════════════════"
log "Database Optimization Report"
log "Environment: ${ENVIRONMENT}"
log "Dry Run: ${DRY_RUN}"
log "Date: $(date '+%Y-%m-%d %H:%M:%S')"
log "═══════════════════════════════════════════════════════════════"
log ""

TOTAL_FREED=0

# ============================================
# 1. РЕВИЗИИ ПОСТОВ
# ============================================
echo -e "${BOLD}[1/4] Post Revisions${NC}"

REVISIONS_COUNT=$(count_records "SELECT COUNT(*) FROM wp_posts WHERE post_type = 'revision';")

if [ "$REVISIONS_COUNT" -gt 0 ]; then
    echo -e "  Found: ${YELLOW}${REVISIONS_COUNT}${NC} revisions"
    log "Post Revisions: ${REVISIONS_COUNT}"
    
    if [ "$DRY_RUN" = false ]; then
        run_query "DELETE FROM wp_posts WHERE post_type = 'revision';" > /dev/null
        echo -e "  ${GREEN}✓ Deleted${NC}"
        log "  → Deleted"
    else
        echo -e "  ${CYAN}→ Would delete${NC}"
        log "  → Would delete"
    fi
else
    echo -e "  ${GREEN}✓ No revisions to delete${NC}"
    log "Post Revisions: 0 (clean)"
fi

echo ""

# ============================================
# 2. TRASH ПОСТЫ
# ============================================
echo -e "${BOLD}[2/4] Trash Posts${NC}"

TRASH_COUNT=$(count_records "SELECT COUNT(*) FROM wp_posts WHERE post_status = 'trash';")

if [ "$TRASH_COUNT" -gt 0 ]; then
    echo -e "  Found: ${YELLOW}${TRASH_COUNT}${NC} trash posts"
    log "Trash Posts: ${TRASH_COUNT}"
    
    if [ "$DRY_RUN" = false ]; then
        run_query "DELETE FROM wp_posts WHERE post_status = 'trash';" > /dev/null
        echo -e "  ${GREEN}✓ Deleted${NC}"
        log "  → Deleted"
    else
        echo -e "  ${CYAN}→ Would delete${NC}"
        log "  → Would delete"
    fi
else
    echo -e "  ${GREEN}✓ No trash posts${NC}"
    log "Trash Posts: 0 (clean)"
fi

echo ""

# ============================================
# 3. СПАМ И TRASH КОММЕНТАРИИ
# ============================================
echo -e "${BOLD}[3/4] Spam & Trash Comments${NC}"

SPAM_COUNT=$(count_records "SELECT COUNT(*) FROM wp_comments WHERE comment_approved = 'spam';")
TRASH_COMMENTS=$(count_records "SELECT COUNT(*) FROM wp_comments WHERE comment_approved = 'trash';")

if [ "$SPAM_COUNT" -gt 0 ] || [ "$TRASH_COMMENTS" -gt 0 ]; then
    echo -e "  Found: ${YELLOW}${SPAM_COUNT}${NC} spam, ${YELLOW}${TRASH_COMMENTS}${NC} trash"
    log "Spam Comments: ${SPAM_COUNT}"
    log "Trash Comments: ${TRASH_COMMENTS}"
    
    if [ "$DRY_RUN" = false ]; then
        run_query "DELETE FROM wp_comments WHERE comment_approved IN ('spam', 'trash');" > /dev/null
        run_query "DELETE FROM wp_commentmeta WHERE comment_id NOT IN (SELECT comment_ID FROM wp_comments);" > /dev/null
        echo -e "  ${GREEN}✓ Deleted comments and their meta${NC}"
        log "  → Deleted"
    else
        echo -e "  ${CYAN}→ Would delete${NC}"
        log "  → Would delete"
    fi
else
    echo -e "  ${GREEN}✓ No spam or trash comments${NC}"
    log "Spam/Trash Comments: 0 (clean)"
fi

echo ""

# ============================================
# 4. ОПТИМИЗАЦИЯ ТАБЛИЦ
# ============================================
echo -e "${BOLD}[4/4] Table Optimization${NC}"

# Получаем список таблиц с фрагментацией
if [ "$ENVIRONMENT" == "local" ]; then
    TABLES=$(docker exec -i "${DB_CONTAINER}" mysql -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -N -e "SELECT table_name FROM information_schema.TABLES WHERE table_schema = '${DB_NAME}' AND engine = 'InnoDB';" 2>/dev/null)
else
    TABLES=$(ssh "${SSH_USER}@${SSH_HOST}" "mysql -u'${DB_USER}' -p'${DB_PASS}' '${DB_NAME}' -N -e \"SELECT table_name FROM information_schema.TABLES WHERE table_schema = '${DB_NAME}' AND engine = 'InnoDB';\"" 2>/dev/null)
fi

TABLES_COUNT=$(echo "$TABLES" | wc -l | xargs)

if [ "$DRY_RUN" = false ]; then
    echo -e "  Optimizing ${CYAN}${TABLES_COUNT}${NC} tables..."
    log "Table Optimization: ${TABLES_COUNT} tables"
    
    OPTIMIZED=0
    while IFS= read -r table; do
        if [ -n "$table" ]; then
            echo -ne "  ${table}...\r"
            run_query "OPTIMIZE TABLE ${table};" > /dev/null 2>&1
            ((OPTIMIZED++))
        fi
    done <<< "$TABLES"
    
    echo -e "  ${GREEN}✓ Optimized ${OPTIMIZED} tables${NC}          "
    log "  → Optimized ${OPTIMIZED} tables"
else
    echo -e "  ${CYAN}→ Would optimize ${TABLES_COUNT} tables${NC}"
    log "  → Would optimize ${TABLES_COUNT} tables"
fi

echo ""

# ============================================
# ИТОГОВЫЙ ОТЧЕТ
# ============================================
log ""
log "═══════════════════════════════════════════════════════════════"
log "Optimization Complete"
log "═══════════════════════════════════════════════════════════════"

echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}✓ Dry run complete - no changes made${NC}"
else
    echo -e "${GREEN}✓ Optimization complete!${NC}"
fi
echo ""

# Рекомендация запустить анализ
echo -e "Run analysis to see results:"
echo -e "  ${CYAN}./deployment-scripts/database/db-analyze.sh ${ENVIRONMENT}${NC}"
echo ""

if [ "$DRY_RUN" = false ]; then
    echo -e "Backup saved to:"
    if [ "$ENVIRONMENT" == "local" ]; then
        echo -e "  ${CYAN}${BACKUP_DIR}/${BACKUP_NAME}${NC}"
    else
        echo -e "  ${CYAN}${SSH_USER}@${SSH_HOST}:${BACKUP_DIR}/${BACKUP_NAME}${NC}"
    fi
    echo ""
fi

echo -e "Log saved to: ${CYAN}${LOG_FILE}${NC}"
echo ""

# Если не dry-run, показываем команду для отката
if [ "$DRY_RUN" = false ]; then
    echo -e "${YELLOW}To rollback (if needed):${NC}"
    if [ "$ENVIRONMENT" == "local" ]; then
        echo -e "  ${CYAN}docker exec -i ${DB_CONTAINER} mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME} < ${BACKUP_DIR}/${BACKUP_NAME}${NC}"
    else
        echo -e "  ${CYAN}ssh ${SSH_USER}@${SSH_HOST} \"mysql -u'${DB_USER}' -p'${DB_PASS}' '${DB_NAME}' < ${BACKUP_DIR}/${BACKUP_NAME}\"${NC}"
    fi
    echo ""
fi
