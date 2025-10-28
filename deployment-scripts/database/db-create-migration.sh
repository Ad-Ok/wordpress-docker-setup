#!/bin/bash
# ✨ Migration Generator
# Создание новых SQL-миграций

set -e

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Директория миграций
MIGRATIONS_DIR="${SCRIPT_DIR}/database/migrations"

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
${BLUE}✨ Migration Generator${NC}

${YELLOW}Использование:${NC}
  ./db-create-migration.sh "<описание>"

${YELLOW}Примеры:${NC}
  # Создать миграцию для добавления таблицы
  ./db-create-migration.sh "add products table"

  # Создать миграцию для изменения колонок
  ./db-create-migration.sh "add category column to posts"

  # Создать миграцию для добавления индексов
  ./db-create-migration.sh "add indexes for performance"

${YELLOW}Что делает:${NC}
  - Создает файл с автоинкрементом номера
  - Добавляет шаблон с проверками EXISTS
  - Готов для редактирования SQL

${YELLOW}Формат файла:${NC}
  001_add_products_table.sql
  002_add_category_column_to_posts.sql
  003_add_indexes_for_performance.sql

EOF
}

# Нормализовать описание для имени файла
normalize_description() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//'
}

# Получить следующий номер миграции
get_next_migration_number() {
    local last_number=0
    
    if [ -d "$MIGRATIONS_DIR" ]; then
        local last_migration=$(ls "${MIGRATIONS_DIR}"/[0-9][0-9][0-9]_*.sql 2>/dev/null | sort | tail -n 1)
        
        if [ -n "$last_migration" ]; then
            last_number=$(basename "$last_migration" | cut -d'_' -f1 | sed 's/^0*//')
            if [ -z "$last_number" ]; then
                last_number=0
            fi
        fi
    fi
    
    printf "%03d" $((last_number + 1))
}

# Создать шаблон миграции
create_migration_template() {
    local description="$1"
    
    cat << 'EOF'
-- ============================================
-- Migration: ${DESCRIPTION}
-- Created: ${DATE}
-- ============================================

-- ВАЖНО: Используйте IF NOT EXISTS для идемпотентности
-- Миграция должна безопасно выполняться несколько раз

-- Пример: Создание таблицы
-- CREATE TABLE IF NOT EXISTS wp_custom_table (
--     id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
--     name varchar(255) NOT NULL,
--     created_at datetime DEFAULT CURRENT_TIMESTAMP,
--     PRIMARY KEY (id)
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Пример: Добавление колонки
-- SET @col_exists = (
--     SELECT COUNT(*)
--     FROM INFORMATION_SCHEMA.COLUMNS
--     WHERE TABLE_SCHEMA = DATABASE()
--     AND TABLE_NAME = 'wp_posts'
--     AND COLUMN_NAME = 'custom_field'
-- );
-- 
-- SET @query = IF(@col_exists = 0,
--     'ALTER TABLE wp_posts ADD COLUMN custom_field VARCHAR(255) NULL',
--     'SELECT "Column already exists" AS message'
-- );
-- 
-- PREPARE stmt FROM @query;
-- EXECUTE stmt;
-- DEALLOCATE PREPARE stmt;

-- Пример: Добавление индекса
-- SET @index_exists = (
--     SELECT COUNT(*)
--     FROM INFORMATION_SCHEMA.STATISTICS
--     WHERE TABLE_SCHEMA = DATABASE()
--     AND TABLE_NAME = 'wp_posts'
--     AND INDEX_NAME = 'idx_custom'
-- );
-- 
-- SET @query = IF(@index_exists = 0,
--     'ALTER TABLE wp_posts ADD INDEX idx_custom (custom_field)',
--     'SELECT "Index already exists" AS message'
-- );
-- 
-- PREPARE stmt FROM @query;
-- EXECUTE stmt;
-- DEALLOCATE PREPARE stmt;

-- ============================================
-- ВАША МИГРАЦИЯ ЗДЕСЬ:
-- ============================================



-- ============================================
-- NOTES:
-- - Всегда проверяйте существование перед созданием
-- - Используйте транзакции если возможно
-- - Добавляйте комментарии для сложной логики
-- - Тестируйте на локальной БД перед деплоем
-- ============================================
EOF
}

# Создать миграцию
create_migration() {
    local description="$1"
    
    if [ -z "$description" ]; then
        echo -e "${RED}✗ Укажите описание миграции${NC}"
        show_usage
        exit 1
    fi
    
    # Создать директорию для миграций
    mkdir -p "${MIGRATIONS_DIR}"
    
    # Получить номер и нормализованное описание
    local number=$(get_next_migration_number)
    local normalized_desc=$(normalize_description "$description")
    local migration_file="${number}_${normalized_desc}.sql"
    local migration_path="${MIGRATIONS_DIR}/${migration_file}"
    
    echo -e "${BLUE}✨ Создание новой миграции...${NC}\n"
    echo -e "   Номер: ${CYAN}${number}${NC}"
    echo -e "   Описание: ${description}"
    echo -e "   Файл: ${GREEN}${migration_file}${NC}"
    echo ""
    
    # Создать файл из шаблона
    local date_now=$(date "+%Y-%m-%d %H:%M:%S")
    create_migration_template "$description" | \
        sed "s/\${DESCRIPTION}/${description}/g" | \
        sed "s/\${DATE}/${date_now}/g" \
        > "${migration_path}"
    
    echo -e "${GREEN}✓ Миграция создана!${NC}"
    echo ""
    echo -e "${CYAN}Что дальше:${NC}"
    echo -e "   1. Откройте файл: ${YELLOW}${migration_path}${NC}"
    echo -e "   2. Добавьте ваш SQL код"
    echo -e "   3. Примените миграцию:"
    echo -e "      ${YELLOW}./db-migrate.sh apply local${NC}   # На локальной БД"
    echo -e "      ${YELLOW}./db-migrate.sh apply dev${NC}     # На DEV"
    echo -e "      ${YELLOW}./db-migrate.sh apply prod${NC}    # На PROD"
    echo ""
    echo -e "${YELLOW}Примеры SQL:${NC}"
    echo -e "   • Создание таблицы"
    echo -e "   • Добавление колонки"
    echo -e "   • Добавление индекса"
    echo -e "   • Изменение типа данных"
    echo ""
    echo -e "Все примеры есть в созданном файле!"
}

# ============================================
# MAIN
# ============================================

DESCRIPTION="$1"

if [ -z "$DESCRIPTION" ] || [ "$DESCRIPTION" == "help" ] || [ "$DESCRIPTION" == "--help" ] || [ "$DESCRIPTION" == "-h" ]; then
    show_usage
    exit 0
fi

create_migration "$DESCRIPTION"
