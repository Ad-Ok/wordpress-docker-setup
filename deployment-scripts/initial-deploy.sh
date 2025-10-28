#!/bin/bash
# 🚀 Initial Deployment Script
# Первый деплой: загружает полную инфраструктуру WordPress на сервер
# Использовать только для первоначального развёртывания!

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

# Проверяем, что wordpress директория существует
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
# STEP 6: Upload WordPress Core Files (excluding wp-content)
# ============================================
echo -e "${BLUE}═══ STEP 6/8: Uploading WordPress Core Files ═══${NC}"
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
echo -e "${BLUE}═══ STEP 6.5/9: Uploading wp-content/uploads ═══${NC}"
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
echo -e "${BLUE}═══ STEP 7/9: Setting Permissions ═══${NC}"
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
echo -e "${BLUE}═══ STEP 8/9: Creating Deployment Marker ═══${NC}"
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
    echo -e "${BLUE}═══ STEP 9/10: Setting up HTTP Authentication ═══${NC}"
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
    echo -e "${BLUE}═══ STEP 9/10: Skipping HTTP Authentication (PROD) ═══${NC}"
    echo ""
fi

# ============================================
# STEP 10: Verification
# ============================================
echo -e "${BLUE}═══ STEP 10/10: Verifying Installation ═══${NC}"
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
# SUCCESS
# ============================================
echo -e "${MAGENTA}╔════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║      INITIAL DEPLOYMENT SUCCESSFUL! 🎉         ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✓${NC} WordPress fully deployed to ${ENV_UPPER}"
echo -e "  Location: ${WEBROOT}"
echo -e "  Site URL: ${SITE_URL}"
echo ""

if [ "$ENVIRONMENT" == "dev" ]; then
    echo -e "${YELLOW}🔒 HTTP Authentication enabled:${NC}"
    echo -e "  Username: ${GREEN}test${NC}"
    echo -e "  Password: ${GREEN}test${NC}"
    echo ""
fi

echo -e "${BLUE}Next steps:${NC}"
echo "  1. Verify wp-config.php database settings"
echo "  2. Run database import if needed"
echo "  3. Test the site: ${SITE_URL}"
if [ "$ENVIRONMENT" == "dev" ]; then
    echo "     (use test/test for HTTP authentication)"
fi
echo "  4. Use regular deploy scripts for future updates"
echo ""

send_notification "✅ Initial deployment to ${ENV_UPPER} completed successfully!"

exit 0
