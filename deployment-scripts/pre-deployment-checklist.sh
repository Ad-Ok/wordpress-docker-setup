#!/bin/bash
# 📋 Pre-deployment Checklist для your-domain.com
# Проверки перед деплоем на PROD

set -e

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Pre-Deployment Checklist for PRODUCTION      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# 1. Проверка Git статуса
# ============================================
echo -e "${BLUE}[1/10]${NC} Checking Git status..."

cd "${LOCAL_PROJECT_ROOT}"

# Проверка, что мы на нужной ветке
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
    echo -e "${YELLOW}⚠️  WARNING: You are on branch '${CURRENT_BRANCH}', not 'main'${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC} On correct branch: ${CURRENT_BRANCH}"
fi

# Проверка незакоммиченных изменений
if ! git diff-index --quiet HEAD --; then
    echo -e "${RED}✗ ERROR: You have uncommitted changes${NC}"
    git status --short
    ((ERRORS++))
else
    echo -e "${GREEN}✓${NC} No uncommitted changes"
fi

# Проверка, что локальная ветка синхронизирована с remote
git fetch origin
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/${CURRENT_BRANCH})

if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
    echo -e "${RED}✗ ERROR: Local branch is not in sync with remote${NC}"
    echo "   Run: git push or git pull"
    ((ERRORS++))
else
    echo -e "${GREEN}✓${NC} Branch is in sync with remote"
fi

echo ""

# ============================================
# 2. Проверка собранных ассетов
# ============================================
echo -e "${BLUE}[2/10]${NC} Checking built assets..."

cd "${LOCAL_THEME_PATH}"

# Проверка, что CSS файлы существуют и свежие
CSS_FILES=(
    "assets/css/main.css"
    "assets/css/admin.css"
)

for css_file in "${CSS_FILES[@]}"; do
    if [ ! -f "$css_file" ]; then
        echo -e "${RED}✗ ERROR: Missing CSS file: ${css_file}${NC}"
        ((ERRORS++))
    else
        # Проверка, что CSS файл собран недавно (не старше исходников)
        SCSS_FILE="${css_file/.css/.scss}"
        SCSS_FILE="${SCSS_FILE/css\//scss\/}"
        
        if [ -f "$SCSS_FILE" ]; then
            if [ "$SCSS_FILE" -nt "$css_file" ]; then
                echo -e "${YELLOW}⚠️  WARNING: ${css_file} is older than source SCSS${NC}"
                echo "   Run: npm run build"
                ((WARNINGS++))
            else
                echo -e "${GREEN}✓${NC} ${css_file} is up to date"
            fi
        fi
    fi
done

# Проверка JS файлов
JS_FILES=(
    "assets/js/main.min.js"
    "assets/js/admin.min.js"
)

for js_file in "${JS_FILES[@]}"; do
    if [ ! -f "$js_file" ]; then
        echo -e "${RED}✗ ERROR: Missing JS file: ${js_file}${NC}"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓${NC} ${js_file} exists"
    fi
done

echo ""

# ============================================
# 3. Проверка package.json и lock файлов
# ============================================
echo -e "${BLUE}[3/10]${NC} Checking dependencies..."

if [ -f "package.json" ]; then
    if [ ! -f "package-lock.json" ]; then
        echo -e "${YELLOW}⚠️  WARNING: package-lock.json missing${NC}"
        ((WARNINGS++))
    else
        echo -e "${GREEN}✓${NC} package-lock.json exists"
    fi
fi

echo ""

# ============================================
# 4. Проверка PHP синтаксиса
# ============================================
echo -e "${BLUE}[4/10]${NC} Checking PHP syntax..."

PHP_ERROR=0
while IFS= read -r -d '' php_file; do
    if ! php -l "$php_file" > /dev/null 2>&1; then
        echo -e "${RED}✗ ERROR: Syntax error in ${php_file}${NC}"
        ((ERRORS++))
        PHP_ERROR=1
    fi
done < <(find . -name "*.php" -not -path "./node_modules/*" -not -path "./vendor/*" -print0)

if [ $PHP_ERROR -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No PHP syntax errors"
fi

echo ""

# ============================================
# 5. Проверка версии темы
# ============================================
echo -e "${BLUE}[5/10]${NC} Checking theme version..."

STYLE_CSS="style.css"
if [ -f "$STYLE_CSS" ]; then
    VERSION=$(grep "Version:" "$STYLE_CSS" | sed 's/.*Version: *//')
    
    if [ -z "$VERSION" ]; then
        echo -e "${YELLOW}⚠️  WARNING: Theme version not found in style.css${NC}"
        ((WARNINGS++))
    else
        echo -e "${GREEN}✓${NC} Theme version: ${VERSION}"
        
        # Проверка, что версия обновлена (не 1.0.0)
        if [ "$VERSION" == "1.0.0" ]; then
            echo -e "${YELLOW}⚠️  WARNING: Consider updating theme version${NC}"
            ((WARNINGS++))
        fi
    fi
fi

echo ""

# ============================================
# 6. Проверка миграций
# ============================================
echo -e "${BLUE}[6/10]${NC} Checking database migrations..."

MIGRATIONS_DIR="${LOCAL_PROJECT_ROOT}/wordpress/wp-content/migrations"
if [ -d "$MIGRATIONS_DIR" ]; then
    MIGRATION_COUNT=$(find "$MIGRATIONS_DIR" -name "*.sql" | wc -l | tr -d ' ')
    echo -e "${GREEN}✓${NC} Found ${MIGRATION_COUNT} migration(s)"
    
    if [ $MIGRATION_COUNT -gt 0 ]; then
        echo -e "${YELLOW}ℹ️  Migrations will be applied during deployment${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  WARNING: Migrations directory not found${NC}"
    ((WARNINGS++))
fi

echo ""

# ============================================
# 7. Проверка .gitignore
# ============================================
echo -e "${BLUE}[7/10]${NC} Checking .gitignore..."

cd "${LOCAL_PROJECT_ROOT}"

GITIGNORE_FILE=".gitignore"
if [ -f "$GITIGNORE_FILE" ]; then
    # Проверка, что собранные ассеты НЕ в .gitignore
    if grep -q "assets/css/\*.css" "$GITIGNORE_FILE" 2>/dev/null; then
        echo -e "${RED}✗ ERROR: Built CSS files are ignored in .gitignore${NC}"
        echo "   Remove 'assets/css/*.css' from .gitignore"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓${NC} Built CSS files are tracked"
    fi
    
    if grep -q "assets/js/\*.min.js" "$GITIGNORE_FILE" 2>/dev/null; then
        echo -e "${RED}✗ ERROR: Built JS files are ignored in .gitignore${NC}"
        echo "   Remove 'assets/js/*.min.js' from .gitignore"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓${NC} Built JS files are tracked"
    fi
fi

echo ""

# ============================================
# 8. Проверка доступности PROD сервера
# ============================================
echo -e "${BLUE}[8/10]${NC} Checking PROD server connectivity..."

if ssh -q -o BatchMode=yes -o ConnectTimeout=5 "${PROD_SSH_USER}@${PROD_SSH_HOST}" exit; then
    echo -e "${GREEN}✓${NC} PROD server is reachable"
else
    echo -e "${RED}✗ ERROR: Cannot connect to PROD server${NC}"
    echo "   Check SSH credentials and network connection"
    ((ERRORS++))
fi

echo ""

# ============================================
# 9. Проверка дискового пространства на сервере
# ============================================
echo -e "${BLUE}[9/10]${NC} Checking disk space on PROD server..."

DISK_USAGE=$(ssh "${PROD_SSH_USER}@${PROD_SSH_HOST}" "df -h ${PROD_WEBROOT} | tail -1 | awk '{print \$5}' | sed 's/%//'")

if [ "$DISK_USAGE" -gt 90 ]; then
    echo -e "${RED}✗ ERROR: Disk usage is ${DISK_USAGE}% (critical)${NC}"
    ((ERRORS++))
elif [ "$DISK_USAGE" -gt 80 ]; then
    echo -e "${YELLOW}⚠️  WARNING: Disk usage is ${DISK_USAGE}% (high)${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC} Disk usage: ${DISK_USAGE}%"
fi

echo ""

# ============================================
# 10. Проверка последнего бэкапа
# ============================================
echo -e "${BLUE}[10/10]${NC} Checking last backup..."

LAST_BACKUP=$(ssh "${PROD_SSH_USER}@${PROD_SSH_HOST}" "ls -t ${PROD_BACKUP_DIR}/backup-*.sql.gz 2>/dev/null | head -1" || echo "")

if [ -z "$LAST_BACKUP" ]; then
    echo -e "${YELLOW}⚠️  WARNING: No recent backups found${NC}"
    echo "   Backup will be created before deployment"
    ((WARNINGS++))
else
    BACKUP_NAME=$(basename "$LAST_BACKUP")
    echo -e "${GREEN}✓${NC} Last backup: ${BACKUP_NAME}"
fi

echo ""

# ============================================
# SUMMARY
# ============================================
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Checklist Summary                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}✗ FAILED: ${ERRORS} error(s) found${NC}"
    echo -e "${YELLOW}⚠️  ${WARNINGS} warning(s)${NC}"
    echo ""
    echo -e "${RED}Deployment is NOT recommended. Please fix errors first.${NC}"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${GREEN}✓ PASSED with warnings${NC}"
    echo -e "${YELLOW}⚠️  ${WARNINGS} warning(s)${NC}"
    echo ""
    echo -e "${YELLOW}Deployment can proceed, but review warnings.${NC}"
    exit 0
else
    echo -e "${GREEN}✓ ALL CHECKS PASSED${NC}"
    echo ""
    echo -e "${GREEN}Ready for deployment! 🚀${NC}"
    exit 0
fi
