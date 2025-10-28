#!/bin/bash
# 🔍 Search & Replace Utility
# Замена доменов в базе данных WordPress через WP-CLI

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# ФУНКЦИИ
# ============================================

# Показать использование
show_usage() {
    cat << EOF
${BLUE}🔍 Search & Replace Utility${NC}

${YELLOW}Использование:${NC}
  ./search-replace.sh <from_url> <to_url> <environment>

${YELLOW}Аргументы:${NC}
  from_url      - URL для замены (например: http://example.com)
  to_url        - Новый URL (например: http://localhost)
  environment   - Окружение: local, dev, prod

${YELLOW}Примеры:${NC}
  # Заменить домен на локальном окружении
  ./search-replace.sh "http://wordpresstest.ru.xsph.ru" "http://localhost" local

  # Заменить домен на удаленном сервере
  ./search-replace.sh "http://localhost" "http://wordpresstest.ru.xsph.ru" prod

${YELLOW}Что делает:${NC}
  - Ищет и заменяет URL во всех таблицах
  - Корректно обрабатывает сериализованные данные
  - Обрабатывает рекурсивные объекты
  - Показывает отчет об изменениях
  - Очищает кэш после замены

EOF
}

# Выполнить search-replace в локальной БД (Docker)
search_replace_local() {
    local from_url="$1"
    local to_url="$2"
    local db_container="$3"
    local wp_path="$4"
    
    echo -e "${CYAN}→ Выполняю search-replace в локальной БД...${NC}"
    echo -e "   От:  ${RED}${from_url}${NC}"
    echo -e "   К:   ${GREEN}${to_url}${NC}"
    
    # Проверить Docker контейнер
    if ! docker ps | grep -q "$db_container"; then
        echo -e "${RED}✗ Docker контейнер '$db_container' не запущен${NC}"
        exit 1
    fi
    
    # Выполнить search-replace через WP-CLI в контейнере
    docker exec "$db_container" wp search-replace \
        "$from_url" "$to_url" \
        --path="$wp_path" \
        --precise \
        --recurse-objects \
        --all-tables \
        --report-changed-only \
        --skip-columns=guid \
        2>&1 | while IFS= read -r line; do
            echo -e "   $line"
        done
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo -e "${GREEN}✓ Search-replace выполнен${NC}"
        
        # Очистить кэш
        echo -e "\n${CYAN}→ Очистка кэша...${NC}"
        docker exec "$db_container" wp cache flush --path="$wp_path" 2>/dev/null || true
        
        # Обновить permalinks
        echo -e "${CYAN}→ Обновление permalinks...${NC}"
        docker exec "$db_container" wp rewrite flush --path="$wp_path" 2>/dev/null || true
        
        echo -e "${GREEN}✓ Готово!${NC}"
        return 0
    else
        echo -e "${RED}✗ Ошибка при выполнении search-replace${NC}"
        return 1
    fi
}

# Выполнить search-replace на удаленном сервере
search_replace_remote() {
    local from_url="$1"
    local to_url="$2"
    local ssh_user="$3"
    local ssh_host="$4"
    local wp_path="$5"
    
    echo -e "${CYAN}→ Выполняю search-replace на удаленном сервере...${NC}"
    echo -e "   От:  ${RED}${from_url}${NC}"
    echo -e "   К:   ${GREEN}${to_url}${NC}"
    echo -e "   SSH: ${ssh_user}@${ssh_host}"
    
    # Выполнить search-replace через SSH
    ssh "${ssh_user}@${ssh_host}" << ENDSSH
cd ${wp_path}

echo "→ Выполняю search-replace..."
wp search-replace \
    "${from_url}" "${to_url}" \
    --precise \
    --recurse-objects \
    --all-tables \
    --report-changed-only \
    --skip-columns=guid

if [ \$? -eq 0 ]; then
    echo "✓ Search-replace выполнен"
    
    echo "→ Очистка кэша..."
    wp cache flush 2>/dev/null || true
    
    echo "→ Обновление permalinks..."
    wp rewrite flush 2>/dev/null || true
    
    echo "✓ Готово!"
    exit 0
else
    echo "✗ Ошибка при выполнении search-replace"
    exit 1
fi
ENDSSH
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Search-replace успешно выполнен на удаленном сервере${NC}"
        return 0
    else
        echo -e "${RED}✗ Ошибка при выполнении search-replace на удаленном сервере${NC}"
        return 1
    fi
}

# ============================================
# MAIN
# ============================================

FROM_URL="$1"
TO_URL="$2"
ENVIRONMENT="$3"

# Проверка аргументов
if [ -z "$FROM_URL" ] || [ -z "$TO_URL" ] || [ -z "$ENVIRONMENT" ]; then
    show_usage
    exit 1
fi

# Загрузить конфигурацию
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/../config.sh"

echo -e "${BLUE}🔍 Search & Replace${NC}\n"

case "$ENVIRONMENT" in
    local)
        search_replace_local \
            "$FROM_URL" \
            "$TO_URL" \
            "$LOCAL_DB_CONTAINER" \
            "$LOCAL_WP_PATH"
        ;;
    dev)
        search_replace_remote \
            "$FROM_URL" \
            "$TO_URL" \
            "$DEV_SSH_USER" \
            "$DEV_SSH_HOST" \
            "$DEV_WP_PATH"
        ;;
    prod)
        echo -e "${RED}⚠️  ВНИМАНИЕ: Замена домена на ПРОДАКШЕНЕ!${NC}"
        read -p "Вы уверены? Введите 'yes' для подтверждения: " confirm
        
        if [ "$confirm" != "yes" ]; then
            echo -e "${YELLOW}Отменено${NC}"
            exit 0
        fi
        
        search_replace_remote \
            "$FROM_URL" \
            "$TO_URL" \
            "$PROD_SSH_USER" \
            "$PROD_SSH_HOST" \
            "$PROD_WP_PATH"
        ;;
    *)
        echo -e "${RED}✗ Неизвестное окружение: $ENVIRONMENT${NC}"
        echo "Используйте: local, dev или prod"
        exit 1
        ;;
esac
