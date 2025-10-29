#!/bin/bash
# 🚀 Initial Deployment Script
# Первый деплой: загружает полную инфраструктуру WordPress на сервер
# Использовать только для первоначального развёртывания!
#
# Что делает:
# 1. Проверяет локальное окружение
# 2. Проверяет SSH соединение
# 3. Проверяет состояние сервера
# 4. Подготавливает директории на сервере
# 5. Клонирует Git репозиторий на сервере
# 5.5. Загружает базу данных с локального Docker
#      - Экспортирует локальную БД из MySQL контейнера
#      - Загружает на сервер
#      - Импортирует и выполняет search-replace URL
# 6. Загружает WordPress core файлы
# 6.5. Загружает wp-content/uploads
# 7. Устанавливает права доступа
# 8. Создает deployment marker
# 9. Настраивает HTTP аутентификацию (для DEV)
# 10. Проверяет установку
# 11. Проверяет подключение к базе данных

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
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Определяем среду (prod или dev)
ENVIRONMENT="${1:-prod}"

if [ "$ENVIRONMENT" == "prod" ]; then
    SSH_USER="$PROD_SSH_USER"
    SSH_HOST="$PROD_SSH_HOST"
    WEBROOT="$PROD_WEBROOT"
    BACKUP_DIR="$PROD_BACKUP_DIR"
    GIT_BRANCH="$PROD_GIT_BRANCH"
    SITE_URL="$PROD_SITE_URL"
elif [ "$ENVIRONMENT" == "dev" ]; then
    SSH_USER="$DEV_SSH_USER"
    SSH_HOST="$DEV_SSH_HOST"
    WEBROOT="$DEV_WEBROOT"
    BACKUP_DIR="$DEV_BACKUP_DIR"
    GIT_BRANCH="$DEV_GIT_BRANCH"
    SITE_URL="$DEV_SITE_URL"
else
    echo -e "${RED}Invalid environment: $ENVIRONMENT${NC}"
    echo "Usage: $0 [prod|dev]"
    exit 1
fi

# Uppercase для вывода (совместимость с bash 3)
ENV_UPPER=$(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')

echo -e "${MAGENTA}╔════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║         INITIAL DEPLOYMENT - ${ENV_UPPER}                 ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# ПРЕДУПРЕЖДЕНИЕ
# ============================================
echo -e "${YELLOW}⚠️  WARNING: Initial Deployment${NC}"
echo ""
echo "This script will:"
echo "  • Clone Git repository on server"
echo "  • Upload and import local database (with URL replacement)"
echo "  • Upload WordPress core files (excluding wp-content)"
echo "  • Upload wp-content/uploads separately"
echo "  • Setup proper permissions"
echo ""
echo -e "${RED}This should only be used for FIRST deployment!${NC}"
echo ""

if [ -t 0 ]; then
    read -p "Continue with initial deployment? (yes/no): " -r CONFIRM
else
    read -r CONFIRM < /dev/tty
    echo "Continue? (yes/no): $CONFIRM"
fi

if [[ ! $CONFIRM =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${RED}Initial deployment cancelled${NC}"
    exit 0
fi

echo ""

# ============================================
# STEP 1: Проверка локального окружения
# ============================================
echo -e "${BLUE}═══ STEP 1/8: Checking Local Environment ═══${NC}"
echo ""

# 1.1 Проверка Docker контейнера с базой данных
echo "→ Checking Docker MySQL container..."
if ! docker ps | grep -q "${LOCAL_DB_CONTAINER}"; then
    echo -e "${RED}✗ Docker MySQL container '${LOCAL_DB_CONTAINER}' is not running${NC}"
    echo ""
    echo "Please start Docker containers:"
    echo "  cd ${LOCAL_PROJECT_ROOT} && docker compose up -d"
    exit 1
fi
echo -e "${GREEN}✓${NC} Docker MySQL container is running"

# 1.2 Проверка подключения к локальной базе данных
echo "→ Checking local database connection..."
if ! docker exec "${LOCAL_DB_CONTAINER}" mysql -u"${LOCAL_DB_USER}" -p"${LOCAL_DB_PASS}" -e "SELECT 1" &>/dev/null; then
    echo -e "${RED}✗ Cannot connect to local database${NC}"
    echo ""
    echo "Database credentials in config.sh:"
    echo "  User: ${LOCAL_DB_USER}"
    echo "  Database: ${LOCAL_DB_NAME}"
    echo "  Container: ${LOCAL_DB_CONTAINER}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Local database connection OK"

# 1.3 Проверяем, что wordpress директория существует
echo "→ Checking WordPress directory..."
if [ ! -d "${LOCAL_PROJECT_ROOT}/wordpress" ]; then
    echo -e "${RED}✗ WordPress directory not found: ${LOCAL_PROJECT_ROOT}/wordpress${NC}"
    exit 1
fi

# Проверяем основные файлы WordPress
REQUIRED_FILES=(
    "wordpress/wp-config.php"
    "wordpress/index.php"
    "wordpress/wp-load.php"
    "wordpress/wp-settings.php"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "${LOCAL_PROJECT_ROOT}/${file}" ]; then
        echo -e "${RED}✗ Required file not found: ${file}${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✓${NC} Local environment check passed"
echo ""

# ============================================
# STEP 2: SSH Connection Test
# ============================================
echo -e "${BLUE}═══ STEP 2/8: Testing SSH Connection ═══${NC}"
echo ""

if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "${SSH_USER}@${SSH_HOST}" exit; then
    echo -e "${RED}✗ Cannot connect to server${NC}"
    send_notification "❌ Initial deployment failed: SSH connection error"
    exit 1
fi

echo -e "${GREEN}✓${NC} SSH connection successful"
echo ""

# 2.1 Проверка WP-CLI на сервере
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
# STEP 3: Проверка сервера
# ============================================
echo -e "${BLUE}═══ STEP 3/8: Checking Server State ═══${NC}"
echo ""

SERVER_CHECK=$(ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
# Проверяем, существует ли директория
if [ -d "${WEBROOT}" ]; then
    # Проверяем, есть ли там уже WordPress
    if [ -f "${WEBROOT}/wp-config.php" ] || [ -d "${WEBROOT}/.git" ]; then
        echo "EXISTING_INSTALLATION"
    else
        echo "EMPTY_DIRECTORY"
    fi
else
    echo "NO_DIRECTORY"
fi
ENDSSH
)

if [ "$SERVER_CHECK" == "EXISTING_INSTALLATION" ]; then
    echo -e "${YELLOW}⚠️  WARNING: Existing WordPress installation detected!${NC}"
    echo ""
    echo "The target directory already contains WordPress."
    echo "This may be a mistake. Initial deployment should only be"
    echo "used on fresh servers."
    echo ""
    
    if [ -t 0 ]; then
        read -p "Are you SURE you want to overwrite? (yes/no): " -r OVERWRITE_CONFIRM
    else
        read -r OVERWRITE_CONFIRM < /dev/tty
        echo "Overwrite? (yes/no): $OVERWRITE_CONFIRM"
    fi
    
    if [[ ! $OVERWRITE_CONFIRM =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${RED}Initial deployment cancelled${NC}"
        exit 0
    fi
    
    # Создаём бэкап существующей установки
    echo ""
    echo "Creating backup of existing installation..."
    ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
mkdir -p ${BACKUP_DIR}
BACKUP_NAME="pre-initial-deploy-\$(date +%Y%m%d-%H%M%S)"
tar -czf "${BACKUP_DIR}/\${BACKUP_NAME}.tar.gz" -C "${WEBROOT}" .
echo "Backup saved: ${BACKUP_DIR}/\${BACKUP_NAME}.tar.gz"
ENDSSH
fi

echo -e "${GREEN}✓${NC} Server check completed"
echo ""

# ============================================
# STEP 4: Создание директорий на сервере
# ============================================
echo -e "${BLUE}═══ STEP 4/8: Preparing Server Directories ═══${NC}"
echo ""

ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
# Создаём директории если их нет
mkdir -p ${WEBROOT}
mkdir -p ${BACKUP_DIR}

# Очищаем webroot если там были дефолтные файлы хостинга
if [ -f "${WEBROOT}/index.php" ] && [ ! -f "${WEBROOT}/wp-config.php" ]; then
    echo "Cleaning default hosting files..."
    rm -f ${WEBROOT}/index.php
    rm -f ${WEBROOT}/index.html
fi

echo "✓ Directories prepared"
ENDSSH

echo -e "${GREEN}✓${NC} Server directories ready"
echo ""

# ============================================
# STEP 5: Clone Git Repository on Server
# ============================================
echo -e "${BLUE}═══ STEP 5/8: Cloning Git Repository on Server ═══${NC}"
echo ""

# Получаем URL репозитория из локального .git
cd "${LOCAL_PROJECT_ROOT}/wordpress"
GIT_REMOTE_URL=$(git config --get remote.origin.url || echo "")

if [ -z "$GIT_REMOTE_URL" ]; then
    echo -e "${RED}✗ ERROR: Could not determine Git remote URL${NC}"
    echo "Please ensure remote.origin.url is set in ${LOCAL_PROJECT_ROOT}/wordpress/.git/config"
    send_notification "❌ Initial deployment failed: Git remote URL not found"
    exit 1
fi

echo "Git remote URL: $GIT_REMOTE_URL"
echo "Branch: $GIT_BRANCH"
echo ""

# Клонируем репозиторий на сервере
ssh "${SSH_USER}@${SSH_HOST}" bash -lc "\
  set -e; \
  if [ -d '${WEBROOT}/.git' ]; then \
    echo '⚠️  Repository already exists on server at ${WEBROOT}'; \
    echo 'Using existing repository...'; \
  else \
    echo 'Cloning repository...'; \
    rm -rf ${WEBROOT}/* ${WEBROOT}/.* 2>/dev/null || true; \
    git clone --branch ${GIT_BRANCH} --single-branch '${GIT_REMOTE_URL}' '${WEBROOT}' || exit 1; \
    echo '✓ Repository cloned successfully'; \
  fi"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Git clone failed${NC}"
    send_notification "❌ Initial deployment failed: Git clone error"
    exit 1
fi

echo -e "${GREEN}✓${NC} Git repository cloned successfully"
echo ""

# ============================================
# STEP 5.5: Database Upload from Local
# ============================================
echo -e "${BLUE}═══ STEP 5.5/10: Uploading Database from Local ═══${NC}"
echo ""

echo "This will upload your local database to the server."
echo "Assumption: Local database is up-to-date and matches the current Git branch."
echo ""

# Проверяем Docker
if ! docker ps &> /dev/null; then
    echo -e "${RED}✗ Docker is not running${NC}"
    echo "Please start Docker and ensure MySQL container is running."
    exit 1
fi

if ! docker ps | grep -q "${LOCAL_DB_CONTAINER}"; then
    echo -e "${YELLOW}⚠️  MySQL container is not running. Starting...${NC}"
    docker start "${LOCAL_DB_CONTAINER}" || {
        echo -e "${RED}✗ Failed to start MySQL container${NC}"
        exit 1
    }
    sleep 3
fi

echo "Checking local database connection..."
if ! docker exec "${LOCAL_DB_CONTAINER}" mysql -u"${LOCAL_DB_USER}" -p"${LOCAL_DB_PASS}" -e "SELECT 1" &> /dev/null; then
    echo -e "${RED}✗ Cannot connect to local database${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Local database connection OK"
echo ""

# Создаём backup на удаленном сервере (если БД уже существует)
echo "[1/4] Creating remote database backup (if exists)..."
ssh "${SSH_USER}@${SSH_HOST}" bash -lc "\
  set -e; \
  WP='/usr/local/bin/php ~/wp-cli.phar'; \
  if [ -f ~/wp-cli.phar ]; then \
    cd '${WEBROOT}' 2>/dev/null || cd /; \
    if \$WP db check 2>/dev/null; then \
      mkdir -p '${BACKUP_DIR}'; \
      echo '→ Creating backup...'; \
      \$WP db export '${BACKUP_DIR}/backup-before-initial-deploy-\$(date +%Y%m%d_%H%M%S).sql.gz' 2>/dev/null || true; \
      echo '✓ Backup created'; \
    else \
      echo 'ℹ️  No existing database to backup'; \
    fi; \
  else \
    echo 'ℹ️  WP-CLI not available, skipping backup'; \
  fi; \
"

echo ""

# Экспортируем локальную БД
echo "[2/4] Exporting local database..."
LOCAL_DB_DUMP=$(mktemp /tmp/db_initial_deploy_XXXXXX.sql.gz)

docker exec "${LOCAL_DB_CONTAINER}" \
    mysqldump \
    -u"${LOCAL_DB_USER}" \
    -p"${LOCAL_DB_PASS}" \
    "${LOCAL_DB_NAME}" \
    2>/dev/null | gzip > "${LOCAL_DB_DUMP}"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to export local database${NC}"
    rm -f "${LOCAL_DB_DUMP}"
    send_notification "❌ Initial deployment failed: Database export error"
    exit 1
fi

DB_SIZE=$(du -h "${LOCAL_DB_DUMP}" | cut -f1)
echo -e "${GREEN}✓${NC} Database exported (${DB_SIZE})"
echo ""

# Загружаем БД на сервер
echo "[3/4] Uploading database to server..."
DB_DUMP_BASENAME=$(basename "${LOCAL_DB_DUMP}")
scp -q "${LOCAL_DB_DUMP}" "${SSH_USER}@${SSH_HOST}:/tmp/" || {
    echo -e "${RED}✗ Database upload failed${NC}"
    rm -f "${LOCAL_DB_DUMP}"
    send_notification "❌ Initial deployment failed: Database upload error"
    exit 1
}

echo -e "${GREEN}✓${NC} Database uploaded"
echo ""

# Импортируем БД на сервере и выполняем search-replace
echo "[4/4] Importing database and replacing URLs..."

# Определяем какие URL нужно заменить
SOURCE_URL="${LOCAL_SITE_URL}"
TARGET_URL="${SITE_URL}"

ssh "${SSH_USER}@${SSH_HOST}" bash -lc "\
  set -e; \
  cd '${WEBROOT}'; \
  \
  WP='/usr/local/bin/php ~/wp-cli.phar'; \
  \
  echo '→ Importing database...'; \
  gunzip -c /tmp/${DB_DUMP_BASENAME} | \$WP db import - 2>/dev/null || exit 1; \
  echo '✓ Database imported'; \
  \
  echo '→ Replacing URLs: ${SOURCE_URL} → ${TARGET_URL}'; \
  \$WP search-replace '${SOURCE_URL}' '${TARGET_URL}' \
    --precise \
    --recurse-objects \
    --all-tables \
    --skip-columns=guid \
    2>/dev/null || exit 1; \
  echo '✓ URLs replaced'; \
  \
  echo '→ Flushing cache...'; \
  \$WP cache flush 2>/dev/null || true; \
  \$WP rewrite flush 2>/dev/null || true; \
  echo '✓ Cache flushed'; \
  \
  rm -f /tmp/${DB_DUMP_BASENAME}; \
"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Database import/replace failed${NC}"
    rm -f "${LOCAL_DB_DUMP}"
    send_notification "❌ Initial deployment failed: Database import error"
    exit 1
fi

# Удаляем локальный дамп
rm -f "${LOCAL_DB_DUMP}"

echo -e "${GREEN}✓${NC} Database uploaded and configured successfully"
echo ""

# ============================================
# STEP 6: Upload WordPress Core Files (excluding wp-content)
# ============================================
echo -e "${BLUE}═══ STEP 6/10: Uploading WordPress Core Files ═══${NC}"
echo ""

echo "Creating archive of WordPress core (excluding wp-content)..."

# Создаём временный архив
CORE_ARCHIVE=$(mktemp /tmp/wp_core_XXXXXX.tar.gz)
EXCLUDE_FILE="${LOCAL_PROJECT_ROOT}/.deployignore"

# Архивируем WordPress исключая wp-content и .deployignore паттерны
if [ -f "${EXCLUDE_FILE}" ]; then
    echo "Using .deployignore file"
    tar --exclude='wordpress/wp-content' --exclude-from="${EXCLUDE_FILE}" \
        -C "${LOCAL_PROJECT_ROOT}" -czf "${CORE_ARCHIVE}" wordpress 2>/dev/null || {
        # Если tar не поддерживает --exclude-from, используем базовый exclude
        tar --exclude='wordpress/wp-content' \
            -C "${LOCAL_PROJECT_ROOT}" -czf "${CORE_ARCHIVE}" wordpress
    }
else
    tar --exclude='wordpress/wp-content' \
        -C "${LOCAL_PROJECT_ROOT}" -czf "${CORE_ARCHIVE}" wordpress
fi

CORE_SIZE=$(du -h "${CORE_ARCHIVE}" | cut -f1)
echo "Archive created: ${CORE_SIZE}"
echo ""

# Загружаем архив на сервер
echo "Uploading core archive to server..."
CORE_BASENAME=$(basename "${CORE_ARCHIVE}")
scp -q "${CORE_ARCHIVE}" "${SSH_USER}@${SSH_HOST}:/tmp/" || {
    echo -e "${RED}✗ Upload failed${NC}"
    rm -f "${CORE_ARCHIVE}"
    send_notification "❌ Initial deployment failed: Core upload error"
    exit 1
}

# Распаковываем на сервере
echo "Extracting core files on server..."
ssh "${SSH_USER}@${SSH_HOST}" bash -lc "\
  set -e; \
  tar -xzf /tmp/${CORE_BASENAME} -C '${WEBROOT}' --strip-components=1 --keep-newer-files 2>/dev/null || \
  tar -xzf /tmp/${CORE_BASENAME} -C '${WEBROOT}' --strip-components=1; \
  rm -f /tmp/${CORE_BASENAME}; \
"

# Удаляем локальный архив
rm -f "${CORE_ARCHIVE}"

echo -e "${GREEN}✓${NC} WordPress core files uploaded successfully"
echo ""

# ============================================
# STEP 6.5: Upload wp-content/uploads
# ============================================
echo -e "${BLUE}═══ STEP 6.5/11: Uploading wp-content/uploads ═══${NC}"
echo ""

UPLOADS_DIR_LOCAL="${LOCAL_PROJECT_ROOT}/wordpress/wp-content/uploads"

if [ -d "${UPLOADS_DIR_LOCAL}" ]; then
    # Проверяем размер uploads
    UPLOADS_SIZE_MB=$(du -sm "${UPLOADS_DIR_LOCAL}" | cut -f1)
    echo "Uploads directory size: ${UPLOADS_SIZE_MB} MB"
    
    # Если uploads больше 500MB, предупреждаем
    if [ ${UPLOADS_SIZE_MB} -gt 500 ]; then
        echo -e "${YELLOW}⚠️  WARNING: Uploads directory is large (${UPLOADS_SIZE_MB} MB)${NC}"
        echo "Upload may take a long time or fail due to connection timeout."
        echo ""
        
        if [ -t 0 ]; then
            read -p "Do you want to upload uploads now? (yes/no/skip): " -r UPLOAD_CONFIRM
        else
            read -r UPLOAD_CONFIRM < /dev/tty
            echo "Upload uploads? (yes/no/skip): $UPLOAD_CONFIRM"
        fi
        
        if [[ ! $UPLOAD_CONFIRM =~ ^[Yy][Ee][Ss]$ ]]; then
            echo -e "${YELLOW}ℹ️  Skipping uploads. You can upload them manually later using rsync:${NC}"
            echo "  rsync -avz --progress ${UPLOADS_DIR_LOCAL}/ ${SSH_USER}@${SSH_HOST}:${WEBROOT}/wp-content/uploads/"
            echo ""
            # Пропускаем uploads
            echo -e "${GREEN}✓${NC} Uploads skipped (will need manual upload)"
            echo ""
            # Продолжаем без ошибки
            SKIP_UPLOADS=true
        fi
    fi
    
    if [ "${SKIP_UPLOADS:-false}" != "true" ]; then
        echo "Creating uploads archive..."
        
        UPLOADS_ARCHIVE=$(mktemp /tmp/wp_uploads_XXXXXX.tar.gz)
        tar -C "${LOCAL_PROJECT_ROOT}/wordpress/wp-content" -czf "${UPLOADS_ARCHIVE}" uploads
        
        UPLOADS_SIZE=$(du -h "${UPLOADS_ARCHIVE}" | cut -f1)
        echo "Uploads archive created: ${UPLOADS_SIZE}"
        echo ""
        
        echo "Uploading uploads archive to server (this may take a while)..."
        UPLOADS_BASENAME=$(basename "${UPLOADS_ARCHIVE}")
        
        # Пробуем загрузить с таймаутом и повторными попытками
        UPLOAD_SUCCESS=false
        for attempt in 1 2 3; do
            echo "Upload attempt ${attempt}/3..."
            if scp -o ConnectTimeout=30 -o ServerAliveInterval=60 "${UPLOADS_ARCHIVE}" "${SSH_USER}@${SSH_HOST}:/tmp/"; then
                UPLOAD_SUCCESS=true
                break
            else
                echo "Attempt ${attempt} failed"
                sleep 5
            fi
        done
        
        if [ "${UPLOAD_SUCCESS}" != "true" ]; then
            echo -e "${RED}✗ Uploads upload failed after 3 attempts${NC}"
            echo -e "${YELLOW}You can upload uploads manually later using rsync:${NC}"
            echo "  rsync -avz --progress ${UPLOADS_DIR_LOCAL}/ ${SSH_USER}@${SSH_HOST}:${WEBROOT}/wp-content/uploads/"
            rm -f "${UPLOADS_ARCHIVE}"
            # Не выходим с ошибкой, просто предупреждаем
            echo -e "${YELLOW}⚠️  Continuing without uploads${NC}"
            echo ""
        else
            echo "Extracting uploads on server..."
            ssh "${SSH_USER}@${SSH_HOST}" bash -lc "\
              set -e; \
              mkdir -p '${WEBROOT}/wp-content'; \
              tar -xzf /tmp/${UPLOADS_BASENAME} -C '${WEBROOT}/wp-content'; \
              rm -f /tmp/${UPLOADS_BASENAME}; \
            "
            
            # Удаляем локальный архив
            rm -f "${UPLOADS_ARCHIVE}"
            
            echo -e "${GREEN}✓${NC} Uploads uploaded successfully"
        fi
    fi
else
    echo -e "${YELLOW}ℹ️  No local uploads directory found - skipping${NC}"
fi

echo ""

# ============================================
# STEP 7: Set Permissions
# ============================================
echo -e "${BLUE}═══ STEP 7/11: Setting Permissions ═══${NC}"
echo ""

ssh "${SSH_USER}@${SSH_HOST}" << 'ENDSSH'
cd ${WEBROOT}

# Устанавливаем права на файлы и директории
echo "Setting file permissions..."
find . -type f -exec chmod 644 {} \;
find . -type d -exec chmod 755 {} \;

# Специальные права для wp-content/uploads
if [ -d "wp-content/uploads" ]; then
    chmod -R 775 wp-content/uploads
    echo "✓ Upload directory permissions set"
fi

# Специальные права для кеша и временных файлов
if [ -d "wp-content/cache" ]; then
    chmod -R 775 wp-content/cache
fi

echo "✓ Permissions configured"
ENDSSH

echo -e "${GREEN}✓${NC} Permissions set successfully"
echo ""

# ============================================
# STEP 8: Create Deployment Marker
# ============================================
echo -e "${BLUE}═══ STEP 8/11: Creating Deployment Marker ═══${NC}"
echo ""

ssh "${SSH_USER}@${SSH_HOST}" bash -lc "\
  set -e; \
  mkdir -p '${WEBROOT}/.deployment-history'; \
  cat > '${WEBROOT}/.deployment-history/last-deployment.json' << 'DEPLOYEOF'
{
    \"type\": \"initial\",
    \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
    \"date_human\": \"$(date)\",
    \"commit\": \"$(cd ${WEBROOT} 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo 'unknown')\",
    \"branch\": \"${GIT_BRANCH}\"
}
DEPLOYEOF
  echo '✓ Deployment marker created'; \
"

echo -e "${GREEN}✓${NC} Deployment marker created"
echo ""

# ============================================
# STEP 9: Setup HTTP Authentication for DEV
# ============================================
if [ "$ENVIRONMENT" == "dev" ]; then
    echo -e "${BLUE}═══ STEP 9/11: Setting up HTTP Authentication ═══${NC}"
    echo ""
    
    echo "Creating htpasswd protection for dev environment..."
    
    # Создаём .htpasswd файл с учётными данными test/test
    # Пароль "test" захеширован с помощью Apache htpasswd
    ssh "${SSH_USER}@${SSH_HOST}" << 'ENDSSH'
# Переходим в webroot
cd "${WEBROOT}"

# Создаём .htpasswd файл с пользователем test и паролем test
# Хеш сгенерирован: htpasswd -nb test test
echo 'test:$apr1$ruca84Hq$dTCYlmXX7dkzByffVd4DT.' > .htpasswd

# Устанавливаем правильные права доступа
chmod 644 .htpasswd

echo "✓ .htpasswd file created"

# Создаём .htaccess для базовой аутентификации
cat > .htaccess << 'EOF'
# HTTP Basic Authentication for DEV environment
AuthType Basic
AuthName "Development Site - Restricted Access"
AuthUserFile ${WEBROOT}/.htpasswd
Require valid-user

# WordPress rules (below authentication)
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
EOF

# Заменяем ${WEBROOT} на реальный путь
sed -i "s|\${WEBROOT}|${WEBROOT}|g" .htaccess

echo "✓ .htaccess file created with authentication"
ENDSSH
    
    echo -e "${GREEN}✓${NC} HTTP Authentication configured"
    echo -e "  Username: ${YELLOW}test${NC}"
    echo -e "  Password: ${YELLOW}test${NC}"
    echo ""
else
    echo -e "${BLUE}═══ STEP 9/11: Skipping HTTP Authentication (PROD) ═══${NC}"
    echo ""
fi

# ============================================
# STEP 10: Verification
# ============================================
echo -e "${BLUE}═══ STEP 10/11: Verifying Installation ═══${NC}"
echo ""

VERIFICATION=$(ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
cd ${WEBROOT}

echo "Checking critical files..."

# Проверяем основные файлы
MISSING=""
if [ ! -f "index.php" ]; then MISSING="\${MISSING} index.php"; fi
if [ ! -f "wp-config.php" ]; then MISSING="\${MISSING} wp-config.php"; fi
if [ ! -f "wp-load.php" ]; then MISSING="\${MISSING} wp-load.php"; fi
if [ ! -d "wp-content" ]; then MISSING="\${MISSING} wp-content/"; fi
if [ ! -d "wp-includes" ]; then MISSING="\${MISSING} wp-includes/"; fi
if [ ! -d "wp-admin" ]; then MISSING="\${MISSING} wp-admin/"; fi

if [ -n "\$MISSING" ]; then
    echo "MISSING:\$MISSING"
else
    echo "OK"
fi
ENDSSH
)

if [[ "$VERIFICATION" == *"MISSING:"* ]]; then
    MISSING_FILES="${VERIFICATION#*MISSING:}"
    echo -e "${RED}✗ Verification failed. Missing files:${NC}"
    echo "$MISSING_FILES"
    echo ""
    echo "Please check the deployment logs and try again."
    send_notification "❌ Initial deployment failed: Missing files"
    exit 1
fi

echo -e "${GREEN}✓${NC} All critical files present"

# Показываем статистику
echo ""
echo "Installation statistics:"
ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
cd ${WEBROOT}
echo "  Files: \$(find . -type f | wc -l)"
echo "  Directories: \$(find . -type d | wc -l)"
echo "  Total size: \$(du -sh . | cut -f1)"
ENDSSH

echo ""

# ============================================
# STEP 11: Final Database Verification
# ============================================
echo -e "${BLUE}═══ STEP 11/11: Verifying Database Connection ═══${NC}"
echo ""

DB_CHECK=$(ssh "${SSH_USER}@${SSH_HOST}" bash -lc "\
  WP='/usr/local/bin/php ~/wp-cli.phar'; \
  cd '${WEBROOT}'; \
  if \$WP db check 2>/dev/null; then \
    echo 'OK'; \
  else \
    echo 'FAILED'; \
  fi \
")

if [[ "$DB_CHECK" == *"OK"* ]]; then
    echo -e "${GREEN}✓${NC} Database connection verified"
    
    # Показываем информацию о БД
    echo ""
    echo "Database information:"
    ssh "${SSH_USER}@${SSH_HOST}" bash -lc "\
      WP='/usr/local/bin/php ~/wp-cli.phar'; \
      cd '${WEBROOT}'; \
      echo '  Tables: \$(\$WP db query \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE();\" --skip-column-names 2>/dev/null)'; \
      echo '  Site URL: \$(\$WP option get siteurl 2>/dev/null)'; \
      echo '  Home URL: \$(\$WP option get home 2>/dev/null)'; \
    "
else
    echo -e "${YELLOW}⚠️  Warning: Could not verify database connection${NC}"
    echo "Please check database credentials in wp-config.php"
fi

echo ""

# ============================================
# SUCCESS
# ============================================
echo -e "${MAGENTA}╔════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║      INITIAL DEPLOYMENT SUCCESSFUL! 🎉         ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✓${NC} WordPress fully deployed to ${ENV_UPPER}"
echo -e "  Location: ${WEBROOT}"
echo -e "  Site URL: ${SITE_URL}"
echo -e "  Database: Imported and configured"
echo ""

if [ "$ENVIRONMENT" == "dev" ]; then
    echo -e "${YELLOW}🔒 HTTP Authentication enabled:${NC}"
    echo -e "  Username: ${GREEN}test${NC}"
    echo -e "  Password: ${GREEN}test${NC}"
    echo ""
fi

echo -e "${BLUE}Next steps:${NC}"
echo "  1. Test the site: ${SITE_URL}"
if [ "$ENVIRONMENT" == "dev" ]; then
    echo "     (use test/test for HTTP authentication)"
fi
echo "  2. Verify WordPress admin access"
echo "  3. Check all pages and functionality"
echo "  4. Use regular deploy scripts for future updates"
echo ""

send_notification "✅ Initial deployment to ${ENV_UPPER} completed successfully!"

exit 0
