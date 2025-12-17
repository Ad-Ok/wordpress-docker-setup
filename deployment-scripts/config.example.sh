#!/bin/bash
# 🔐 Конфигурация деплоя для your-domain.com
# Скопируйте этот файл в config.sh и заполните своими данными
# ВАЖНО: config.sh добавлен в .gitignore - не коммитьте его!

# ============================================
# PROD SERVER (your-domain.com)
# ============================================
PROD_SSH_USER="your_ssh_user"
PROD_SSH_HOST="your_server_ip"
PROD_SSH_PORT="22"
PROD_WEBROOT="/home/your_user/domains/your-domain.com/public_html"
PROD_BACKUP_DIR="/home/your_user/backups"
PROD_WP_PATH="/home/your_user/domains/your-domain.com/public_html"

# База данных PROD
PROD_DB_NAME="your_db_name"
PROD_DB_USER="your_db_user"
PROD_DB_PASS="your_db_password"
PROD_DB_HOST="localhost"

# Git ветка для PROD
PROD_GIT_BRANCH="main"

# URL сайта PROD
PROD_SITE_URL="https://your-domain.com"

# WP-CLI на PROD
PROD_WP_CLI="/home/your_user/bin/wp"

# ============================================
# DEV SERVER (dev.your-domain.com)
# ============================================
DEV_SSH_USER="your_ssh_user"
DEV_SSH_HOST="your_server_ip"
DEV_SSH_PORT="22"
DEV_WEBROOT="/home/your_user/domains/dev.your-domain.com/public_html"
DEV_BACKUP_DIR="/home/your_user/backups-dev"
DEV_WP_PATH="/home/your_user/domains/dev.your-domain.com/public_html"

# База данных DEV
DEV_DB_NAME="your_dev_db_name"
DEV_DB_USER="your_dev_db_user"
DEV_DB_PASS="your_dev_db_password"
DEV_DB_HOST="localhost"

# Git ветка для DEV
DEV_GIT_BRANCH="dev"

# URL сайта DEV
DEV_SITE_URL="https://dev.your-domain.com"

# WP-CLI на DEV
DEV_WP_CLI="/home/your_user/bin/wp"

# ============================================
# ЛОКАЛЬНЫЕ ПУТИ
# ============================================
LOCAL_PROJECT_ROOT="/path/to/your/project/www"
LOCAL_THEME_PATH="${LOCAL_PROJECT_ROOT}/wordpress/wp-content/themes/your-theme"
LOCAL_BACKUP_DIR="${LOCAL_PROJECT_ROOT}/backups"

# ============================================
# ЛОКАЛЬНАЯ БАЗА ДАННЫХ (Docker)
# ============================================
LOCAL_DB_NAME="wordpress_db"
LOCAL_DB_USER="wordpress_user"
LOCAL_DB_PASS="wordpress_password"
LOCAL_DB_HOST="localhost"
LOCAL_DB_PORT="3306"
LOCAL_DB_CONTAINER="wordpress_mysql"

# URL локального сайта
LOCAL_SITE_URL="https://localhost"

# Путь к WordPress внутри Docker контейнера
LOCAL_WP_PATH="/var/www/html"

# ============================================
# НАСТРОЙКИ SNAPSHOTS
# ============================================
LOCAL_SNAPSHOT_DIR="${LOCAL_BACKUP_DIR}/snapshots"
SNAPSHOT_KEEP_COUNT="3"  # Сколько snapshots хранить для каждой ветки
SNAPSHOT_AUTO_SWITCH="true"  # Автопереключение БД при git checkout

# ============================================
# НАСТРОЙКИ МИГРАЦИЙ
# ============================================
# Путь к директории с SQL миграциями (в сабмодуле wordpress)
LOCAL_MIGRATIONS_DIR="${LOCAL_PROJECT_ROOT}/wordpress/database/migrations"
PROD_MIGRATIONS_DIR="${PROD_WP_PATH}/database/migrations"
DEV_MIGRATIONS_DIR="${DEV_WP_PATH}/database/migrations"

# Автоматический запуск миграций при деплое
AUTO_RUN_MIGRATIONS="true"

# ============================================
# НАСТРОЙКИ БЭКАПОВ
# ============================================
BACKUP_KEEP_COUNT="10"
BACKUP_BEFORE_DEPLOY="true"

# ============================================
# SMOKE TESTS
# ============================================
# URL для проверки после деплоя
SMOKE_TEST_URLS=(
    "/"
    "/wp-json/"
    "/wp-admin/admin-ajax.php"
)

# Ожидаемый HTTP код
SMOKE_TEST_EXPECTED_CODE="200"

# Таймаут для curl (секунды)
SMOKE_TEST_TIMEOUT="10"

# ============================================
# ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ
# ============================================
# Требовать подтверждение перед PROD деплоем
REQUIRE_CONFIRMATION="true"

# Автоматическая очистка кеша после деплоя
AUTO_CLEAR_CACHE="true"

# Включить режим обслуживания при деплое на PROD
MAINTENANCE_MODE_ENABLED="false"

# Режим отладки
DEBUG_MODE="false"

# ============================================
# НАСТРОЙКИ ОТЛАДКИ WORDPRESS
# ============================================
PROD_WP_DEBUG="false"
PROD_WP_DEBUG_LOG="false"
PROD_WP_DEBUG_DISPLAY="false"

DEV_WP_DEBUG="true"
DEV_WP_DEBUG_LOG="true"
DEV_WP_DEBUG_DISPLAY="true"

LOCAL_WP_DEBUG="true"
LOCAL_WP_DEBUG_LOG="true"
LOCAL_WP_DEBUG_DISPLAY="false"

# ============================================
# ПУТИ КЭШИРОВАНИЯ WP SUPER CACHE
# ============================================
PROD_WP_SUPER_CACHE_PATH="/home/your_user/domains/your-domain.com/public_html/wp-content/plugins/wp-super-cache/"
DEV_WP_SUPER_CACHE_PATH="/home/your_user/domains/dev.your-domain.com/public_html/wp-content/plugins/wp-super-cache/"
LOCAL_WP_SUPER_CACHE_PATH="/var/www/html/wp-content/plugins/wp-super-cache/"
