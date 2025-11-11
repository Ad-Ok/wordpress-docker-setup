#!/bin/bash
# 📊 Database Analysis Script
# Анализирует базу данных WordPress и создает отчет с метриками
#
# Использование:
#   ./db-analyze.sh [local|dev|prod]
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

# Определяем среду
ENVIRONMENT="${1:-local}"

# Настройка подключения в зависимости от среды
if [ "$ENVIRONMENT" == "local" ]; then
    echo -e "${BLUE}═══ Database Analysis: LOCAL ═══${NC}"
    echo ""
    
    # Проверка Docker контейнера
    if ! docker ps | grep -q "${LOCAL_DB_CONTAINER}"; then
        echo -e "${RED}✗ Docker MySQL container '${LOCAL_DB_CONTAINER}' is not running${NC}"
        exit 1
    fi
    
    DB_NAME="$LOCAL_DB_NAME"
    DB_USER="$LOCAL_DB_USER"
    DB_PASS="$LOCAL_DB_PASS"
    MYSQL_CMD="docker exec -i ${LOCAL_DB_CONTAINER} mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME}"
    
elif [ "$ENVIRONMENT" == "dev" ]; then
    echo -e "${BLUE}═══ Database Analysis: DEV ═══${NC}"
    echo ""
    
    DB_NAME="$DEV_DB_NAME"
    DB_USER="$DEV_DB_USER"
    DB_PASS="$DEV_DB_PASS"
    MYSQL_CMD="ssh ${DEV_SSH_USER}@${DEV_SSH_HOST} \"mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME}\""
    
elif [ "$ENVIRONMENT" == "prod" ]; then
    echo -e "${BLUE}═══ Database Analysis: PROD ═══${NC}"
    echo ""
    
    DB_NAME="$PROD_DB_NAME"
    DB_USER="$PROD_DB_USER"
    DB_PASS="$PROD_DB_PASS"
    MYSQL_CMD="ssh ${PROD_SSH_USER}@${PROD_SSH_HOST} \"mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME}\""
    
else
    echo -e "${RED}Invalid environment: $ENVIRONMENT${NC}"
    echo "Usage: $0 [local|dev|prod]"
    exit 1
fi

# Создание директории для отчетов
REPORTS_DIR="${LOCAL_PROJECT_ROOT}/wordpress/database/reports"
mkdir -p "$REPORTS_DIR"

# Имя файла отчета
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORTS_DIR}/db-analysis-${ENVIRONMENT}-${TIMESTAMP}.txt"
REPORT_JSON="${REPORTS_DIR}/db-analysis-${ENVIRONMENT}-${TIMESTAMP}.json"

# Функция выполнения SQL запроса
run_query() {
    local query="$1"
    if [ "$ENVIRONMENT" == "local" ]; then
        echo "$query" | docker exec -i "${LOCAL_DB_CONTAINER}" mysql -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -N 2>/dev/null
    else
        # Для удаленных серверов
        ssh "${SSH_USER}@${SSH_HOST}" "mysql -u'${DB_USER}' -p'${DB_PASS}' '${DB_NAME}' -N -e \"${query}\"" 2>/dev/null | grep -v "Using a password"
    fi
}

# Начало отчета
ENV_UPPER=$(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')
REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')

cat > "$REPORT_FILE" << EOF
═══════════════════════════════════════════════════════════════
   WordPress Database Analysis Report
═══════════════════════════════════════════════════════════════

Environment: ${ENV_UPPER}
Database: ${DB_NAME}
Generated: ${REPORT_DATE}

EOF

echo -e "${CYAN}Analyzing database...${NC}"
echo ""

# ============================================
# 1. ОБЩАЯ ИНФОРМАЦИЯ О БАЗЕ ДАННЫХ
# ============================================
echo -e "${BOLD}[1/10] General Database Information${NC}"

DB_SIZE=$(run_query "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) FROM information_schema.TABLES WHERE table_schema = '${DB_NAME}';")
TABLE_COUNT=$(run_query "SELECT COUNT(*) FROM information_schema.TABLES WHERE table_schema = '${DB_NAME}';")

cat >> "$REPORT_FILE" << EOF
═══════════════════════════════════════════════════════════════
1. GENERAL DATABASE INFO
═══════════════════════════════════════════════════════════════

Total Size: ${DB_SIZE} MB
Total Tables: ${TABLE_COUNT}

EOF

echo -e "  Database size: ${GREEN}${DB_SIZE} MB${NC}"
echo -e "  Total tables: ${GREEN}${TABLE_COUNT}${NC}"
echo ""

# ============================================
# 2. РАЗМЕРЫ ТАБЛИЦ И ФРАГМЕНТАЦИЯ
# ============================================
echo -e "${BOLD}[2/10] Table Sizes & Fragmentation${NC}"

cat >> "$REPORT_FILE" << EOF
═══════════════════════════════════════════════════════════════
2. TABLE SIZES (Top 10)
═══════════════════════════════════════════════════════════════

EOF

run_query "SELECT 
    CONCAT(table_name, ':', ROUND((data_length + index_length) / 1024 / 1024, 2), ' MB')
FROM information_schema.TABLES 
WHERE table_schema = '${DB_NAME}' 
ORDER BY (data_length + index_length) DESC 
LIMIT 10;" | while read line; do
    table=$(echo "$line" | cut -d: -f1)
    size=$(echo "$line" | cut -d: -f2)
    echo "  ${table}: ${size}" >> "$REPORT_FILE"
    echo -e "  ${table}: ${CYAN}${size}${NC}"
done

echo "" >> "$REPORT_FILE"

# Фрагментация таблиц
cat >> "$REPORT_FILE" << EOF

═══════════════════════════════════════════════════════════════
2a. TABLE FRAGMENTATION
═══════════════════════════════════════════════════════════════

EOF

echo ""
echo -e "${BOLD}Table Fragmentation:${NC}"

TOTAL_FRAGMENTATION=$(run_query "SELECT ROUND(SUM(data_free) / 1024 / 1024, 2) FROM information_schema.TABLES WHERE table_schema = '${DB_NAME}' AND engine = 'InnoDB';")

echo "Total fragmented space: ${TOTAL_FRAGMENTATION} MB" >> "$REPORT_FILE"
echo -e "  Total fragmented space: ${CYAN}${TOTAL_FRAGMENTATION} MB${NC}"

if (( $(echo "$TOTAL_FRAGMENTATION > 10" | bc -l 2>/dev/null || echo 0) )); then
    echo "  ⚠️  WARNING: Significant fragmentation detected" >> "$REPORT_FILE"
    echo -e "  ${YELLOW}⚠️  Significant fragmentation detected${NC}"
fi

echo "" >> "$REPORT_FILE"
echo "Tables with fragmentation (>1 MB):" >> "$REPORT_FILE"

run_query "SELECT 
    CONCAT(table_name, ':', ROUND(data_free / 1024 / 1024, 2), ' MB:', ROUND((data_free / (data_length + index_length + data_free)) * 100, 1), '%')
FROM information_schema.TABLES 
WHERE table_schema = '${DB_NAME}' 
  AND engine = 'InnoDB'
  AND data_free > 1048576
ORDER BY data_free DESC;" | while read line; do
    if [ -n "$line" ]; then
        table=$(echo "$line" | cut -d: -f1)
        fragmented=$(echo "$line" | cut -d: -f2)
        percent=$(echo "$line" | cut -d: -f3)
        echo "  ${table}: ${fragmented} (${percent})" >> "$REPORT_FILE"
        echo -e "  ${YELLOW}${table}${NC}: ${fragmented} (${percent})"
    fi
done

FRAGMENTED_TABLES=$(run_query "SELECT COUNT(*) FROM information_schema.TABLES WHERE table_schema = '${DB_NAME}' AND engine = 'InnoDB' AND data_free > 1048576;")

if [ "$FRAGMENTED_TABLES" -eq 0 ]; then
    echo "  ✓ No significant fragmentation" >> "$REPORT_FILE"
    echo -e "  ${GREEN}✓ No significant fragmentation${NC}"
fi

echo "" >> "$REPORT_FILE"
echo ""

# ============================================
# 3. AUTOLOAD ОПЦИИ
# ============================================
echo -e "${BOLD}[3/10] Autoload Options Analysis${NC}"

AUTOLOAD_SIZE=$(run_query "SELECT ROUND(SUM(LENGTH(option_value)) / 1024, 2) FROM wp_options WHERE autoload = 'yes';")
AUTOLOAD_COUNT=$(run_query "SELECT COUNT(*) FROM wp_options WHERE autoload = 'yes';")

cat >> "$REPORT_FILE" << EOF
═══════════════════════════════════════════════════════════════
3. AUTOLOAD OPTIONS
═══════════════════════════════════════════════════════════════

Total Autoload Size: ${AUTOLOAD_SIZE} KB
Total Autoload Count: ${AUTOLOAD_COUNT}

EOF

echo -e "  Total autoload size: ${GREEN}${AUTOLOAD_SIZE} KB${NC}"
echo -e "  Total autoload count: ${GREEN}${AUTOLOAD_COUNT}${NC}"

if (( $(echo "$AUTOLOAD_SIZE > 1000" | bc -l) )); then
    echo -e "  ${YELLOW}⚠️  WARNING: Autoload size is large (>1MB)${NC}"
    echo "  ⚠️  WARNING: Autoload size is large (>1MB)" >> "$REPORT_FILE"
fi

echo ""
cat >> "$REPORT_FILE" << EOF

Large Autoload Options (>50 KB):
EOF

run_query "SELECT 
    CONCAT(option_name, ':', ROUND(LENGTH(option_value) / 1024, 2), ' KB')
FROM wp_options 
WHERE autoload = 'yes' 
  AND LENGTH(option_value) > 51200 
ORDER BY LENGTH(option_value) DESC 
LIMIT 10;" | while read line; do
    option=$(echo "$line" | cut -d: -f1)
    size=$(echo "$line" | cut -d: -f2)
    echo "  - ${option}: ${size}" >> "$REPORT_FILE"
    echo -e "  ${YELLOW}${option}${NC}: ${size}"
done

echo "" >> "$REPORT_FILE"
echo ""

# ============================================
# 4. TRANSIENT КЕШ
# ============================================
echo -e "${BOLD}[4/10] Transient Cache${NC}"

TRANSIENT_COUNT=$(run_query "SELECT COUNT(*) FROM wp_options WHERE option_name LIKE '_transient_%' OR option_name LIKE '_site_transient_%';")
TRANSIENT_SIZE=$(run_query "SELECT ROUND(SUM(LENGTH(option_value)) / 1024, 2) FROM wp_options WHERE option_name LIKE '_transient_%' OR option_name LIKE '_site_transient_%';")

cat >> "$REPORT_FILE" << EOF
═══════════════════════════════════════════════════════════════
4. TRANSIENT CACHE
═══════════════════════════════════════════════════════════════

Total Transients: ${TRANSIENT_COUNT}
Total Size: ${TRANSIENT_SIZE} KB

EOF

echo -e "  Total transients: ${GREEN}${TRANSIENT_COUNT}${NC}"
echo -e "  Total size: ${GREEN}${TRANSIENT_SIZE} KB${NC}"

if [ "$TRANSIENT_COUNT" -gt 100 ]; then
    echo -e "  ${YELLOW}⚠️  Consider cleaning transients${NC}"
    echo "  ⚠️  Consider cleaning transients" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo ""

# ============================================
# 5. ПОСТЫ И РЕВИЗИИ
# ============================================
echo -e "${BOLD}[5/10] Posts & Revisions${NC}"

TOTAL_POSTS=$(run_query "SELECT COUNT(*) FROM wp_posts WHERE post_type = 'post' AND post_status = 'publish';")
TOTAL_PAGES=$(run_query "SELECT COUNT(*) FROM wp_posts WHERE post_type = 'page' AND post_status = 'publish';")
TOTAL_REVISIONS=$(run_query "SELECT COUNT(*) FROM wp_posts WHERE post_type = 'revision';")
TOTAL_DRAFTS=$(run_query "SELECT COUNT(*) FROM wp_posts WHERE post_status = 'draft';")
TOTAL_TRASH=$(run_query "SELECT COUNT(*) FROM wp_posts WHERE post_status = 'trash';")

cat >> "$REPORT_FILE" << EOF
═══════════════════════════════════════════════════════════════
5. POSTS & REVISIONS
═══════════════════════════════════════════════════════════════

Published Posts: ${TOTAL_POSTS}
Published Pages: ${TOTAL_PAGES}
Revisions: ${TOTAL_REVISIONS}
Drafts: ${TOTAL_DRAFTS}
Trash: ${TOTAL_TRASH}

EOF

echo -e "  Published posts: ${GREEN}${TOTAL_POSTS}${NC}"
echo -e "  Published pages: ${GREEN}${TOTAL_PAGES}${NC}"
echo -e "  Revisions: ${CYAN}${TOTAL_REVISIONS}${NC}"
echo -e "  Drafts: ${CYAN}${TOTAL_DRAFTS}${NC}"
echo -e "  Trash: ${CYAN}${TOTAL_TRASH}${NC}"

if [ "$TOTAL_REVISIONS" -gt 100 ]; then
    echo -e "  ${YELLOW}⚠️  Consider limiting or cleaning old revisions${NC}"
    echo "  ⚠️  Consider limiting or cleaning old revisions" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo ""

# ============================================
# 6. CUSTOM POST TYPES
# ============================================
echo -e "${BOLD}[6/10] Custom Post Types${NC}"

cat >> "$REPORT_FILE" << EOF
═══════════════════════════════════════════════════════════════
6. CUSTOM POST TYPES
═══════════════════════════════════════════════════════════════

EOF

run_query "SELECT 
    CONCAT(post_type, ':', COUNT(*))
FROM wp_posts 
WHERE post_status = 'publish' 
  AND post_type NOT IN ('post', 'page', 'revision', 'nav_menu_item', 'attachment')
GROUP BY post_type 
ORDER BY COUNT(*) DESC;" | while read line; do
    post_type=$(echo "$line" | cut -d: -f1)
    count=$(echo "$line" | cut -d: -f2)
    echo "  ${post_type}: ${count}" >> "$REPORT_FILE"
    echo -e "  ${GREEN}${post_type}${NC}: ${count}"
done

echo "" >> "$REPORT_FILE"
echo ""

# ============================================
# 7. КОММЕНТАРИИ
# ============================================
echo -e "${BOLD}[7/10] Comments${NC}"

APPROVED_COMMENTS=$(run_query "SELECT COUNT(*) FROM wp_comments WHERE comment_approved = '1';")
SPAM_COMMENTS=$(run_query "SELECT COUNT(*) FROM wp_comments WHERE comment_approved = 'spam';")
TRASH_COMMENTS=$(run_query "SELECT COUNT(*) FROM wp_comments WHERE comment_approved = 'trash';")
PENDING_COMMENTS=$(run_query "SELECT COUNT(*) FROM wp_comments WHERE comment_approved = '0';")

cat >> "$REPORT_FILE" << EOF
═══════════════════════════════════════════════════════════════
7. COMMENTS
═══════════════════════════════════════════════════════════════

Approved: ${APPROVED_COMMENTS}
Spam: ${SPAM_COMMENTS}
Trash: ${TRASH_COMMENTS}
Pending: ${PENDING_COMMENTS}

EOF

echo -e "  Approved: ${GREEN}${APPROVED_COMMENTS}${NC}"
echo -e "  Spam: ${CYAN}${SPAM_COMMENTS}${NC}"
echo -e "  Trash: ${CYAN}${TRASH_COMMENTS}${NC}"
echo -e "  Pending: ${CYAN}${PENDING_COMMENTS}${NC}"

if [ "$SPAM_COMMENTS" -gt 0 ] || [ "$TRASH_COMMENTS" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠️  Consider deleting spam/trash comments${NC}"
    echo "  ⚠️  Consider deleting spam/trash comments" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo ""

# ============================================
# 8. ORPHANED DATA
# ============================================
echo -e "${BOLD}[8/10] Orphaned Data${NC}"

ORPHANED_POSTMETA=$(run_query "SELECT COUNT(*) FROM wp_postmeta pm LEFT JOIN wp_posts wp ON wp.ID = pm.post_id WHERE wp.ID IS NULL;")
ORPHANED_TERMMETA=$(run_query "SELECT COUNT(*) FROM wp_termmeta tm LEFT JOIN wp_terms t ON t.term_id = tm.term_id WHERE t.term_id IS NULL;" || echo "0")
ORPHANED_COMMENTMETA=$(run_query "SELECT COUNT(*) FROM wp_commentmeta cm LEFT JOIN wp_comments c ON c.comment_ID = cm.comment_id WHERE c.comment_ID IS NULL;")

cat >> "$REPORT_FILE" << EOF
═══════════════════════════════════════════════════════════════
8. ORPHANED DATA
═══════════════════════════════════════════════════════════════

Orphaned Postmeta: ${ORPHANED_POSTMETA}
Orphaned Termmeta: ${ORPHANED_TERMMETA}
Orphaned Commentmeta: ${ORPHANED_COMMENTMETA}

EOF

echo -e "  Orphaned postmeta: ${CYAN}${ORPHANED_POSTMETA}${NC}"
echo -e "  Orphaned termmeta: ${CYAN}${ORPHANED_TERMMETA}${NC}"
echo -e "  Orphaned commentmeta: ${CYAN}${ORPHANED_COMMENTMETA}${NC}"

if [ "$ORPHANED_POSTMETA" -gt 0 ] || [ "$ORPHANED_TERMMETA" -gt 0 ] || [ "$ORPHANED_COMMENTMETA" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠️  Consider cleaning orphaned data${NC}"
    echo "  ⚠️  Consider cleaning orphaned data" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo ""

# ============================================
# 9. ТАКСОНОМИИ
# ============================================
echo -e "${BOLD}[9/10] Taxonomies${NC}"

cat >> "$REPORT_FILE" << EOF
═══════════════════════════════════════════════════════════════
9. TAXONOMIES
═══════════════════════════════════════════════════════════════

EOF

run_query "SELECT 
    CONCAT(taxonomy, ':', COUNT(*))
FROM wp_term_taxonomy 
GROUP BY taxonomy 
ORDER BY COUNT(*) DESC;" | while read line; do
    taxonomy=$(echo "$line" | cut -d: -f1)
    count=$(echo "$line" | cut -d: -f2)
    echo "  ${taxonomy}: ${count}" >> "$REPORT_FILE"
    echo -e "  ${GREEN}${taxonomy}${NC}: ${count}"
done

echo "" >> "$REPORT_FILE"
echo ""

# ============================================
# 10. РЕКОМЕНДАЦИИ ПО ОПТИМИЗАЦИИ
# ============================================
echo -e "${BOLD}[10/10] Optimization Recommendations${NC}"

cat >> "$REPORT_FILE" << EOF
═══════════════════════════════════════════════════════════════
10. OPTIMIZATION RECOMMENDATIONS
═══════════════════════════════════════════════════════════════

EOF

RECOMMENDATIONS=0

# Проверка autoload
if (( $(echo "$AUTOLOAD_SIZE > 1000" | bc -l) )); then
    echo "  ⚠️  Large autoload size detected (${AUTOLOAD_SIZE} KB)" >> "$REPORT_FILE"
    echo "     → Disable autoload for large/rarely used options" >> "$REPORT_FILE"
    echo -e "  ${YELLOW}⚠️${NC}  Large autoload size (${AUTOLOAD_SIZE} KB)"
    echo -e "     ${CYAN}→${NC} Disable autoload for large options"
    ((RECOMMENDATIONS++))
fi

# Проверка transients
if [ "$TRANSIENT_COUNT" -gt 100 ]; then
    echo "  ⚠️  Many transients found (${TRANSIENT_COUNT})" >> "$REPORT_FILE"
    echo "     → Clean expired transients" >> "$REPORT_FILE"
    echo -e "  ${YELLOW}⚠️${NC}  Many transients (${TRANSIENT_COUNT})"
    echo -e "     ${CYAN}→${NC} Clean expired transients"
    ((RECOMMENDATIONS++))
fi

# Проверка revisions
if [ "$TOTAL_REVISIONS" -gt 100 ]; then
    echo "  ⚠️  Many revisions found (${TOTAL_REVISIONS})" >> "$REPORT_FILE"
    echo "     → Limit or delete old revisions" >> "$REPORT_FILE"
    echo -e "  ${YELLOW}⚠️${NC}  Many revisions (${TOTAL_REVISIONS})"
    echo -e "     ${CYAN}→${NC} Delete old revisions"
    ((RECOMMENDATIONS++))
fi

# Проверка spam/trash
if [ "$SPAM_COMMENTS" -gt 0 ] || [ "$TRASH_COMMENTS" -gt 0 ]; then
    echo "  ⚠️  Spam/trash comments found" >> "$REPORT_FILE"
    echo "     → Delete spam (${SPAM_COMMENTS}) and trash (${TRASH_COMMENTS}) comments" >> "$REPORT_FILE"
    echo -e "  ${YELLOW}⚠️${NC}  Spam/trash comments found"
    echo -e "     ${CYAN}→${NC} Delete spam (${SPAM_COMMENTS}) and trash (${TRASH_COMMENTS})"
    ((RECOMMENDATIONS++))
fi

# Проверка orphaned data
if [ "$ORPHANED_POSTMETA" -gt 0 ]; then
    echo "  ⚠️  Orphaned postmeta found (${ORPHANED_POSTMETA})" >> "$REPORT_FILE"
    echo "     → Clean orphaned postmeta" >> "$REPORT_FILE"
    echo -e "  ${YELLOW}⚠️${NC}  Orphaned postmeta (${ORPHANED_POSTMETA})"
    echo -e "     ${CYAN}→${NC} Clean orphaned metadata"
    ((RECOMMENDATIONS++))
fi

# Проверка фрагментации
if (( $(echo "$TOTAL_FRAGMENTATION > 10" | bc -l 2>/dev/null || echo 0) )); then
    echo "  ⚠️  Significant table fragmentation (${TOTAL_FRAGMENTATION} MB)" >> "$REPORT_FILE"
    echo "     → Run OPTIMIZE TABLE to defragment" >> "$REPORT_FILE"
    echo -e "  ${YELLOW}⚠️${NC}  Table fragmentation (${TOTAL_FRAGMENTATION} MB)"
    echo -e "     ${CYAN}→${NC} Run OPTIMIZE TABLE"
    ((RECOMMENDATIONS++))
fi

# Всегда рекомендуем оптимизацию таблиц
echo "  ✓  Run OPTIMIZE TABLE on all tables" >> "$REPORT_FILE"
echo -e "  ${GREEN}✓${NC}  Run OPTIMIZE TABLE on all tables"
((RECOMMENDATIONS++))

if [ "$RECOMMENDATIONS" -eq 1 ]; then
    echo "" >> "$REPORT_FILE"
    echo "✅ Database is in good shape! Only routine optimization needed." >> "$REPORT_FILE"
    echo ""
    echo -e "${GREEN}✅ Database is in good shape!${NC}"
fi

echo "" >> "$REPORT_FILE"
echo "═══════════════════════════════════════════════════════════════" >> "$REPORT_FILE"
echo "End of Report" >> "$REPORT_FILE"
echo "═══════════════════════════════════════════════════════════════" >> "$REPORT_FILE"

# ============================================
# Создание JSON отчета
# ============================================
cat > "$REPORT_JSON" << EOF
{
  "environment": "${ENVIRONMENT}",
  "database": "${DB_NAME}",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "metrics": {
    "database_size_mb": ${DB_SIZE},
    "table_count": ${TABLE_COUNT},
    "fragmentation_mb": ${TOTAL_FRAGMENTATION},
    "fragmented_tables": ${FRAGMENTED_TABLES},
    "autoload": {
      "size_kb": ${AUTOLOAD_SIZE},
      "count": ${AUTOLOAD_COUNT}
    },
    "transients": {
      "count": ${TRANSIENT_COUNT},
      "size_kb": ${TRANSIENT_SIZE}
    },
    "posts": {
      "published": ${TOTAL_POSTS},
      "pages": ${TOTAL_PAGES},
      "revisions": ${TOTAL_REVISIONS},
      "drafts": ${TOTAL_DRAFTS},
      "trash": ${TOTAL_TRASH}
    },
    "comments": {
      "approved": ${APPROVED_COMMENTS},
      "spam": ${SPAM_COMMENTS},
      "trash": ${TRASH_COMMENTS},
      "pending": ${PENDING_COMMENTS}
    },
    "orphaned": {
      "postmeta": ${ORPHANED_POSTMETA},
      "termmeta": ${ORPHANED_TERMMETA},
      "commentmeta": ${ORPHANED_COMMENTMETA}
    }
  },
  "recommendations_count": ${RECOMMENDATIONS}
}
EOF

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Analysis complete!${NC}"
echo ""
echo -e "Reports saved to:"
echo -e "  ${CYAN}${REPORT_FILE}${NC}"
echo -e "  ${CYAN}${REPORT_JSON}${NC}"
echo ""

# Открыть отчет в less (опционально)
if [ -t 0 ] && [ "$2" != "--no-view" ]; then
    echo -e "View report? (y/n): "
    read -r VIEW_REPORT
    if [[ $VIEW_REPORT =~ ^[Yy]$ ]]; then
        less "$REPORT_FILE"
    fi
fi
