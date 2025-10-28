#!/bin/bash
# 🚀 Deploy to PRODUCTION
# Релизный деплой с полным циклом проверок

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

# Проверка dry-run режима
DRY_RUN_MODE="${DRY_RUN:-false}"
if [ "$1" == "--dry-run" ]; then
    DRY_RUN_MODE="true"
fi

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      PRODUCTION DEPLOYMENT - your-domain.com       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$DRY_RUN_MODE" == "true" ]; then
    echo -e "${YELLOW}🧪 DRY RUN MODE - No actual changes will be made${NC}"
    echo ""
fi

# ============================================
# STEP 1: Pre-deployment Checklist
# ============================================
echo -e "${BLUE}═══ STEP 1/10: Pre-deployment Checklist ═══${NC}"
echo ""

if ! bash "${SCRIPT_DIR}/pre-deployment-checklist.sh"; then
    echo ""
    echo -e "${RED}Pre-deployment checklist failed!${NC}"
    echo "Fix the issues and try again."
    exit 1
fi

echo ""

# ============================================
# STEP 2: Confirmation
# ============================================
if [ "$REQUIRE_CONFIRMATION" == "true" ] && [ "$DRY_RUN_MODE" != "true" ]; then
    echo -e "${BLUE}═══ STEP 2/10: Confirmation ═══${NC}"
    echo ""
    
    # Определяем корень git репозитория
    GIT_ROOT="$(cd "${SCRIPT_DIR}/.." && git rev-parse --show-toplevel)"
    
    CURRENT_COMMIT=$(cd "${GIT_ROOT}" && git rev-parse --short HEAD)
    COMMIT_MESSAGE=$(cd "${GIT_ROOT}" && git log -1 --pretty=%B)
    
    echo -e "Commit: ${GREEN}${CURRENT_COMMIT}${NC}"
    echo -e "Message: ${COMMIT_MESSAGE}"
    echo ""
    echo -e "${YELLOW}⚠️  You are about to deploy to PRODUCTION${NC}"
    echo ""
    read -p "Continue? (yes/no): " -r CONFIRM
    
    if [[ ! $CONFIRM =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${RED}Deployment cancelled by user${NC}"
        exit 0
    fi
    echo ""
fi

# ============================================
# STEP 3: SSH Connection Test
# ============================================
echo -e "${BLUE}═══ STEP 3/10: Testing SSH Connection ═══${NC}"
echo ""

if [ "$DRY_RUN_MODE" != "true" ]; then
    if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "${PROD_SSH_USER}@${PROD_SSH_HOST}" exit; then
        echo -e "${RED}✗ Cannot connect to PROD server${NC}"
        send_notification "❌ PROD deployment failed: SSH connection error"
        exit 1
    fi
fi

echo -e "${GREEN}✓${NC} SSH connection successful"
echo ""

# ============================================
# STEP 4: Backup
# ============================================
echo -e "${BLUE}═══ STEP 4/10: Creating Backup ═══${NC}"
echo ""

if [ "$BACKUP_BEFORE_DEPLOY" == "true" ] && [ "$DRY_RUN_MODE" != "true" ]; then
    bash "${SCRIPT_DIR}/utils/backup.sh" prod
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Backup failed${NC}"
        send_notification "❌ PROD deployment failed: Backup error"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Backup created successfully"
else
    echo -e "${YELLOW}ℹ️  Skipping backup (disabled or dry-run)${NC}"
fi

echo ""

# ============================================
# STEP 5: Enable Maintenance Mode
# ============================================
echo -e "${BLUE}═══ STEP 5/10: Enabling Maintenance Mode ═══${NC}"
echo ""

if [ "$MAINTENANCE_MODE_ENABLED" == "true" ] && [ "$DRY_RUN_MODE" != "true" ]; then
    ssh "${PROD_SSH_USER}@${PROD_SSH_HOST}" << 'ENDSSH'
cd ${PROD_WEBROOT}
# Создаем .maintenance файл
echo "<?php \$upgrading = time(); ?>" > .maintenance
ENDSSH
    
    echo -e "${GREEN}✓${NC} Maintenance mode enabled"
else
    echo -e "${YELLOW}ℹ️  Skipping maintenance mode${NC}"
fi

echo ""

# ============================================
# STEP 6: Pull Changes from Git
# ============================================
echo -e "${BLUE}═══ STEP 6/10: Pulling Changes from Git ═══${NC}"
echo ""

if [ "$DRY_RUN_MODE" != "true" ]; then
    ssh "${PROD_SSH_USER}@${PROD_SSH_HOST}" << ENDSSH
cd ${PROD_WEBROOT}

echo "Current branch: \$(git rev-parse --abbrev-ref HEAD)"
echo "Current commit: \$(git rev-parse --short HEAD)"
echo ""

echo "Fetching from origin..."
git fetch origin

echo "Pulling ${PROD_GIT_BRANCH}..."
git pull origin ${PROD_GIT_BRANCH}

echo ""
echo "New commit: \$(git rev-parse --short HEAD)"
ENDSSH
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Git pull failed${NC}"
        
        # Отключить maintenance mode
        ssh "${PROD_SSH_USER}@${PROD_SSH_HOST}" "rm -f ${PROD_WEBROOT}/.maintenance"
        
        send_notification "❌ PROD deployment failed: Git pull error"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Changes pulled successfully"
else
    echo -e "${YELLOW}ℹ️  DRY RUN: Would pull from ${PROD_GIT_BRANCH}${NC}"
fi

echo ""

# ============================================
# STEP 7: Run Database Migrations
# ============================================
echo -e "${BLUE}═══ STEP 7/10: Running Database Migrations ═══${NC}"
echo ""

if [ "$AUTO_RUN_MIGRATIONS" == "true" ] && [ "$DRY_RUN_MODE" != "true" ]; then
    ssh "${PROD_SSH_USER}@${PROD_SSH_HOST}" << ENDSSH
cd ${PROD_WP_PATH}

if [ -f "wp-content/migrations/migration_runner.php" ]; then
    echo "Checking migrations status..."
    wp your-project migrate:status
    
    echo ""
    echo "Running migrations..."
    wp your-project migrate
    
    if [ \$? -eq 0 ]; then
        echo "✓ Migrations completed"
    else
        echo "✗ Migrations failed"
        exit 1
    fi
else
    echo "ℹ️  No migrations found"
fi
ENDSSH
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Migrations failed${NC}"
        
        # Отключить maintenance mode
        ssh "${PROD_SSH_USER}@${PROD_SSH_HOST}" "rm -f ${PROD_WEBROOT}/.maintenance"
        
        send_notification "❌ PROD deployment failed: Migration error"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Migrations completed"
else
    echo -e "${YELLOW}ℹ️  Skipping migrations${NC}"
fi

echo ""

# ============================================
# STEP 8: Clear Cache
# ============================================
echo -e "${BLUE}═══ STEP 8/10: Clearing Cache ═══${NC}"
echo ""

if [ "$AUTO_CLEAR_CACHE" == "true" ] && [ "$DRY_RUN_MODE" != "true" ]; then
    ssh "${PROD_SSH_USER}@${PROD_SSH_HOST}" << ENDSSH
cd ${PROD_WP_PATH}

echo "Flushing WordPress cache..."
wp cache flush

echo "Flushing rewrite rules..."
wp rewrite flush

# Если есть плагин кеширования
if wp plugin is-active wp-super-cache 2>/dev/null; then
    echo "Flushing WP Super Cache..."
    wp super-cache flush
fi

if wp plugin is-active w3-total-cache 2>/dev/null; then
    echo "Flushing W3 Total Cache..."
    wp w3-total-cache flush
fi
ENDSSH
    
    echo -e "${GREEN}✓${NC} Cache cleared"
else
    echo -e "${YELLOW}ℹ️  Skipping cache clearing${NC}"
fi

echo ""

# ============================================
# STEP 9: Disable Maintenance Mode
# ============================================
echo -e "${BLUE}═══ STEP 9/10: Disabling Maintenance Mode ═══${NC}"
echo ""

if [ "$MAINTENANCE_MODE_ENABLED" == "true" ] && [ "$DRY_RUN_MODE" != "true" ]; then
    ssh "${PROD_SSH_USER}@${PROD_SSH_HOST}" "rm -f ${PROD_WEBROOT}/.maintenance"
    echo -e "${GREEN}✓${NC} Maintenance mode disabled"
else
    echo -e "${YELLOW}ℹ️  Maintenance mode was not enabled${NC}"
fi

echo ""

# ============================================
# STEP 10: Smoke Tests
# ============================================
echo -e "${BLUE}═══ STEP 10/10: Running Smoke Tests ═══${NC}"
echo ""

if [ "$DRY_RUN_MODE" != "true" ]; then
    if bash "${SCRIPT_DIR}/smoke-tests.sh" prod; then
        echo -e "${GREEN}✓${NC} All smoke tests passed"
    else
        echo -e "${RED}✗ Smoke tests failed${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  Deployment completed but tests failed${NC}"
        echo "Site is live but may have issues. Check logs."
        
        send_notification "⚠️ PROD deployed but smoke tests failed"
        exit 1
    fi
else
    echo -e "${YELLOW}ℹ️  DRY RUN: Would run smoke tests${NC}"
fi

echo ""

# ============================================
# SUCCESS
# ============================================
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           DEPLOYMENT SUCCESSFUL! 🎉             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

CURRENT_COMMIT=$(cd "${LOCAL_PROJECT_ROOT}" && git rev-parse --short HEAD)

echo -e "${GREEN}✓${NC} Production deployment completed"
echo -e "  Commit: ${CURRENT_COMMIT}"
echo -e "  Site: ${PROD_SITE_URL}"
echo ""

if [ "$DRY_RUN_MODE" != "true" ]; then
    send_notification "✅ PROD deployed successfully! Commit: ${CURRENT_COMMIT}"
fi

exit 0
