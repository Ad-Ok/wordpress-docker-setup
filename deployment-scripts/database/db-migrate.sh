#!/bin/bash
# 🗄️ Database Migration Manager
# Система управления миграциями базы данных

set -e

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Директория миграций (теперь в сабмодуле wordpress)
MIGRATIONS_DIR="${LOCAL_MIGRATIONS_DIR}"
APPLIED_LOG="${MIGRATIONS_DIR}/.applied.json"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ============================================
# ФУНКЦИИ
# ============================================

# Показать использование
show_usage() {
    cat << EOF
${BLUE}🗄️ Database Migration Manager${NC}

${YELLOW}Использование:${NC}
  ./db-migrate.sh <command> [environment] [options]

${YELLOW}Команды:${NC}
  ${GREEN}apply${NC} <env>         Применить все новые миграции
  ${GREEN}status${NC} <env>        Показать статус миграций
  ${GREEN}list${NC}                Показать все миграции

${YELLOW}Окружения:${NC}
  ${CYAN}local${NC}  - Локальная БД (Docker)
  ${CYAN}dev${NC}    - Development сервер
  ${CYAN}prod${NC}   - Production сервер

${YELLOW}Примеры:${NC}
  # Применить миграции на локальной БД
  ./db-migrate.sh apply local

  # Применить миграции на DEV
  ./db-migrate.sh apply dev

  # Применить миграции на PROD
  ./db-migrate.sh apply prod

  # Показать статус
  ./db-migrate.sh status local

  # Показать все миграции
  ./db-migrate.sh list

${YELLOW}Создание миграции:${NC}
  Используйте: ${CYAN}./db-create-migration.sh "описание"${NC}

${YELLOW}Формат миграции:${NC}
  001_description.sql  - Номер должен быть уникальным
  Миграции применяются в порядке номеров

${YELLOW}Отслеживание:${NC}
  Примененные миграции хранятся в: ${MIGRATIONS_DIR}/.applied.json

EOF
}

# Инициализировать файл примененных миграций
init_applied_log() {
    if [ ! -f "$APPLIED_LOG" ]; then
        echo '{"migrations": []}' > "$APPLIED_LOG"
    fi
}

# Получить список всех миграций
get_all_migrations() {
    find "${MIGRATIONS_DIR}" -name "[0-9][0-9][0-9]_*.sql" 2>/dev/null | sort || true
}

# Получить список примененных миграций для окружения
get_applied_migrations() {
    local environment="$1"
    init_applied_log
    
    # Для удаленных окружений читаем файл с сервера
    if [ "$environment" == "dev" ] || [ "$environment" == "prod" ]; then
        local SSH_USER SSH_HOST REMOTE_MIGRATIONS_DIR
        
        case "$environment" in
            dev)
                SSH_USER="$DEV_SSH_USER"
                SSH_HOST="$DEV_SSH_HOST"
                REMOTE_MIGRATIONS_DIR="$DEV_MIGRATIONS_DIR"
                ;;
            prod)
                SSH_USER="$PROD_SSH_USER"
                SSH_HOST="$PROD_SSH_HOST"
                REMOTE_MIGRATIONS_DIR="$PROD_MIGRATIONS_DIR"
                ;;
        esac
        
        ssh "${SSH_USER}@${SSH_HOST}" "cat ${REMOTE_MIGRATIONS_DIR}/.applied.json 2>/dev/null || echo '{\"migrations\": []}'" | \
            jq -r --arg env "$environment" \
                '.migrations[] | select(.environment == $env) | .file' 2>/dev/null || true
    else
        # Локально читаем локальный файл
        jq -r --arg env "$environment" \
            '.migrations[] | select(.environment == $env) | .file' \
            "$APPLIED_LOG" 2>/dev/null || true
    fi
}

# Проверить, применена ли миграция
is_migration_applied() {
    local migration_file="$1"
    local environment="$2"
    
    local applied=$(get_applied_migrations "$environment")
    echo "$applied" | grep -q "^${migration_file}$"
}

# Отметить миграцию как примененную
mark_migration_applied() {
    local migration_file="$1"
    local environment="$2"
    
    init_applied_log
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Для удаленных окружений обновляем файл на сервере
    if [ "$environment" == "dev" ] || [ "$environment" == "prod" ]; then
        local SSH_USER SSH_HOST REMOTE_MIGRATIONS_DIR
        
        case "$environment" in
            dev)
                SSH_USER="$DEV_SSH_USER"
                SSH_HOST="$DEV_SSH_HOST"
                REMOTE_MIGRATIONS_DIR="$DEV_MIGRATIONS_DIR"
                ;;
            prod)
                SSH_USER="$PROD_SSH_USER"
                SSH_HOST="$PROD_SSH_HOST"
                REMOTE_MIGRATIONS_DIR="$PROD_MIGRATIONS_DIR"
                ;;
        esac
        
        ssh "${SSH_USER}@${SSH_HOST}" "cd ${REMOTE_MIGRATIONS_DIR} && python3 << 'PYEOF'
import json
from datetime import datetime, timezone

# Read current .applied.json
try:
    with open('.applied.json', 'r') as f:
        data = json.load(f)
except:
    data = {'migrations': []}

# Add new migration
new_migration = {
    'file': '${migration_file}',
    'environment': '${environment}',
    'applied_at': '${timestamp}'
}

data['migrations'].append(new_migration)

# Write back
with open('.applied.json', 'w') as f:
    json.dump(data, f, indent=2)
PYEOF
"
    else
        # Локально обновляем локальный файл
        local temp_file=$(mktemp)
        
        jq --arg file "$migration_file" \
           --arg env "$environment" \
           --arg ts "$timestamp" \
           '.migrations += [{
               "file": $file,
               "environment": $env,
               "applied_at": $ts
           }]' "$APPLIED_LOG" > "$temp_file"
        
        mv "$temp_file" "$APPLIED_LOG"
    fi
}

# Показать список миграций
list_migrations() {
    echo -e "${BLUE}📋 Список миграций:${NC}\n"
    
    local migrations=$(get_all_migrations)
    
    if [ -z "$migrations" ]; then
        echo -e "${YELLOW}Нет миграций в ${MIGRATIONS_DIR}${NC}"
        echo -e "\nСоздайте миграцию: ${CYAN}./db-create-migration.sh \"описание\"${NC}"
        return 0
    fi
    
    echo "$migrations" | while read -r migration_path; do
        local migration_file=$(basename "$migration_path")
        local migration_number=$(echo "$migration_file" | cut -d'_' -f1)
        local migration_desc=$(echo "$migration_file" | sed 's/^[0-9]*_//;s/.sql$//' | tr '_' ' ')
        
        # Проверить применение на разных окружениях
        local status_local=" "
        local status_dev=" "
        local status_prod=" "
        
        if is_migration_applied "$migration_file" "local" 2>/dev/null; then
            status_local="${GREEN}✓${NC}"
        fi
        if is_migration_applied "$migration_file" "dev" 2>/dev/null; then
            status_dev="${GREEN}✓${NC}"
        fi
        if is_migration_applied "$migration_file" "prod" 2>/dev/null; then
            status_prod="${GREEN}✓${NC}"
        fi
        
        echo -e "${CYAN}${migration_number}${NC} ${migration_desc}"
        echo -e "   ${BLUE}├─${NC} Local: [${status_local}]  Dev: [${status_dev}]  Prod: [${status_prod}]"
        echo -e "   ${BLUE}└─${NC} Файл: ${migration_file}"
        echo ""
    done
}

# Показать статус миграций для окружения
show_status() {
    local environment="$1"
    
    if [ -z "$environment" ]; then
        echo -e "${RED}✗ Укажите окружение: local, dev или prod${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📊 Статус миграций для: ${CYAN}${environment}${NC}\n"
    
    local all_migrations=$(get_all_migrations)
    local applied_migrations=$(get_applied_migrations "$environment")
    
    if [ -z "$all_migrations" ]; then
        echo -e "${YELLOW}Нет миграций${NC}"
        return 0
    fi
    
    local pending_count=0
    local applied_count=0
    
    echo "$all_migrations" | while read -r migration_path; do
        local migration_file=$(basename "$migration_path")
        
        if echo "$applied_migrations" | grep -q "^${migration_file}$"; then
            echo -e "   ${GREEN}✓${NC} ${migration_file}"
            applied_count=$((applied_count + 1))
        else
            echo -e "   ${YELLOW}○${NC} ${migration_file} ${YELLOW}(не применена)${NC}"
            pending_count=$((pending_count + 1))
        fi
    done
    
    local total=$(echo "$all_migrations" | wc -l | tr -d ' ')
    local applied=$(echo "$applied_migrations" | wc -l | tr -d ' ')
    local pending=$((total - applied))
    
    echo ""
    echo -e "${CYAN}Итого:${NC} $total миграций"
    echo -e "  ${GREEN}✓${NC} Применено: $applied"
    echo -e "  ${YELLOW}○${NC} Ожидает: $pending"
}

# Применить миграцию локально (Docker)
apply_migration_local() {
    local migration_file="$1"
    local migration_path="${MIGRATIONS_DIR}/${migration_file}"
    
    if [ ! -f "$migration_path" ]; then
        echo -e "${RED}✗ Файл миграции не найден: $migration_path${NC}"
        return 1
    fi
    
    # Проверить Docker
    if ! docker ps | grep -q "${LOCAL_DB_CONTAINER}"; then
        echo -e "${RED}✗ Docker контейнер '${LOCAL_DB_CONTAINER}' не запущен${NC}"
        return 1
    fi
    
    echo -e "${CYAN}→ Применяю миграцию: ${migration_file}${NC}"
    
    # Применить миграцию
    docker exec -i "${LOCAL_DB_CONTAINER}" \
        mysql \
        -u"${LOCAL_DB_USER}" \
        -p"${LOCAL_DB_PASS}" \
        "${LOCAL_DB_NAME}" \
        < "$migration_path" 2>&1 | sed 's/^/   /'
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo -e "   ${GREEN}✓${NC} Миграция применена"
        mark_migration_applied "$migration_file" "local"
        return 0
    else
        echo -e "   ${RED}✗${NC} Ошибка при применении миграции"
        return 1
    fi
}

# Применить миграцию на удаленном сервере
apply_migration_remote() {
    local migration_file="$1"
    local environment="$2"
    local migration_path="${MIGRATIONS_DIR}/${migration_file}"
    
    if [ ! -f "$migration_path" ]; then
        echo -e "${RED}✗ Файл миграции не найден: $migration_path${NC}"
        return 1
    fi
    
    # Выбрать параметры окружения
    case "$environment" in
        dev)
            SSH_USER="$DEV_SSH_USER"
            SSH_HOST="$DEV_SSH_HOST"
            REMOTE_WP_PATH="$DEV_WP_PATH"
            DB_NAME="$DEV_DB_NAME"
            DB_USER="$DEV_DB_USER"
            DB_PASS="$DEV_DB_PASS"
            ;;
        prod)
            SSH_USER="$PROD_SSH_USER"
            SSH_HOST="$PROD_SSH_HOST"
            REMOTE_WP_PATH="$PROD_WP_PATH"
            DB_NAME="$PROD_DB_NAME"
            DB_USER="$PROD_DB_USER"
            DB_PASS="$PROD_DB_PASS"
            ;;
    esac
    
    echo -e "${CYAN}→ Применяю миграцию на ${environment}: ${migration_file}${NC}"
    
    # Отправить и применить миграцию
    cat "$migration_path" | ssh "${SSH_USER}@${SSH_HOST}" \
        "mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME}" 2>&1 | sed 's/^/   /'
    
    if [ ${PIPESTATUS[1]} -eq 0 ]; then
        echo -e "   ${GREEN}✓${NC} Миграция применена на ${environment}"
        mark_migration_applied "$migration_file" "$environment"
        return 0
    else
        echo -e "   ${RED}✗${NC} Ошибка при применении миграции на ${environment}"
        return 1
    fi
}

# Применить все новые миграции
apply_migrations() {
    local environment="$1"
    
    if [ -z "$environment" ]; then
        echo -e "${RED}✗ Укажите окружение: local, dev или prod${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🚀 Применение миграций на: ${CYAN}${environment}${NC}\n"
    
    # Получить список миграций
    local all_migrations=$(get_all_migrations)
    
    if [ -z "$all_migrations" ]; then
        echo -e "${YELLOW}Нет миграций для применения${NC}"
        return 0
    fi
    
    local applied_migrations=$(get_applied_migrations "$environment")
    local pending_migrations=""
    
    # Найти неприменённые миграции
    echo "$all_migrations" | while read -r migration_path; do
        local migration_file=$(basename "$migration_path")
        
        if ! echo "$applied_migrations" | grep -q "^${migration_file}$"; then
            echo "$migration_file"
        fi
    done > /tmp/pending_migrations_$$
    
    pending_migrations=$(cat /tmp/pending_migrations_$$)
    rm -f /tmp/pending_migrations_$$
    
    if [ -z "$pending_migrations" ]; then
        echo -e "${GREEN}✓ Все миграции уже применены${NC}"
        return 0
    fi
    
    # Показать список миграций для применения
    echo -e "${YELLOW}Миграции для применения:${NC}"
    echo "$pending_migrations" | while read -r migration_file; do
        echo -e "   ${CYAN}•${NC} $migration_file"
    done
    echo ""
    
    # Подтверждение для PROD
    if [ "$environment" == "prod" ]; then
        echo -e "${RED}⚠️  ВНИМАНИЕ: Применение миграций на ПРОДАКШЕНЕ!${NC}"
        read -p "Продолжить? (yes/no): " confirm
        
        if [ "$confirm" != "yes" ]; then
            echo -e "${YELLOW}Отменено${NC}"
            exit 0
        fi
    fi
    
    # Создать backup перед применением
    if [ "$environment" == "local" ]; then
        echo -e "${CYAN}→ Создаю snapshot перед миграцией...${NC}"
        "${SCRIPT_DIR}/database/db-snapshot.sh" create "before-migration" > /dev/null 2>&1
        echo -e "   ${GREEN}✓${NC} Snapshot создан\n"
    else
        echo -e "${CYAN}→ Создаю backup на ${environment}...${NC}"
        "${SCRIPT_DIR}/utils/backup.sh" "$environment" > /dev/null 2>&1
        echo -e "   ${GREEN}✓${NC} Backup создан\n"
    fi
    
    # Применить миграции
    local temp_dir="$(mktemp -d)"
    local success_file="${temp_dir}/success"
    local fail_file="${temp_dir}/fail"
    
    echo "$pending_migrations" | while read -r migration_file; do
        if [ "$environment" == "local" ]; then
            if apply_migration_local "$migration_file"; then
                echo "1" >> "$success_file"
            else
                echo "1" >> "$fail_file"
                break
            fi
        else
            if apply_migration_remote "$migration_file" "$environment"; then
                echo "1" >> "$success_file"
            else
                echo "1" >> "$fail_file"
                break
            fi
        fi
        echo ""
    done
    
    local success_count=$(wc -l < "$success_file" 2>/dev/null | tr -d ' ' || echo 0)
    local fail_count=$(wc -l < "$fail_file" 2>/dev/null | tr -d ' ' || echo 0)
    
    # Итоги
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    local pending_count=$(echo "$pending_migrations" | wc -l | tr -d ' ')
    
    if [ "$fail_count" -eq 0 ]; then
        echo -e "${GREEN}✅ Все миграции успешно применены!${NC}"
        echo -e "   Применено: ${pending_count}"
    else
        echo -e "${RED}❌ Применение миграций завершилось с ошибками${NC}"
        echo -e "   Успешно: ${success_count}"
        echo -e "   Ошибок: ${fail_count}"
        echo ""
        echo -e "${YELLOW}Рекомендация:${NC}"
        echo -e "   1. Исправьте ошибку в миграции"
        echo -e "   2. Откатите изменения (если нужно)"
        if [ "$environment" == "local" ]; then
            echo -e "   3. Восстановите snapshot: ${CYAN}./db-snapshot.sh restore latest${NC}"
        else
            echo -e "   3. Восстановите backup: ${CYAN}./rollback.sh${NC}"
        fi
    fi
    
    # Очистка временных файлов
    rm -rf "$temp_dir"
}

# ============================================
# MAIN
# ============================================

COMMAND="$1"
ENVIRONMENT="$2"

case "$COMMAND" in
    apply)
        apply_migrations "$ENVIRONMENT"
        ;;
    status)
        show_status "$ENVIRONMENT"
        ;;
    list)
        list_migrations
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
