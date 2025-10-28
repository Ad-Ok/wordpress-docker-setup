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

echo -e "${MAGENTA}╔════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║         INITIAL DEPLOYMENT - ${ENVIRONMENT^^}                 ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# ПРЕДУПРЕЖДЕНИЕ
# ============================================
echo -e "${YELLOW}⚠️  WARNING: Initial Deployment${NC}"
echo ""
echo "This script will:"
echo "  • Upload FULL WordPress installation"
echo "  • Upload ALL wp-content (themes, plugins, uploads)"
echo "  • Initialize Git repository on server"
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
# STEP 5: Upload WordPress Files via rsync
# ============================================
echo -e "${BLUE}═══ STEP 5/8: Uploading WordPress Files ═══${NC}"
echo ""

echo "This may take several minutes depending on size..."
echo ""

# Проверяем наличие .deployignore
EXCLUDE_FILE="${LOCAL_PROJECT_ROOT}/.deployignore"
TEMP_EXCLUDE_FILE=""

if [ -f "$EXCLUDE_FILE" ]; then
    echo "Using .deployignore file"
else
    echo "Creating temporary exclude list..."
    TEMP_EXCLUDE_FILE=$(mktemp)
    cat > "$TEMP_EXCLUDE_FILE" << 'EOF'
.git/
.gitignore
.gitmodules
.DS_Store
.env
.env.*
node_modules/
*.log
logs/
.vscode/
.idea/
*.swp
*.swo
*~
.htpasswd
deployment-scripts/config.sh
backups/
mysql/
docker-compose.yml
README.md
docs/
EOF
    EXCLUDE_FILE="$TEMP_EXCLUDE_FILE"
fi

# Upload WordPress core + wp-content
echo "Uploading WordPress files..."
rsync -avz --progress \
    --exclude-from="$EXCLUDE_FILE" \
    "${LOCAL_PROJECT_ROOT}/wordpress/" \
    "${SSH_USER}@${SSH_HOST}:${WEBROOT}/"

# Проверяем результат
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓${NC} WordPress files uploaded successfully"
else
    echo ""
    echo -e "${RED}✗ File upload failed${NC}"
    [ -n "$TEMP_EXCLUDE_FILE" ] && rm -f "$TEMP_EXCLUDE_FILE"
    send_notification "❌ Initial deployment failed: File upload error"
    exit 1
fi

# Удаляем временный файл если создавали
[ -n "$TEMP_EXCLUDE_FILE" ] && rm -f "$TEMP_EXCLUDE_FILE"

echo ""

# ============================================
# STEP 6: Инициализация Git на сервере
# ============================================
echo -e "${BLUE}═══ STEP 6/8: Initializing Git Repository ═══${NC}"
echo ""

# Получаем URL репозитория из локального .git
cd "${LOCAL_PROJECT_ROOT}/wordpress"
GIT_REMOTE_URL=$(git config --get remote.origin.url || echo "")

if [ -z "$GIT_REMOTE_URL" ]; then
    echo -e "${YELLOW}⚠️  WARNING: Could not determine Git remote URL${NC}"
    echo "You'll need to set it up manually on the server."
    GIT_SETUP="manual"
else
    echo "Git remote URL: $GIT_REMOTE_URL"
    GIT_SETUP="auto"
fi

ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
cd ${WEBROOT}

# Инициализируем git если ещё не инициализирован
if [ ! -d ".git" ]; then
    echo "Initializing Git repository..."
    git init
    
    if [ "$GIT_SETUP" == "auto" ]; then
        echo "Adding remote origin..."
        git remote add origin "${GIT_REMOTE_URL}"
        
        echo "Fetching from remote..."
        git fetch origin
        
        echo "Setting up branch..."
        git checkout -b ${GIT_BRANCH}
        git branch --set-upstream-to=origin/${GIT_BRANCH} ${GIT_BRANCH}
        
        echo "✓ Git repository configured"
    else
        echo "⚠️  Git initialized but remote not configured"
        echo "Please run manually on server:"
        echo "  cd ${WEBROOT}"
        echo "  git remote add origin <your-repo-url>"
        echo "  git fetch origin"
        echo "  git checkout -b ${GIT_BRANCH}"
        echo "  git branch --set-upstream-to=origin/${GIT_BRANCH}"
    fi
else
    echo "Git repository already exists"
fi
ENDSSH

echo -e "${GREEN}✓${NC} Git repository initialized"
echo ""

# ============================================
# STEP 7: Set Permissions
# ============================================
echo -e "${BLUE}═══ STEP 7/8: Setting Permissions ═══${NC}"
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
# STEP 8: Verification
# ============================================
echo -e "${BLUE}═══ STEP 8/8: Verifying Installation ═══${NC}"
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

echo -e "${GREEN}✓${NC} WordPress fully deployed to ${ENVIRONMENT^^}"
echo -e "  Location: ${WEBROOT}"
echo -e "  Site URL: ${SITE_URL}"
echo ""

echo -e "${BLUE}Next steps:${NC}"
echo "  1. Verify wp-config.php database settings"
echo "  2. Run database import if needed"
echo "  3. Test the site: ${SITE_URL}"
echo "  4. Use regular deploy scripts for future updates"
echo ""

send_notification "✅ Initial deployment to ${ENVIRONMENT^^} completed successfully!"

exit 0
