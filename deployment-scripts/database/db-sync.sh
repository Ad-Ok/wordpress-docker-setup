#!/bin/bash
# 🔄 Database Sync Script
# Полная синхронизация базы данных между окружениями

set -e

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"

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
${BLUE}🔄 Database Sync${NC}

${YELLOW}Использование:${NC}
  ./db-sync.sh <operation> <environment>

${YELLOW}Операции:${NC}
  ${GREEN}pull${NC}   - Загрузить БД с удаленного сервера (REMOTE → LOCAL)
  ${GREEN}push${NC}   - Отправить БД на удаленный сервер (LOCAL → REMOTE)

${YELLOW}Окружения:${NC}
  ${CYAN}prod${NC}   - Production сервер
  ${CYAN}dev${NC}    - Development сервер

${YELLOW}Примеры:${NC}
  # Загрузить БД с продакшена на локалку
  ./db-sync.sh pull prod

  # Загрузить БД с дева на локалку
  ./db-sync.sh pull dev

  # Отправить локальную БД на продакшен (для initial deploy)
  ./db-sync.sh push prod

${YELLOW}Что делает:${NC}
  1. Создает backup текущей БД (на всякий случай)
  2. Экспортирует/импортирует базу данных
  3. Автоматически заменяет домены (search-replace)
  4. Очищает кэш и permalinks
  5. Сохраняет snapshot для отката

${YELLOW}ВНИМАНИЕ:${NC}
  - PULL заменит вашу локальную БД
  - PUSH заменит удаленную БД (используйте осторожно!)

EOF
}

# Проверить Docker
check_docker() {
    if ! docker ps &> /dev/null; then
        echo -e "${RED}✗ Docker не запущен${NC}"
        exit 1
    fi
    
    if ! docker ps | grep -q "${LOCAL_DB_CONTAINER}"; then
        echo -e "${YELLOW}⚠️  MySQL контейнер не запущен. Запускаю...${NC}"
        docker start "${LOCAL_DB_CONTAINER}"
        sleep 3
    fi
}

# PULL: Загрузить БД с удаленного сервера
pull_database() {
    local environment="$1"
    
    # Выбрать параметры окружения
    case "$environment" in
        prod)
            SSH_USER="$PROD_SSH_USER"
            SSH_HOST="$PROD_SSH_HOST"
            REMOTE_WP_PATH="$PROD_WP_PATH"
            REMOTE_URL="$PROD_SITE_URL"
            ;;
        dev)
            SSH_USER="$DEV_SSH_USER"
            SSH_HOST="$DEV_SSH_HOST"
            REMOTE_WP_PATH="$DEV_WP_PATH"
            REMOTE_URL="$DEV_SITE_URL"
            ;;
        *)
            echo -e "${RED}✗ Неизвестное окружение: $environment${NC}"
            exit 1
            ;;
    esac
    
    local ENV_UPPER=$(echo "$environment" | tr '[:lower:]' '[:upper:]')
    
    echo -e "${BLUE}🔄 Загрузка БД: ${ENV_UPPER} → LOCAL${NC}\n"
    echo -e "   От:  ${CYAN}${REMOTE_URL}${NC}"
    echo -e "   К:   ${GREEN}${LOCAL_SITE_URL}${NC}"
    echo ""
    
    # Подтверждение
    echo -e "${YELLOW}⚠️  ВНИМАНИЕ: Локальная база данных будет ЗАМЕНЕНА!${NC}"
    read -p "Продолжить? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Отменено${NC}"
        exit 0
    fi
    
    check_docker
    
    # 1. Создать snapshot текущей локальной БД
    echo -e "\n${BLUE}[1/5]${NC} ${CYAN}Создаю snapshot текущей БД...${NC}"
    "${SCRIPT_DIR}/database/db-snapshot.sh" create "before-pull-${environment}" > /dev/null
    echo -e "   ${GREEN}✓${NC} Snapshot создан"
    
    # 2. Экспортировать БД с удаленного сервера
    echo -e "\n${BLUE}[2/5]${NC} ${CYAN}Экспортирую БД с ${ENV_UPPER}...${NC}"
    
    local temp_dump="/tmp/db-sync-${environment}-$(date +%Y%m%d_%H%M%S).sql.gz"
    
    # Определяем путь к WP-CLI для окружения
    local REMOTE_WP_CLI=""
    if [ "$environment" == "prod" ]; then
        REMOTE_WP_CLI="${PROD_WP_CLI}"
    else
        REMOTE_WP_CLI="${DEV_WP_CLI}"
    fi
    
    ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH | gzip > "${temp_dump}"
cd ${REMOTE_WP_PATH}
${REMOTE_WP_CLI} db export - 2>/dev/null
ENDSSH
    
    if [ $? -eq 0 ]; then
        local size=$(du -h "${temp_dump}" | cut -f1)
        echo -e "   ${GREEN}✓${NC} БД экспортирована (${size})"
    else
        echo -e "   ${RED}✗${NC} Ошибка при экспорте БД"
        rm -f "${temp_dump}"
        exit 1
    fi
    
    # 3. Импортировать БД в локальный Docker
    echo -e "\n${BLUE}[3/5]${NC} ${CYAN}Импортирую БД в локальный Docker...${NC}"
    
    # Фильтруем DEFINER для совместимости с локальным MySQL
    gunzip -c "${temp_dump}" | \
        sed 's/DEFINER=[^ ]*//g' | \
        docker exec -i "${LOCAL_DB_CONTAINER}" \
        mysql \
        -u"${LOCAL_DB_USER}" \
        -p"${LOCAL_DB_PASS}" \
        "${LOCAL_DB_NAME}" \
        2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}✓${NC} БД импортирована"
    else
        echo -e "   ${RED}✗${NC} Ошибка при импорте БД"
        rm -f "${temp_dump}"
        exit 1
    fi
    
    # Удалить временный файл
    rm -f "${temp_dump}"
    
    # 4. Заменить домены
    echo -e "\n${BLUE}[4/5]${NC} ${CYAN}Замена доменов...${NC}"
    
    "${SCRIPT_DIR}/database/utils/search-replace.sh" \
        "${REMOTE_URL}" \
        "${LOCAL_SITE_URL}" \
        "local" | sed 's/^/   /'
    
    # 5. Создать новый snapshot после импорта
    echo -e "\n${BLUE}[5/5]${NC} ${CYAN}Создаю snapshot после импорта...${NC}"
    "${SCRIPT_DIR}/database/db-snapshot.sh" create "after-pull-${environment}" > /dev/null
    echo -e "   ${GREEN}✓${NC} Snapshot создан"
    
    echo -e "\n${GREEN}✅ БД успешно загружена с ${ENV_UPPER}!${NC}"
    echo -e "\n${CYAN}Что дальше:${NC}"
    echo -e "   1. Проверьте сайт: ${LOCAL_SITE_URL}"
    echo -e "   2. Если нужно откатиться: ${YELLOW}./db-snapshot.sh restore latest${NC}"
}

# PUSH: Отправить БД на удаленный сервер
push_database() {
    local environment="$1"
    
    # PUSH разрешен только на PROD для initial deploy
    if [ "$environment" != "prod" ]; then
        echo -e "${RED}✗ PUSH разрешен только на PROD${NC}"
        echo -e "Для DEV используйте миграции: ${CYAN}./db-migrate.sh apply dev${NC}"
        exit 1
    fi
    
    SSH_USER="$PROD_SSH_USER"
    SSH_HOST="$PROD_SSH_HOST"
    REMOTE_WP_PATH="$PROD_WP_PATH"
    REMOTE_URL="$PROD_SITE_URL"
    
    echo -e "${BLUE}🚀 Отправка БД: LOCAL → PROD${NC}\n"
    echo -e "   От:  ${CYAN}${LOCAL_SITE_URL}${NC}"
    echo -e "   К:   ${GREEN}${REMOTE_URL}${NC}"
    echo ""
    
    # Предупреждение
    echo -e "${RED}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ⚠️  КРИТИЧЕСКОЕ ПРЕДУПРЕЖДЕНИЕ ⚠️                 ║${NC}"
    echo -e "${RED}║                                                    ║${NC}"
    echo -e "${RED}║  Вы собираетесь ЗАМЕНИТЬ базу данных ПРОДАКШЕНА!  ║${NC}"
    echo -e "${RED}║  Все данные будут ПОТЕРЯНЫ!                        ║${NC}"
    echo -e "${RED}║                                                    ║${NC}"
    echo -e "${RED}║  Используйте только для Initial Deploy!           ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "Введите 'REPLACE DATABASE' для подтверждения: " confirm
    
    if [ "$confirm" != "REPLACE DATABASE" ]; then
        echo -e "${YELLOW}Отменено${NC}"
        exit 0
    fi
    
    check_docker
    
    # 1. Создать backup на удаленном сервере
    echo -e "\n${BLUE}[1/5]${NC} ${CYAN}Создаю backup на PROD...${NC}"
    
    ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
cd ${REMOTE_WP_PATH}
echo "→ Создаю backup..."
mkdir -p ../backups
wp db export ../backups/backup-before-initial-deploy-\$(date +%Y%m%d_%H%M%S).sql.gz
echo "✓ Backup создан"
ENDSSH
    
    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}✓${NC} Backup создан на PROD"
    else
        echo -e "   ${RED}✗${NC} Ошибка при создании backup"
        exit 1
    fi
    
    # 2. Экспортировать локальную БД
    echo -e "\n${BLUE}[2/5]${NC} ${CYAN}Экспортирую локальную БД...${NC}"
    
    local temp_dump="/tmp/db-sync-push-$(date +%Y%m%d_%H%M%S).sql.gz"
    
    docker exec "${LOCAL_DB_CONTAINER}" \
        mysqldump \
        -u"${LOCAL_DB_USER}" \
        -p"${LOCAL_DB_PASS}" \
        "${LOCAL_DB_NAME}" \
        2>/dev/null | gzip > "${temp_dump}"
    
    if [ $? -eq 0 ]; then
        local size=$(du -h "${temp_dump}" | cut -f1)
        echo -e "   ${GREEN}✓${NC} БД экспортирована (${size})"
    else
        echo -e "   ${RED}✗${NC} Ошибка при экспорте БД"
        rm -f "${temp_dump}"
        exit 1
    fi
    
    # 3. Заменить домены ПЕРЕД отправкой
    echo -e "\n${BLUE}[3/5]${NC} ${CYAN}Подготовка БД (замена доменов)...${NC}"
    
    # Распаковать, заменить через WP-CLI в локальном контейнере, упаковать обратно
    local temp_replaced="/tmp/db-sync-replaced-$(date +%Y%m%d_%H%M%S).sql.gz"
    
    gunzip -c "${temp_dump}" | docker exec -i "${LOCAL_DB_CONTAINER}" \
        mysql \
        -u"${LOCAL_DB_USER}" \
        -p"${LOCAL_DB_PASS}" \
        --database="${LOCAL_DB_NAME}_temp" \
        2>/dev/null
    
    docker exec "${LOCAL_DB_CONTAINER}" \
        wp search-replace \
        "${LOCAL_SITE_URL}" \
        "${REMOTE_URL}" \
        --path="${LOCAL_WP_PATH}" \
        --precise \
        --recurse-objects \
        --all-tables \
        --url="${LOCAL_SITE_URL}" \
        --skip-columns=guid \
        2>/dev/null | sed 's/^/   /'
    
    docker exec "${LOCAL_DB_CONTAINER}" \
        mysqldump \
        -u"${LOCAL_DB_USER}" \
        -p"${LOCAL_DB_PASS}" \
        "${LOCAL_DB_NAME}" \
        2>/dev/null | gzip > "${temp_replaced}"
    
    echo -e "   ${GREEN}✓${NC} Домены заменены"
    
    # 4. Отправить БД на PROD
    echo -e "\n${BLUE}[4/5]${NC} ${CYAN}Отправляю БД на PROD...${NC}"
    
    gunzip -c "${temp_replaced}" | ssh "${SSH_USER}@${SSH_HOST}" \
        "cd ${REMOTE_WP_PATH} && wp db import -"
    
    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}✓${NC} БД импортирована на PROD"
    else
        echo -e "   ${RED}✗${NC} Ошибка при импорте БД на PROD"
        rm -f "${temp_dump}" "${temp_replaced}"
        exit 1
    fi
    
    # Удалить временные файлы
    rm -f "${temp_dump}" "${temp_replaced}"
    
    # 5. Очистить кэш на PROD
    echo -e "\n${BLUE}[5/5]${NC} ${CYAN}Очистка кэша на PROD...${NC}"
    
    ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
cd ${REMOTE_WP_PATH}
wp cache flush 2>/dev/null || true
wp rewrite flush 2>/dev/null || true
echo "✓ Кэш очищен"
ENDSSH
    
    echo -e "\n${GREEN}✅ БД успешно отправлена на PROD!${NC}"
    echo -e "\n${CYAN}Что дальше:${NC}"
    echo -e "   1. Проверьте сайт: ${REMOTE_URL}"
    echo -e "   2. Если нужно откатиться, используйте backup на сервере"
}

# ============================================
# MAIN
# ============================================

OPERATION="$1"
ENVIRONMENT="$2"

# Проверка аргументов
if [ -z "$OPERATION" ] || [ -z "$ENVIRONMENT" ]; then
    show_usage
    exit 1
fi

case "$OPERATION" in
    pull)
        pull_database "$ENVIRONMENT"
        ;;
    push)
        push_database "$ENVIRONMENT"
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo -e "${RED}✗ Неизвестная операция: $OPERATION${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac
