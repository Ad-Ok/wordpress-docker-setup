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
PROD_WEBROOT="/home/your_user/your-domain.com"
PROD_BACKUP_DIR="/home/your_user/backups"
PROD_WP_PATH="/home/your_user/your-domain.com"

# База данных PROD
PROD_DB_NAME="your_db_name"
PROD_DB_USER="your_db_user"
PROD_DB_PASS="your_db_password"
PROD_DB_HOST="localhost"

# Git ветка для PROD
PROD_GIT_BRANCH="main"

# URL сайта PROD
PROD_SITE_URL="https://your-domain.com"

# ============================================
# DEV SERVER (dev.your-domain.com)
# ============================================
DEV_SSH_USER="your_ssh_user"
DEV_SSH_HOST="your_server_ip"
DEV_SSH_PORT="22"
DEV_WEBROOT="/home/your_user/dev.your-domain.com"
DEV_BACKUP_DIR="/home/your_user/backups-dev"
DEV_WP_PATH="/home/your_user/dev.your-domain.com"

# База данных DEV
DEV_DB_NAME="your_dev_db_name"
DEV_DB_USER="your_dev_db_user"
DEV_DB_PASS="your_dev_db_password"
DEV_DB_HOST="localhost"

# Git ветка для DEV
DEV_GIT_BRANCH="dev"

# URL сайта DEV
DEV_SITE_URL="https://dev.your-domain.com"

# ============================================
# ЛОКАЛЬНЫЕ ПУТИ
# ============================================
LOCAL_PROJECT_ROOT="/path/to/your/project/www"
LOCAL_THEME_PATH="${LOCAL_PROJECT_ROOT}/wordpress/wp-content/themes/your-theme"
LOCAL_BACKUP_DIR="${LOCAL_PROJECT_ROOT}/../backups"

# ============================================
# УВЕДОМЛЕНИЯ
# ============================================
# Telegram
TELEGRAM_BOT_TOKEN="your_bot_token_here"
TELEGRAM_CHAT_ID="your_chat_id_here"
TELEGRAM_ENABLED="false"  # true/false

# Email
EMAIL_TO="admin@your-domain.com"
EMAIL_FROM="deploy@your-domain.com"
EMAIL_ENABLED="false"  # true/false

# Slack (опционально)
SLACK_WEBHOOK_URL=""
SLACK_ENABLED="false"

# ============================================
# НАСТРОЙКИ БЭКАПОВ
# ============================================
# Сколько бэкапов хранить
BACKUP_KEEP_COUNT="10"

# Создавать бэкап перед каждым деплоем
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
# Режим обслуживания (maintenance mode)
MAINTENANCE_MODE_ENABLED="true"

# Запускать миграции автоматически
AUTO_RUN_MIGRATIONS="true"

# Очищать кеш после деплоя
AUTO_CLEAR_CACHE="true"

# Требовать подтверждение перед PROD деплоем
REQUIRE_CONFIRMATION="true"

# Режим dry-run по умолчанию (для тестирования)
DRY_RUN="false"

# ============================================
# ПУТИ КЭШИРОВАНИЯ WP SUPER CACHE
# ============================================
PROD_WP_SUPER_CACHE_PATH="/home/your_user/your-domain.com/wp-content/plugins/wp-super-cache/"
DEV_WP_SUPER_CACHE_PATH="/home/your_user/dev.your-domain.com/wp-content/plugins/wp-super-cache/"
LOCAL_WP_SUPER_CACHE_PATH="/var/www/html/wp-content/plugins/wp-super-cache/"
