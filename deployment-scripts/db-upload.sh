#!/bin/bash
# 🚀 Database Upload Script
# Загружает локальную базу данных на сервер и выполняет search-replace URL
#
# Использование:
#   ./db-upload.sh [prod|dev]
#
# Что делает:
# 1. Проверяет локальное окружение (Docker MySQL)
# 2. Проверяет SSH соединение
# 3. Экспортирует локальную базу данных
# 4. Загружает на сервер
# 5. Импортирует и выполняет search-replace URL

set -e

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils/notifications.sh"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Определяем среду (prod или dev)
ENVIRONMENT="${1:-prod}"

if [ "$ENVIRONMENT" == "prod" ]; then
    SSH_USER="$PROD_SSH_USER"
    SSH_HOST="$PROD_SSH_HOST"
    WEBROOT="$PROD_WEBROOT"
    BACKUP_DIR="$PROD_BACKUP_DIR"
    SITE_URL="$PROD_SITE_URL"
    DB_NAME="$PROD_DB_NAME"
    DB_USER="$PROD_DB_USER"
    DB_PASSWORD="$PROD_DB_PASS"
    DB_HOST="$PROD_DB_HOST"
elif [ "$ENVIRONMENT" == "dev" ]; then
    SSH_USER="$DEV_SSH_USER"
    SSH_HOST="$DEV_SSH_HOST"
    WEBROOT="$DEV_WEBROOT"
    BACKUP_DIR="$DEV_BACKUP_DIR"
    SITE_URL="$DEV_SITE_URL"
    DB_NAME="$DEV_DB_NAME"
    DB_USER="$DEV_DB_USER"
    DB_PASSWORD="$DEV_DB_PASS"
    DB_HOST="$DEV_DB_HOST"
else
    echo -e "${RED}Invalid environment: $ENVIRONMENT${NC}"
    echo "Usage: $0 [prod|dev]"
    exit 1
fi

# Uppercase для вывода
ENV_UPPER=$(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')

echo -e "${BLUE}═══ Database Upload to ${ENV_UPPER} ═══${NC}"
echo ""

# ============================================
# Проверка локального окружения
# ============================================
echo "→ Checking local Docker MySQL container..."
if ! docker ps | grep -q "${LOCAL_DB_CONTAINER}"; then
    echo -e "${RED}✗ Docker MySQL container '${LOCAL_DB_CONTAINER}' is not running${NC}"
    echo ""
    echo "Please start Docker containers:"
    echo "  cd ${LOCAL_PROJECT_ROOT} && docker compose up -d"
    exit 1
fi

if ! docker exec "${LOCAL_DB_CONTAINER}" mysql -u"${LOCAL_DB_USER}" -p"${LOCAL_DB_PASS}" -e "SELECT 1" &>/dev/null; then
    echo -e "${RED}✗ Cannot connect to local database${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Local database connection OK"
echo ""

# ============================================
# Проверка SSH соединения
# ============================================
echo "→ Testing SSH connection..."
if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "${SSH_USER}@${SSH_HOST}" exit; then
    echo -e "${RED}✗ Cannot connect to server${NC}"
    send_notification "❌ Database upload failed: SSH connection error"
    exit 1
fi

echo -e "${GREEN}✓${NC} SSH connection successful"
echo ""

# ============================================
# Проверка WP-CLI на сервере
# ============================================
echo "→ Checking WP-CLI on server..."
WP_CLI_CHECK=$(ssh "${SSH_USER}@${SSH_HOST}" "if [ -f ~/wp-cli.phar ] && /usr/local/bin/php ~/wp-cli.phar --version &>/dev/null; then echo 'OK'; else echo 'MISSING'; fi")

if [ "$WP_CLI_CHECK" != "OK" ]; then
    echo -e "${RED}✗ WP-CLI is not installed or not working on server${NC}"
    echo ""
    echo "Please install WP-CLI on the server:"
    echo "  ssh ${SSH_USER}@${SSH_HOST}"
    echo "  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
    echo "  chmod +x wp-cli.phar"
    echo "  mv wp-cli.phar ~/wp-cli.phar"
    echo "  echo 'alias wp=\"/usr/local/bin/php ~/wp-cli.phar\"' >> ~/.bash_profile"
    echo ""
    echo "Or see: www/docs/WP-CLI_INSTALL_ON_SPRINTHOST.md"
    exit 1
fi

echo -e "${GREEN}✓${NC} WP-CLI is installed on server"
echo ""

# ============================================
# Создание бэкапа удаленной БД
# ============================================
echo "→ Creating remote database backup..."
ssh "${SSH_USER}@${SSH_HOST}" bash -c "\
  WP='/usr/local/bin/php ~/wp-cli.phar'; \
  if [ -f ~/wp-cli.phar ]; then \
    cd '${WEBROOT}' 2>/dev/null || cd /; \
    if \$WP db check 2>/dev/null; then \
      mkdir -p '${BACKUP_DIR}'; \
      echo 'Creating backup...'; \
      \$WP db export '${BACKUP_DIR}/backup-db-upload-\$(date +%Y%m%d_%H%M%S).sql.gz' 2>/dev/null || true; \
      echo '✓ Backup created'; \
    else \
      echo 'ℹ️  No existing database to backup'; \
    fi; \
  else \
    echo 'ℹ️  WP-CLI not available, skipping backup'; \
  fi; \
" 2>&1 | grep -v "^BASH" | grep -v "^DIRSTACK" | grep -v "^GROUPS" | grep -v "=" || true

echo ""

# ============================================
# Экспорт локальной БД
# ============================================
echo "→ Exporting local database..."
LOCAL_DB_DUMP="/tmp/db_upload_$(date +%Y%m%d_%H%M%S)_$$.sql.gz"

docker exec "${LOCAL_DB_CONTAINER}" \
    mysqldump \
    -u"${LOCAL_DB_USER}" \
    -p"${LOCAL_DB_PASS}" \
    "${LOCAL_DB_NAME}" \
    2>/dev/null | gzip > "${LOCAL_DB_DUMP}"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to export local database${NC}"
    rm -f "${LOCAL_DB_DUMP}"
    send_notification "❌ Database upload failed: Export error"
    exit 1
fi

DB_SIZE=$(du -h "${LOCAL_DB_DUMP}" | cut -f1)
echo -e "${GREEN}✓${NC} Database exported (${DB_SIZE})"
echo ""

# ============================================
# Загрузка БД на сервер
# ============================================
echo "→ Uploading database to server..."
DB_DUMP_BASENAME=$(basename "${LOCAL_DB_DUMP}")
scp -q "${LOCAL_DB_DUMP}" "${SSH_USER}@${SSH_HOST}:/tmp/" || {
    echo -e "${RED}✗ Database upload failed${NC}"
    rm -f "${LOCAL_DB_DUMP}"
    send_notification "❌ Database upload failed: Upload error"
    exit 1
}

echo -e "${GREEN}✓${NC} Database uploaded"
echo ""

# ============================================
# Импорт БД и замена URL
# ============================================
echo "→ Importing database and replacing URLs..."

# Определяем URL для замены
SOURCE_URL="${LOCAL_SITE_URL}"
TARGET_URL="${SITE_URL}"

# Импорт базы данных
echo "Importing database..."
SSH_RESULT=$(ssh "${SSH_USER}@${SSH_HOST}" "gunzip -c /tmp/${DB_DUMP_BASENAME} | mysql -u '${DB_USER}' -p'${DB_PASSWORD}' '${DB_NAME}' 2>&1 && echo 'SUCCESS' || echo 'FAILED'")

if echo "$SSH_RESULT" | grep -q "SUCCESS"; then
    echo -e "${GREEN}✓${NC} Database imported"
else
    echo -e "${RED}✗ Database import failed${NC}"
    echo "$SSH_RESULT" | grep -v "Using a password"
    rm -f "${LOCAL_DB_DUMP}"
    send_notification "❌ Database upload failed: Import error"
    exit 1
fi

# Замена URL через SQL
echo "Replacing URLs: ${SOURCE_URL} → ${TARGET_URL}"
ssh "${SSH_USER}@${SSH_HOST}" "mysql -u '${DB_USER}' -p'${DB_PASSWORD}' '${DB_NAME}' -e \"
UPDATE wp_options SET option_value = REPLACE(option_value, '${SOURCE_URL}', '${TARGET_URL}');
UPDATE wp_posts SET post_content = REPLACE(post_content, '${SOURCE_URL}', '${TARGET_URL}');
UPDATE wp_posts SET post_excerpt = REPLACE(post_excerpt, '${SOURCE_URL}', '${TARGET_URL}');
UPDATE wp_posts SET guid = REPLACE(guid, '${SOURCE_URL}', '${TARGET_URL}');
UPDATE wp_postmeta SET meta_value = REPLACE(meta_value, '${SOURCE_URL}', '${TARGET_URL}');
UPDATE wp_comments SET comment_content = REPLACE(comment_content, '${SOURCE_URL}', '${TARGET_URL}');
UPDATE wp_options SET option_value = '${TARGET_URL}' WHERE option_name IN ('siteurl', 'home');
\"" 2>&1 | grep -v "Using a password"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} URLs replaced"
else
    echo -e "${YELLOW}⚠${NC} URL replacement completed with warnings"
fi

# Удаление временных файлов
ssh "${SSH_USER}@${SSH_HOST}" "rm -f /tmp/${DB_DUMP_BASENAME}"
rm -f "${LOCAL_DB_DUMP}"

echo ""
echo -e "${GREEN}✓${NC} Database upload completed successfully!"
echo ""
echo "Database uploaded to ${ENV_UPPER}:"
echo "  Database: ${DB_NAME}"
echo "  Site URL: ${SITE_URL}"
echo ""

send_notification "✅ Database uploaded to ${ENV_UPPER} successfully!"

exit 0