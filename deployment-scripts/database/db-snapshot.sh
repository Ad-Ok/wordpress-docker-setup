#!/bin/bash
# 📸 Database Snapshot Manager
# Управление снапшотами базы данных для разных веток

set -e

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# ФУНКЦИИ
# ============================================

# Показать использование
show_usage() {
    cat << EOF
${BLUE}📸 Database Snapshot Manager${NC}

${YELLOW}Использование:${NC}
  ./db-snapshot.sh <command> [options]

${YELLOW}Команды:${NC}
  ${GREEN}create${NC} [description]     Создать snapshot текущей БД
  ${GREEN}list${NC}                     Показать все snapshots
  ${GREEN}restore${NC} <snapshot>       Восстановить snapshot
  ${GREEN}cleanup${NC}                  Удалить старые snapshots
  ${GREEN}auto-save${NC}                Автосохранение для текущей ветки
  ${GREEN}auto-restore${NC}             Автовосстановление для текущей ветки

${YELLOW}Примеры:${NC}
  # Создать snapshot с описанием
  ./db-snapshot.sh create "before migration"

  # Показать все snapshots
  ./db-snapshot.sh list

  # Восстановить конкретный snapshot
  ./db-snapshot.sh restore main_20251029_153022

  # Восстановить последний snapshot для текущей ветки
  ./db-snapshot.sh restore latest

  # Удалить старые snapshots
  ./db-snapshot.sh cleanup

${YELLOW}Автоматическое использование (через Git hook):${NC}
  ./db-snapshot.sh auto-save      # Сохранить БД текущей ветки
  ./db-snapshot.sh auto-restore   # Восстановить БД новой ветки

EOF
}

# Получить текущую ветку Git
get_current_branch() {
    git -C "${LOCAL_PROJECT_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

# Нормализовать имя ветки для использования в имени файла
normalize_branch_name() {
    echo "$1" | sed 's/[^a-zA-Z0-9_-]/_/g'
}

# Создать имя файла snapshot
create_snapshot_filename() {
    local branch="$1"
    local description="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local normalized_branch=$(normalize_branch_name "$branch")
    
    if [ -n "$description" ]; then
        local normalized_desc=$(normalize_branch_name "$description")
        echo "${normalized_branch}_${timestamp}_${normalized_desc}.sql.gz"
    else
        echo "${normalized_branch}_${timestamp}.sql.gz"
    fi
}

# Проверить, запущен ли Docker
check_docker() {
    if ! docker ps &> /dev/null; then
        echo -e "${RED}✗ Docker не запущен${NC}"
        echo "Запустите Docker Desktop и попробуйте снова"
        exit 1
    fi
}

# Проверить, существует ли контейнер MySQL
check_mysql_container() {
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${LOCAL_DB_CONTAINER}$"; then
        echo -e "${RED}✗ MySQL контейнер '${LOCAL_DB_CONTAINER}' не найден${NC}"
        echo "Запустите: docker compose up -d"
        exit 1
    fi
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${LOCAL_DB_CONTAINER}$"; then
        echo -e "${YELLOW}⚠️  MySQL контейнер не запущен. Запускаю...${NC}"
        docker start "${LOCAL_DB_CONTAINER}"
        sleep 3
    fi
}

# Создать snapshot
create_snapshot() {
    local description="$1"
    local current_branch=$(get_current_branch)
    
    echo -e "${BLUE}📸 Создание snapshot базы данных...${NC}"
    echo -e "   Ветка: ${GREEN}${current_branch}${NC}"
    
    check_docker
    check_mysql_container
    
    # Создать директорию для snapshots
    mkdir -p "${LOCAL_SNAPSHOT_DIR}"
    
    # Создать имя файла
    local snapshot_file=$(create_snapshot_filename "$current_branch" "$description")
    local snapshot_path="${LOCAL_SNAPSHOT_DIR}/${snapshot_file}"
    
    echo -e "   Файл: ${snapshot_file}"
    
    # Экспорт базы данных
    echo -e "\n${CYAN}→ Экспортирую базу данных...${NC}"
    
    docker exec "${LOCAL_DB_CONTAINER}" \
        mysqldump \
        -u"${LOCAL_DB_USER}" \
        -p"${LOCAL_DB_PASS}" \
        "${LOCAL_DB_NAME}" \
        2>/dev/null | gzip > "${snapshot_path}"
    
    if [ $? -eq 0 ]; then
        local size=$(du -h "${snapshot_path}" | cut -f1)
        echo -e "${GREEN}✓ Snapshot создан: ${snapshot_file} (${size})${NC}"
        
        # Сохранить метаданные
        save_snapshot_metadata "$snapshot_file" "$current_branch" "$description"
        
        # Очистить старые snapshots для этой ветки
        cleanup_old_snapshots "$current_branch"
        
        return 0
    else
        echo -e "${RED}✗ Ошибка при создании snapshot${NC}"
        rm -f "${snapshot_path}"
        return 1
    fi
}

# Сохранить метаданные snapshot
save_snapshot_metadata() {
    local snapshot_file="$1"
    local branch="$2"
    local description="$3"
    local metadata_file="${LOCAL_SNAPSHOT_DIR}/.metadata.json"
    
    # Создать или загрузить существующий файл метаданных
    if [ ! -f "$metadata_file" ]; then
        echo "[]" > "$metadata_file"
    fi
    
    # Добавить новую запись
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local temp_file=$(mktemp)
    
    jq --arg file "$snapshot_file" \
       --arg branch "$branch" \
       --arg desc "$description" \
       --arg ts "$timestamp" \
       '. += [{
           "file": $file,
           "branch": $branch,
           "description": $desc,
           "created_at": $ts
       }]' "$metadata_file" > "$temp_file"
    
    mv "$temp_file" "$metadata_file"
}

# Показать список snapshots
list_snapshots() {
    echo -e "${BLUE}📋 Список snapshots:${NC}\n"
    
    if [ ! -d "${LOCAL_SNAPSHOT_DIR}" ] || [ -z "$(ls -A ${LOCAL_SNAPSHOT_DIR}/*.sql.gz 2>/dev/null)" ]; then
        echo -e "${YELLOW}Нет сохраненных snapshots${NC}"
        return 0
    fi
    
    local metadata_file="${LOCAL_SNAPSHOT_DIR}/.metadata.json"
    local current_branch=$(get_current_branch)
    
    # Группировка по веткам
    local branches=($(ls "${LOCAL_SNAPSHOT_DIR}"/*.sql.gz 2>/dev/null | xargs -n 1 basename | cut -d'_' -f1 | sort -u))
    
    for branch in "${branches[@]}"; do
        if [ "$branch" == "$current_branch" ]; then
            echo -e "${GREEN}■${NC} ${CYAN}${branch}${NC} ${YELLOW}(текущая)${NC}"
        else
            echo -e "${MAGENTA}■${NC} ${branch}"
        fi
        
        # Показать snapshots для этой ветки
        ls -t "${LOCAL_SNAPSHOT_DIR}/${branch}"_*.sql.gz 2>/dev/null | while read -r snapshot_path; do
            local snapshot_file=$(basename "$snapshot_path")
            local size=$(du -h "$snapshot_path" | cut -f1)
            local date=$(echo "$snapshot_file" | cut -d'_' -f2-3 | sed 's/_/ /')
            local description=""
            
            # Получить описание из метаданных
            if [ -f "$metadata_file" ]; then
                description=$(jq -r --arg file "$snapshot_file" \
                    '.[] | select(.file == $file) | .description' "$metadata_file" 2>/dev/null)
            fi
            
            if [ -n "$description" ] && [ "$description" != "null" ]; then
                echo -e "  ${BLUE}├─${NC} ${snapshot_file%.*.*} (${size}) - ${description}"
            else
                echo -e "  ${BLUE}├─${NC} ${snapshot_file%.*.*} (${size})"
            fi
        done
        echo ""
    done
}

# Восстановить snapshot
restore_snapshot() {
    local snapshot_name="$1"
    
    if [ -z "$snapshot_name" ]; then
        echo -e "${RED}✗ Укажите имя snapshot${NC}"
        echo "Используйте: ./db-snapshot.sh list"
        exit 1
    fi
    
    check_docker
    check_mysql_container
    
    local snapshot_file=""
    
    # Если указано "latest" - взять последний для текущей ветки
    if [ "$snapshot_name" == "latest" ]; then
        local current_branch=$(get_current_branch)
        local normalized_branch=$(normalize_branch_name "$current_branch")
        snapshot_file=$(ls -t "${LOCAL_SNAPSHOT_DIR}/${normalized_branch}"_*.sql.gz 2>/dev/null | head -n 1)
        
        if [ -z "$snapshot_file" ]; then
            echo -e "${YELLOW}⚠️  Нет snapshots для ветки ${current_branch}${NC}"
            echo -e "Доступные snapshots:"
            list_snapshots
            exit 1
        fi
    else
        # Найти файл snapshot
        if [ -f "${LOCAL_SNAPSHOT_DIR}/${snapshot_name}.sql.gz" ]; then
            snapshot_file="${LOCAL_SNAPSHOT_DIR}/${snapshot_name}.sql.gz"
        elif [ -f "${LOCAL_SNAPSHOT_DIR}/${snapshot_name}" ]; then
            snapshot_file="${LOCAL_SNAPSHOT_DIR}/${snapshot_name}"
        else
            echo -e "${RED}✗ Snapshot не найден: ${snapshot_name}${NC}"
            echo -e "\nДоступные snapshots:"
            list_snapshots
            exit 1
        fi
    fi
    
    local snapshot_basename=$(basename "$snapshot_file" .sql.gz)
    
    echo -e "${BLUE}🔄 Восстановление snapshot...${NC}"
    echo -e "   Файл: ${GREEN}${snapshot_basename}${NC}"
    
    # Подтверждение
    echo -e "\n${YELLOW}⚠️  ВНИМАНИЕ: Текущая база данных будет ЗАМЕНЕНА!${NC}"
    read -p "Продолжить? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Отменено${NC}"
        exit 0
    fi
    
    # Создать backup текущей БД перед восстановлением
    echo -e "\n${CYAN}→ Создаю backup текущей БД на всякий случай...${NC}"
    create_snapshot "before-restore"
    
    # Восстановление
    echo -e "\n${CYAN}→ Восстанавливаю базу данных...${NC}"
    
    gunzip -c "$snapshot_file" | docker exec -i "${LOCAL_DB_CONTAINER}" \
        mysql \
        -u"${LOCAL_DB_USER}" \
        -p"${LOCAL_DB_PASS}" \
        "${LOCAL_DB_NAME}" \
        2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ База данных восстановлена${NC}"
        
        # Flush cache в WordPress (через WP-CLI если доступен)
        echo -e "\n${CYAN}→ Очистка кэша WordPress...${NC}"
        docker exec "${LOCAL_DB_CONTAINER}" \
            wp cache flush --path="${LOCAL_WP_PATH}" 2>/dev/null || true
        
        echo -e "${GREEN}✓ Готово!${NC}"
        return 0
    else
        echo -e "${RED}✗ Ошибка при восстановлении snapshot${NC}"
        return 1
    fi
}

# Очистить старые snapshots для ветки
cleanup_old_snapshots() {
    local branch="$1"
    local normalized_branch=$(normalize_branch_name "$branch")
    
    # Получить список snapshots для ветки
    local snapshots=($(ls -t "${LOCAL_SNAPSHOT_DIR}/${normalized_branch}"_*.sql.gz 2>/dev/null))
    local count=${#snapshots[@]}
    
    if [ $count -gt $SNAPSHOT_KEEP_COUNT ]; then
        echo -e "\n${CYAN}→ Очистка старых snapshots (оставляю последние ${SNAPSHOT_KEEP_COUNT})...${NC}"
        
        for ((i=$SNAPSHOT_KEEP_COUNT; i<$count; i++)); do
            local file_to_remove="${snapshots[$i]}"
            local filename=$(basename "$file_to_remove")
            echo -e "   ${YELLOW}Удаляю:${NC} $filename"
            rm -f "$file_to_remove"
        done
    fi
}

# Очистить все старые snapshots
cleanup_all_snapshots() {
    echo -e "${BLUE}🧹 Очистка старых snapshots...${NC}\n"
    
    if [ ! -d "${LOCAL_SNAPSHOT_DIR}" ]; then
        echo -e "${YELLOW}Директория snapshots не существует${NC}"
        return 0
    fi
    
    # Получить список всех веток
    local branches=($(ls "${LOCAL_SNAPSHOT_DIR}"/*.sql.gz 2>/dev/null | xargs -n 1 basename | cut -d'_' -f1 | sort -u))
    
    for branch in "${branches[@]}"; do
        echo -e "${CYAN}→ Очистка snapshots для ветки: ${branch}${NC}"
        cleanup_old_snapshots "$branch"
    done
    
    echo -e "\n${GREEN}✓ Очистка завершена${NC}"
}

# Автосохранение для текущей ветки (используется в Git hook)
auto_save_current() {
    local current_branch=$(get_current_branch)
    
    # Проверить, есть ли изменения в БД (можно пропустить если нет данных)
    check_docker || return 0
    check_mysql_container || return 0
    
    echo -e "${BLUE}💾 Автосохранение БД для ветки: ${GREEN}${current_branch}${NC}"
    create_snapshot "auto-save" > /dev/null 2>&1
}

# Автовосстановление для новой ветки (используется в Git hook)
auto_restore_for_branch() {
    local target_branch="$1"
    
    if [ -z "$target_branch" ]; then
        target_branch=$(get_current_branch)
    fi
    
    check_docker || return 0
    check_mysql_container || return 0
    
    local normalized_branch=$(normalize_branch_name "$target_branch")
    local latest_snapshot=$(ls -t "${LOCAL_SNAPSHOT_DIR}/${normalized_branch}"_*.sql.gz 2>/dev/null | head -n 1)
    
    if [ -n "$latest_snapshot" ]; then
        echo -e "${BLUE}🔄 Восстанавливаю БД для ветки: ${GREEN}${target_branch}${NC}"
        
        # Восстановление без подтверждения (для автоматизации)
        gunzip -c "$latest_snapshot" | docker exec -i "${LOCAL_DB_CONTAINER}" \
            mysql \
            -u"${LOCAL_DB_USER}" \
            -p"${LOCAL_DB_PASS}" \
            "${LOCAL_DB_NAME}" \
            2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ БД восстановлена из последнего snapshot${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Нет snapshot для ветки ${target_branch}${NC}"
        echo -e "   Опции:"
        echo -e "   1. Скопировать БД от main: ${CYAN}git checkout main && ./db-snapshot.sh create && git checkout ${target_branch} && ./db-snapshot.sh restore latest${NC}"
        echo -e "   2. Загрузить от PROD: ${CYAN}./db-sync.sh pull prod${NC}"
    fi
}

# ============================================
# MAIN
# ============================================

COMMAND="${1:-}"

case "$COMMAND" in
    create)
        create_snapshot "$2"
        ;;
    list)
        list_snapshots
        ;;
    restore)
        restore_snapshot "$2"
        ;;
    cleanup)
        cleanup_all_snapshots
        ;;
    auto-save)
        auto_save_current
        ;;
    auto-restore)
        auto_restore_for_branch "$2"
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
