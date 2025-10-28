#!/bin/bash
# ⚡ Hotfix Deployment Script
# Быстрый деплой критических исправлений

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

# Параметры
HOTFIX_DESCRIPTION="${1:-urgent-fix}"
CURRENT_BRANCH=$(cd "${LOCAL_PROJECT_ROOT}" && git rev-parse --abbrev-ref HEAD)

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              HOTFIX DEPLOYMENT                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# Валидация
# ============================================
if [ -z "$HOTFIX_DESCRIPTION" ]; then
    echo -e "${RED}Usage: ./hotfix.sh \"description\"${NC}"
    echo "Example: ./hotfix.sh \"Fix cart calculation bug\""
    exit 1
fi

# Проверка незакоммиченных изменений
cd "${LOCAL_PROJECT_ROOT}"
if ! git diff-index --quiet HEAD --; then
    echo -e "${RED}✗ You have uncommitted changes${NC}"
    echo ""
    git status --short
    echo ""
    read -p "Do you want to continue anyway? (yes/no): " -r CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        exit 0
    fi
fi

# ============================================
# 1. Создать hotfix ветку
# ============================================
echo -e "${BLUE}[1/6]${NC} Creating hotfix branch..."

# Преобразовать описание в slug
HOTFIX_SLUG=$(echo "$HOTFIX_DESCRIPTION" | \
    tr '[:upper:]' '[:lower:]' | \
    sed 's/[^a-z0-9]/-/g' | \
    sed 's/--*/-/g' | \
    sed 's/^-//' | \
    sed 's/-$//')

HOTFIX_BRANCH="hotfix/${HOTFIX_SLUG}"

if [ "$CURRENT_BRANCH" == "$HOTFIX_BRANCH" ]; then
    echo -e "${YELLOW}Already on ${HOTFIX_BRANCH}${NC}"
else
    # Создать hotfix ветку от main
    git checkout main
    git pull origin main
    git checkout -b "$HOTFIX_BRANCH"
    
    echo -e "${GREEN}✓${NC} Created branch: ${HOTFIX_BRANCH}"
fi

echo ""

# ============================================
# 2. Показать diff и спросить, готов ли пользователь
# ============================================
echo -e "${BLUE}[2/6]${NC} Review changes..."
echo ""

# Показать изменения
git diff HEAD

echo ""
read -p "Ready to commit these changes? (yes/no): " -r COMMIT_CONFIRM

if [ "$COMMIT_CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Hotfix cancelled${NC}"
    echo "Branch ${HOTFIX_BRANCH} kept for manual work"
    exit 0
fi

echo ""

# ============================================
# 3. Коммит изменений
# ============================================
echo -e "${BLUE}[3/6]${NC} Committing changes..."

git add -A

COMMIT_MESSAGE="🔥 HOTFIX: ${HOTFIX_DESCRIPTION}"
git commit -m "$COMMIT_MESSAGE"

COMMIT_HASH=$(git rev-parse --short HEAD)
echo -e "${GREEN}✓${NC} Committed: ${COMMIT_HASH}"
echo ""

# ============================================
# 4. Push в remote
# ============================================
echo -e "${BLUE}[4/6]${NC} Pushing to remote..."

git push origin "$HOTFIX_BRANCH"

echo -e "${GREEN}✓${NC} Pushed to origin/${HOTFIX_BRANCH}"
echo ""

# ============================================
# 5. Merge в main
# ============================================
echo -e "${BLUE}[5/6]${NC} Merging to main..."

read -p "Merge to main and deploy now? (yes/no): " -r MERGE_CONFIRM

if [ "$MERGE_CONFIRM" == "yes" ]; then
    git checkout main
    git merge --no-ff "$HOTFIX_BRANCH" -m "Merge ${HOTFIX_BRANCH} into main"
    git push origin main
    
    echo -e "${GREEN}✓${NC} Merged to main"
    echo ""
    
    # ============================================
    # 6. Deploy to PROD
    # ============================================
    echo -e "${BLUE}[6/6]${NC} Deploying to PRODUCTION..."
    echo ""
    
    read -p "Deploy to PROD now? (yes/no): " -r DEPLOY_CONFIRM
    
    if [ "$DEPLOY_CONFIRM" == "yes" ]; then
        bash "${SCRIPT_DIR}/deploy-prod.sh"
        
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✓ Hotfix deployed successfully${NC}"
            send_notification "🔥 HOTFIX deployed: ${HOTFIX_DESCRIPTION} (${COMMIT_HASH})"
        else
            echo ""
            echo -e "${RED}✗ Deployment failed${NC}"
            send_notification "❌ HOTFIX deployment failed: ${HOTFIX_DESCRIPTION}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Deployment skipped${NC}"
        echo "Deploy manually later with: ./deploy-prod.sh"
    fi
    
    # Удалить hotfix ветку
    echo ""
    read -p "Delete hotfix branch? (yes/no): " -r DELETE_CONFIRM
    
    if [ "$DELETE_CONFIRM" == "yes" ]; then
        git branch -d "$HOTFIX_BRANCH"
        git push origin --delete "$HOTFIX_BRANCH"
        echo -e "${GREEN}✓${NC} Hotfix branch deleted"
    fi
else
    echo -e "${YELLOW}Merge skipped${NC}"
    echo ""
    echo "Manual steps:"
    echo "1. Create PR: ${HOTFIX_BRANCH} → main"
    echo "2. After merge, run: ./deploy-prod.sh"
fi

echo ""
echo -e "${GREEN}✓ Hotfix process completed${NC}"

exit 0
