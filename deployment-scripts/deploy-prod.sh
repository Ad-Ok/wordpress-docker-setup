#!/bin/bash
# 🚀 Deploy to PRODUCTION
# Релизный деплой с полным циклом проверок
#
# Флаги:
#   --dry-run            Режим симуляции без реальных изменений
#   --skip-migrations    Деплой без миграций (для первого запуска перед ручной настройкой Polylang)

set -e

# Парсинг аргументов
SKIP_MIGRATIONS=false
DRY_RUN_MODE="${DRY_RUN:-false}"

for arg in "$@"; do
    case $arg in
        --skip-migrations)
            SKIP_MIGRATIONS=true
            shift
            ;;
        --dry-run)
            DRY_RUN_MODE="true"
            shift
            ;;
        *)
            ;;
    esac
done

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils/notifications.sh"
source "${SCRIPT_DIR}/utils/deployment-helpers.sh"
source "${SCRIPT_DIR}/utils/version-bump.sh"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      PRODUCTION DEPLOYMENT - your-domain.com       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Показываем активные флаги
if [ "$DRY_RUN_MODE" == "true" ]; then
    echo -e "${YELLOW}🧪 DRY RUN MODE - No actual changes will be made${NC}"
fi
if [ "$SKIP_MIGRATIONS" = true ]; then
    echo -e "${YELLOW}⚠️  Mode: Deployment WITHOUT migrations${NC}"
fi
[ "$DRY_RUN_MODE" == "true" ] || [ "$SKIP_MIGRATIONS" = true ] && echo ""

# ============================================
# Проверка: Первый ли это деплой?
# ============================================
echo -e "${BLUE}Checking deployment type...${NC}"

if is_first_deployment "$PROD_SSH_USER" "$PROD_SSH_HOST" "$PROD_WEBROOT"; then
    echo -e "${YELLOW}⚠️  First deployment detected!${NC}"
    echo ""
    echo "This appears to be the first deployment to this server."
    echo "You should use the initial-deploy.sh script instead."
    echo ""
    echo -e "${BLUE}Run:${NC}"
    echo "  ./deployment-scripts/initial-deploy.sh prod"
    echo ""
    
    if [ -t 0 ]; then
        read -p "Continue with regular deploy anyway? (yes/no): " -r FORCE_REGULAR
    else
        read -r FORCE_REGULAR < /dev/tty
        echo "Continue? (yes/no): $FORCE_REGULAR"
    fi
    
    if [[ ! $FORCE_REGULAR =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${YELLOW}Deployment cancelled. Use initial-deploy.sh for first deployment.${NC}"
        exit 0
    fi
    
    echo -e "${YELLOW}Proceeding with regular deployment as requested...${NC}"
    echo ""
else
    echo -e "${GREEN}✓${NC} Regular deployment (WordPress already installed)"
    echo ""
fi

# ============================================
# STEP 0: Version Bump & Build
# ============================================
echo -e "${BLUE}═══ STEP 0/10: Version Bump ═══${NC}"
echo ""

if [ "$DRY_RUN_MODE" != "true" ]; then
    # Увеличиваем версию темы
    version_bump
    
    if [ $? -eq 0 ]; then
        # Коммитим и пушим изменения версии
        WP_GIT_ROOT="${SCRIPT_DIR}/../wordpress"
        cd "${WP_GIT_ROOT}"
        
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        
        echo -e "${BLUE}Committing version bump...${NC}"
        cd wp-content/themes/maslovka
        git add style.css
        git commit -m "chore: bump theme version" || true
        
        echo -e "${BLUE}Pushing to ${CURRENT_BRANCH}...${NC}"
        git push origin "${CURRENT_BRANCH}"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Version bump pushed${NC}"
        else
            echo -e "${YELLOW}⚠️  Failed to push version bump, but continuing...${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Version bump failed, but continuing...${NC}"
    fi
else
    echo -e "${YELLOW}Skipping version bump in dry-run mode${NC}"
fi

echo ""

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
    
    # Работаем с WordPress сабмодулем
    WP_GIT_ROOT="${SCRIPT_DIR}/../wordpress"
    
    CURRENT_COMMIT=$(cd "${WP_GIT_ROOT}" && git rev-parse --short HEAD)
    COMMIT_MESSAGE=$(cd "${WP_GIT_ROOT}" && git log -1 --pretty=%B)
    CURRENT_BRANCH=$(cd "${WP_GIT_ROOT}" && git rev-parse --abbrev-ref HEAD)
    
    echo -e "Branch: ${GREEN}${CURRENT_BRANCH}${NC}"
    echo -e "Commit: ${GREEN}${CURRENT_COMMIT}${NC}"
    echo -e "Message: ${COMMIT_MESSAGE}"
    echo ""
    echo -e "${YELLOW}⚠️  You are about to deploy to PRODUCTION${NC}"
    echo ""
    
    # Читаем из /dev/tty для корректной работы с pipes
    if [ -t 0 ]; then
        read -p "Continue? (yes/no): " -r CONFIRM
    else
        read -r CONFIRM < /dev/tty
        echo "Continue? (yes/no): $CONFIRM"
    fi
    
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

# Проверка на первый деплой (если есть только дефолтный index.php хостинга)
if [ -f "index.php" ] && [ ! -d ".git" ]; then
    echo "⚠️  Detected default hosting files. Cleaning for first deployment..."
    
    # Сохраняем .git если он уже есть
    if [ -d ".git" ]; then
        echo "Git already initialized, keeping .git directory"
    fi
    
    # Удаляем дефолтные файлы хостинга
    rm -f index.php
    echo "✓ Default hosting files removed"
fi

echo "Current branch: \$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'none')"
echo "Current commit: \$(git rev-parse --short HEAD 2>/dev/null || echo 'none')"
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
if [ "$SKIP_MIGRATIONS" = true ]; then
    echo -e "${BLUE}═══ STEP 7/10: Migrations (SKIPPED) ═══${NC}"
    echo ""
    echo -e "${YELLOW}⊘${NC} Migrations skipped as requested"
    echo ""
elif [ "$AUTO_RUN_MIGRATIONS" == "true" ] && [ "$DRY_RUN_MODE" != "true" ]; then
    echo -e "${BLUE}═══ STEP 7/10: Running Database Migrations ═══${NC}"
    echo ""
    
    "${SCRIPT_DIR}/database/db-migrate.sh" apply prod
    
    echo -e "${GREEN}✓${NC} Migrations checked"
    echo ""
else
    echo -e "${BLUE}═══ STEP 7/10: Migrations (SKIPPED) ═══${NC}"
    echo ""
    echo -e "${YELLOW}ℹ️  Skipping migrations${NC}"
    echo ""
fi

# ============================================
# STEP 8: Clear Cache
# ============================================
echo -e "${BLUE}═══ STEP 8/10: Clearing Cache ═══${NC}"
echo ""

if [ "$AUTO_CLEAR_CACHE" == "true" ] && [ "$DRY_RUN_MODE" != "true" ]; then
    ssh "${PROD_SSH_USER}@${PROD_SSH_HOST}" << ENDSSH
cd ${PROD_WP_PATH}

# Очистка WP Super Cache (если установлен)
if [ -d "wp-content/cache" ]; then
    echo "Clearing WP Super Cache..."
    rm -rf wp-content/cache/*
    echo "✓ Cache directory cleared"
fi

# Очистка кеша через PHP скрипт (для функций WordPress)
php -r "
define('WP_USE_THEMES', false);
require_once('wp-load.php');
if (function_exists('wp_cache_flush')) {
    wp_cache_flush();
    echo 'WordPress cache flushed\n';
}
"

echo "✓ Cache cleared"
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
