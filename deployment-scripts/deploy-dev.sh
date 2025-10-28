#!/bin/bash
# 🚀 Deploy to DEV
# Быстрый деплой на dev окружение

set -e

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils/notifications.sh"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      DEV DEPLOYMENT - dev.your-domain.com          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# STEP 1: Git Status Check
# ============================================
echo -e "${BLUE}═══ STEP 1/5: Checking Git Status ═══${NC}"
echo ""

# Работаем с WordPress сабмодулем, а не с корневым репозиторием
WP_GIT_ROOT="${SCRIPT_DIR}/../wordpress"
cd "${WP_GIT_ROOT}"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$CURRENT_BRANCH" != "dev" ]; then
    echo -e "${YELLOW}⚠️  WARNING: You are on branch '${CURRENT_BRANCH}', not 'dev'${NC}"
    read -p "Continue anyway? (yes/no): " -r CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        exit 0
    fi
fi

# Проверка, что изменения запушены
git fetch origin
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/${CURRENT_BRANCH} 2>/dev/null || echo "")

if [ -n "$REMOTE_COMMIT" ] && [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
    echo -e "${YELLOW}⚠️  Local branch is not in sync with remote${NC}"
    read -p "Push changes first? (yes/no): " -r PUSH_CONFIRM
    
    if [ "$PUSH_CONFIRM" == "yes" ]; then
        git push origin "$CURRENT_BRANCH"
        echo -e "${GREEN}✓${NC} Changes pushed"
    fi
fi

LOCAL_COMMIT=$(git rev-parse --short HEAD)
COMMIT_MESSAGE=$(git log -1 --pretty=%B)

echo -e "  Branch: ${GREEN}${CURRENT_BRANCH}${NC}"
echo -e "  Commit: ${GREEN}${LOCAL_COMMIT}${NC}"
echo -e "  Message: ${COMMIT_MESSAGE}"
echo -e "${GREEN}✓${NC} Git status OK"
echo ""

# ============================================
# STEP 2: SSH Connection
# ============================================
echo -e "${BLUE}═══ STEP 2/5: Testing SSH Connection ═══${NC}"
echo ""

if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "${DEV_SSH_USER}@${DEV_SSH_HOST}" exit; then
    echo -e "${RED}✗ Cannot connect to DEV server${NC}"
    send_notification "❌ DEV deployment failed: SSH connection error"
    exit 1
fi

echo -e "${GREEN}✓${NC} SSH connection OK"
echo ""

# ============================================
# STEP 3: Pull Changes
# ============================================
echo -e "${BLUE}═══ STEP 3/5: Pulling Changes ═══${NC}"
echo ""

ssh "${DEV_SSH_USER}@${DEV_SSH_HOST}" << ENDSSH
cd ${DEV_WEBROOT}

# Проверка на первый деплой (если есть только дефолтный index.php хостинга)
if [ -f "index.php" ] && [ ! -d ".git" ]; then
    echo "⚠️  Detected default hosting files. Cleaning for first deployment..."
    
    # Удаляем дефолтные файлы хостинга
    rm -f index.php
    echo "✓ Default hosting files removed"
fi

echo "Current branch: \$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'none')"
echo "Current commit: \$(git rev-parse --short HEAD 2>/dev/null || echo 'none')"
echo ""

echo "Pulling ${DEV_GIT_BRANCH}..."
git fetch origin
git pull origin ${DEV_GIT_BRANCH}

echo ""
echo "New commit: \$(git rev-parse --short HEAD)"
ENDSSH

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Git pull failed${NC}"
    send_notification "❌ DEV deployment failed: Git pull error"
    exit 1
fi

echo -e "${GREEN}✓${NC} Changes pulled"
echo ""

# ============================================
# STEP 4: Run Migrations (if any)
# ============================================
echo -e "${BLUE}═══ STEP 4/5: Running Migrations ═══${NC}"
echo ""

ssh "${DEV_SSH_USER}@${DEV_SSH_HOST}" << ENDSSH
cd ${DEV_WP_PATH}

if [ -f "wp-content/migrations/migration_runner.php" ]; then
    echo "Checking migrations..."
    wp your-project migrate:status || true
    
    echo ""
    echo "Running migrations..."
    wp your-project migrate || echo "No migrations to run"
else
    echo "No migrations directory found"
fi
ENDSSH

echo -e "${GREEN}✓${NC} Migrations checked"
echo ""

# ============================================
# STEP 5: Clear Cache
# ============================================
echo -e "${BLUE}═══ STEP 5/5: Clearing Cache ═══${NC}"
echo ""

ssh "${DEV_SSH_USER}@${DEV_SSH_HOST}" << ENDSSH
cd ${DEV_WP_PATH}

echo "Flushing WordPress cache..."
wp cache flush

echo "Flushing rewrite rules..."
wp rewrite flush

# Кеш плагины (если есть)
wp plugin is-active wp-super-cache 2>/dev/null && wp super-cache flush || true
wp plugin is-active w3-total-cache 2>/dev/null && wp w3-total-cache flush || true
ENDSSH

echo -e "${GREEN}✓${NC} Cache cleared"
echo ""

# ============================================
# SUCCESS
# ============================================
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           DEV DEPLOYMENT COMPLETE! ✓            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

CURRENT_COMMIT=$(git rev-parse --short HEAD)

echo -e "${GREEN}✓${NC} DEV deployment completed"
echo -e "  Branch: ${CURRENT_BRANCH}"
echo -e "  Commit: ${LOCAL_COMMIT}"
echo -e "  Site: ${DEV_SITE_URL}"
echo ""

send_notification "✅ DEV deployed: ${LOCAL_COMMIT} - ${COMMIT_MESSAGE}"

exit 0
