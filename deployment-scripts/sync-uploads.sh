#!/bin/bash
# 📤 Upload Synchronization Script
# Безопасная синхронизация wp-content/uploads на сервер
# Использует rsync для надёжной передачи больших объёмов данных
#
# Особенности:
# - Инкрементальная синхронизация (передаются только новые/изменённые файлы)
# - Поддержка resume при обрыве соединения
# - Фильтрация системных/временных файлов
# - Защита от удаления файлов на сервере
# - Отчёты о прогрессе
# - Dry-run режим для проверки
#
# Использование:
#   ./sync-uploads.sh [prod|dev] [--dry-run] [--delete]
#
# Опции:
#   --dry-run   Показать что будет синхронизировано без реальной передачи
#   --delete    Удалить файлы на сервере, которых нет локально (осторожно!)

set -e

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Определяем среду (prod или dev)
ENVIRONMENT=""
DRY_RUN=false
DELETE_MODE=false
LONG_NAME_FILES=""
LONG_COUNT=0

# Парсим аргументы
for arg in "$@"; do
    case $arg in
        prod|dev)
            ENVIRONMENT="$arg"
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --delete)
            DELETE_MODE=true
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [prod|dev] [--dry-run] [--delete]"
            exit 1
            ;;
    esac
done

# Если среда не указана, спрашиваем
if [ -z "$ENVIRONMENT" ]; then
    echo -e "${YELLOW}Select environment:${NC}"
    echo "  1) dev"
    echo "  2) prod"
    read -p "Enter choice (1-2): " -r ENV_CHOICE
    
    case $ENV_CHOICE in
        1) ENVIRONMENT="dev" ;;
        2) ENVIRONMENT="prod" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
fi

# Устанавливаем переменные в зависимости от среды
if [ "$ENVIRONMENT" == "prod" ]; then
    SSH_USER="$PROD_SSH_USER"
    SSH_HOST="$PROD_SSH_HOST"
    WEBROOT="$PROD_WEBROOT"
elif [ "$ENVIRONMENT" == "dev" ]; then
    SSH_USER="$DEV_SSH_USER"
    SSH_HOST="$DEV_SSH_HOST"
    WEBROOT="$DEV_WEBROOT"
else
    echo -e "${RED}Invalid environment: $ENVIRONMENT${NC}"
    exit 1
fi

# Uppercase для вывода
ENV_UPPER=$(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')

# ============================================
# HEADER
# ============================================
echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         UPLOADS SYNC - ${ENV_UPPER}                       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}🔍 DRY RUN MODE - No files will be transferred${NC}"
    echo ""
fi

# ============================================
# STEP 1: Проверка локального окружения
# ============================================
echo -e "${BLUE}═══ STEP 1/4: Checking Local Environment ═══${NC}"
echo ""

UPLOADS_DIR_LOCAL="${LOCAL_PROJECT_ROOT}/wordpress/wp-content/uploads"

if [ ! -d "${UPLOADS_DIR_LOCAL}" ]; then
    echo -e "${RED}✗ Local uploads directory not found: ${UPLOADS_DIR_LOCAL}${NC}"
    exit 1
fi

# Проверяем размер и количество файлов
UPLOADS_SIZE=$(du -sh "${UPLOADS_DIR_LOCAL}" | cut -f1)
FILE_COUNT=$(find "${UPLOADS_DIR_LOCAL}" -type f | wc -l | tr -d ' ')

echo "Local uploads directory:"
echo "  Path: ${UPLOADS_DIR_LOCAL}"
echo "  Size: ${UPLOADS_SIZE}"
echo "  Files: ${FILE_COUNT}"
echo ""

# Проверяем большие файлы
LARGE_FILES=$(find "${UPLOADS_DIR_LOCAL}" -type f -size +50M | wc -l | tr -d ' ')
if [ ${LARGE_FILES} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found ${LARGE_FILES} files larger than 50MB${NC}"
    echo "Large files may take time to upload:"
    find "${UPLOADS_DIR_LOCAL}" -type f -size +50M -exec du -h {} \; | sort -rh | head -5 | while read size path; do
        echo "  ${size} - $(basename "$path")"
    done
    echo ""
fi

# Проверяем проблемные имена файлов
echo "Checking for problematic filenames..."
PROBLEM_COUNT=0

# Файлы с пробелами
SPACE_FILES=$(find "${UPLOADS_DIR_LOCAL}" -name "* *" -type f | wc -l | tr -d ' ')
if [ ${SPACE_FILES} -gt 0 ]; then
    echo -e "${YELLOW}  ⚠ ${SPACE_FILES} files with spaces in names${NC}"
    PROBLEM_COUNT=$((PROBLEM_COUNT + SPACE_FILES))
fi

# Файлы с кириллицей/спецсимволами
NON_ASCII=$(find "${UPLOADS_DIR_LOCAL}" -type f -exec sh -c 'basename "$1" | LC_ALL=C grep -q "[^[:print:]]"' _ {} \; -print | wc -l | tr -d ' ')
if [ ${NON_ASCII} -gt 0 ]; then
    echo -e "${YELLOW}  ⚠ ${NON_ASCII} files with non-ASCII characters (cyrillic, etc)${NC}"
    PROBLEM_COUNT=$((PROBLEM_COUNT + NON_ASCII))
fi

# Файлы с очень длинными именами (>200 БАЙТ в basename)
# NAME_MAX на сервере = 255 байт, используем 200 байт как безопасный порог
# Кириллица занимает ~2 байта на символ в UTF-8
echo "  Checking for files with extremely long names..."
LONG_NAME_FILES=$(mktemp)

# Поиск файлов с длинными именами (проверяем БАЙТЫ, не символы!)
UPLOADS_DIR_LOCAL="${UPLOADS_DIR_LOCAL}" python3 << 'PYSCRIPT' > "${LONG_NAME_FILES}"
import os
import sys

uploads_dir = os.environ.get('UPLOADS_DIR_LOCAL')
max_bytes = 200

for root, dirs, files in os.walk(uploads_dir):
    for fname in files:
        byte_len = len(fname.encode('utf-8'))
        if byte_len > max_bytes:
            full_path = os.path.join(root, fname)
            print(full_path)
PYSCRIPT

# Считаем количество найденных файлов
LONG_COUNT=$(cat "${LONG_NAME_FILES}" | wc -l | tr -d ' ')
LONG_COUNT=${LONG_COUNT:-0}

if [ ${LONG_COUNT} -gt 0 ]; then
    echo -e "${YELLOW}  ⚠ ${LONG_COUNT} files with extremely long names (>200 bytes)${NC}"
    echo -e "${YELLOW}    These files will be SKIPPED during sync (filesystem limitation)${NC}"
    PROBLEM_COUNT=$((PROBLEM_COUNT + LONG_COUNT))
    
    if [ ${LONG_COUNT} -le 20 ]; then
        echo "    Files that will be skipped:"
        head -10 "${LONG_NAME_FILES}" | while IFS= read -r file; do
            filename=$(basename "$file")
            byte_len=$(printf "%s" "$filename" | wc -c | tr -d ' ')
            # Показываем только первые 80 символов имени
            echo "      - ${filename:0:80}... [${byte_len} bytes]"
        done
    else
        echo "    Showing first 10 of ${LONG_COUNT} files:"
        head -10 "${LONG_NAME_FILES}" | while IFS= read -r file; do
            filename=$(basename "$file")
            byte_len=$(printf "%s" "$filename" | wc -c | tr -d ' ')
            echo "      - ${filename:0:80}... [${byte_len} bytes]"
        done
    fi
fi

if [ ${PROBLEM_COUNT} -gt 0 ]; then
    echo -e "${YELLOW}  Note: Files with long names will be skipped. You can re-upload them via WordPress admin.${NC}"
fi

echo -e "${GREEN}✓${NC} Local environment check passed"
echo ""

# ============================================
# STEP 2: Проверка SSH соединения
# ============================================
echo -e "${BLUE}═══ STEP 2/4: Testing SSH Connection ═══${NC}"
echo ""

if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "${SSH_USER}@${SSH_HOST}" exit; then
    echo -e "${RED}✗ Cannot connect to ${SSH_USER}@${SSH_HOST}${NC}"
    echo ""
    echo "Please check:"
    echo "  • SSH keys are configured"
    echo "  • Server is accessible"
    echo "  • Credentials in config.sh are correct"
    exit 1
fi

echo -e "${GREEN}✓${NC} SSH connection successful"
echo ""

# ============================================
# STEP 3: Подготовка директории на сервере
# ============================================
echo -e "${BLUE}═══ STEP 3/4: Preparing Remote Directory ═══${NC}"
echo ""

# Создаём директорию на сервере если её нет
ssh "${SSH_USER}@${SSH_HOST}" "mkdir -p '${WEBROOT}/wp-content/uploads'"

# Проверяем текущее состояние на сервере
echo "Checking remote uploads directory..."
REMOTE_INFO=$(ssh "${SSH_USER}@${SSH_HOST}" bash << ENDSSH
if [ -d "${WEBROOT}/wp-content/uploads" ]; then
    SIZE=\$(du -sh "${WEBROOT}/wp-content/uploads" 2>/dev/null | cut -f1)
    COUNT=\$(find "${WEBROOT}/wp-content/uploads" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "EXISTS|\${SIZE}|\${COUNT}"
else
    echo "EMPTY|0|0"
fi
ENDSSH
)

REMOTE_STATUS=$(echo "$REMOTE_INFO" | cut -d'|' -f1)
REMOTE_SIZE=$(echo "$REMOTE_INFO" | cut -d'|' -f2)
REMOTE_COUNT=$(echo "$REMOTE_INFO" | cut -d'|' -f3)

if [ "$REMOTE_STATUS" == "EXISTS" ]; then
    echo "Remote uploads directory:"
    echo "  Size: ${REMOTE_SIZE}"
    echo "  Files: ${REMOTE_COUNT}"
else
    echo "Remote uploads directory is empty (will be created)"
fi

echo -e "${GREEN}✓${NC} Remote directory ready"
echo ""

# ============================================
# STEP 4: Синхронизация с rsync
# ============================================
echo -e "${BLUE}═══ STEP 4/4: Synchronizing Uploads ═══${NC}"
echo ""

# Создаём временный exclude файл
EXCLUDE_FILE=$(mktemp /tmp/rsync_exclude_XXXXXX)
cat > "${EXCLUDE_FILE}" << 'EOF'
# macOS системные файлы
.DS_Store
._*
__MACOSX/
.AppleDouble
.LSOverride
.Spotlight-V100
.Trashes

# Windows системные файлы
Thumbs.db
desktop.ini
ehthumbs.db

# Временные файлы редакторов
*~
*.swp
*.swo
*.tmp

# VCS
.git/
.gitignore

# Временные папки
.cache/
.temp/
EOF

# Добавляем файлы с длинными именами в exclude (если есть)
if [ -f "${LONG_NAME_FILES}" ] && [ ${LONG_COUNT} -gt 0 ]; then
    echo "Adding ${LONG_COUNT} long-named files to exclude list..."
    
    # Добавляем относительные пути к exclude файлу
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            # Получаем относительный путь от UPLOADS_DIR_LOCAL
            rel_path="${file#${UPLOADS_DIR_LOCAL}/}"
            # Добавляем в exclude файл с экранированием специальных символов
            echo "$rel_path" >> "${EXCLUDE_FILE}"
        fi
    done < "${LONG_NAME_FILES}"
    
    echo "  Long-named files will be excluded from sync"
fi

# Формируем команду rsync
RSYNC_OPTS=(
    -avz                          # archive, verbose, compress
    --progress                    # показываем прогресс
    --partial                     # разрешаем resume прерванных передач
    --partial-dir=.rsync-partial  # папка для временных файлов
    --exclude-from="${EXCLUDE_FILE}"
    --ignore-errors               # продолжаем при ошибках с отдельными файлами
    --max-delete=100              # защита от случайного массового удаления
    --timeout=300                 # таймаут на операции ввода-вывода (5 мин)
    --contimeout=60               # таймаут на подключение (60 сек)
    -e "ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=10"  # keep-alive
)

# Добавляем опции в зависимости от режима
if [ "$DRY_RUN" = true ]; then
    RSYNC_OPTS+=(--dry-run)
    RSYNC_OPTS+=(--itemize-changes)
fi

if [ "$DELETE_MODE" = true ]; then
    echo -e "${RED}⚠️  DELETE MODE ENABLED${NC}"
    echo "Files on server that don't exist locally will be DELETED!"
    echo ""
    
    if [ "$DRY_RUN" != true ]; then
        read -p "Are you sure you want to continue? (type 'yes' to confirm): " -r CONFIRM
        if [[ ! $CONFIRM =~ ^[Yy][Ee][Ss]$ ]]; then
            echo "Sync cancelled"
            rm -f "${EXCLUDE_FILE}"
            exit 0
        fi
    fi
    
    RSYNC_OPTS+=(--delete)
    RSYNC_OPTS+=(--delete-excluded)
fi

# Информация о синхронизации
echo "Sync configuration:"
echo "  Source: ${UPLOADS_DIR_LOCAL}/"
echo "  Target: ${SSH_USER}@${SSH_HOST}:${WEBROOT}/wp-content/uploads/"
echo "  Mode: $([ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "LIVE SYNC")"
echo "  Delete: $([ "$DELETE_MODE" = true ] && echo "YES (files on server will be removed if not in source)" || echo "NO (files on server will be preserved)")"
echo ""

if [ "$DRY_RUN" != true ]; then
    echo "Starting synchronization..."
    echo "This may take several minutes depending on the size and number of files."
    echo ""
fi

# Запускаем rsync
START_TIME=$(date +%s)
RSYNC_EXIT_CODE=0

rsync "${RSYNC_OPTS[@]}" \
    "${UPLOADS_DIR_LOCAL}/" \
    "${SSH_USER}@${SSH_HOST}:${WEBROOT}/wp-content/uploads/" || RSYNC_EXIT_CODE=$?

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Коды выхода rsync:
# 0 = успех
# 23 = частичная передача из-за ошибок (например, файлы со слишком длинными именами)
# 24 = частичная передача из-за пропавших исходных файлов

if [ $RSYNC_EXIT_CODE -eq 0 ] || [ $RSYNC_EXIT_CODE -eq 23 ] || [ $RSYNC_EXIT_CODE -eq 24 ]; then
    echo ""
    if [ "$DRY_RUN" = true ]; then
        echo -e "${GREEN}✓${NC} Dry run completed in ${DURATION} seconds"
        
        if [ $RSYNC_EXIT_CODE -eq 23 ]; then
            echo -e "${YELLOW}  Note: Some files were skipped (likely due to long filenames)${NC}"
        fi
        
        echo ""
        echo "No files were actually transferred."
        echo "Run without --dry-run to perform the actual sync."
    else
        echo -e "${GREEN}✓${NC} Uploads synchronized in ${DURATION} seconds"
        
        if [ $RSYNC_EXIT_CODE -eq 23 ]; then
            echo -e "${YELLOW}  Note: Some files were skipped (likely due to long filenames)${NC}"
        fi
        
        echo ""
        
        # Устанавливаем правильные права доступа на сервере
        echo "Setting file permissions..."
        ssh "${SSH_USER}@${SSH_HOST}" "find '${WEBROOT}/wp-content/uploads' -type d -exec chmod 755 {} \; && find '${WEBROOT}/wp-content/uploads' -type f -exec chmod 644 {} \;" 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Permissions set"
        echo ""
        
        echo "All uploads have been synced to the server."
    fi
else
    echo ""
    echo -e "${RED}✗ Sync failed with exit code ${RSYNC_EXIT_CODE}${NC}"
    rm -f "${EXCLUDE_FILE}"
    rm -f "${LONG_NAME_FILES}"
    exit 1
fi

# Очистка временных файлов
rm -f "${EXCLUDE_FILE}"
rm -f "${LONG_NAME_FILES}"

# ============================================
# SUMMARY
# ============================================
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓${NC} Sync completed"
echo ""

# Предупреждение о пропущенных файлах с длинными именами
if [ ${LONG_COUNT:-0} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  NOTE: ${LONG_COUNT} files were skipped due to long filenames${NC}"
    echo ""
    echo "These files exceed filesystem name length limits (>200 bytes)."
    echo "Server NAME_MAX = 255 bytes. With UTF-8 cyrillic (~2 bytes/char),"
    echo "safe limit is ~100-120 characters for Russian filenames."
    echo ""
    echo "To fix this:"
    echo "  1. Re-upload the original images via WordPress admin"
    echo "  2. Or use a plugin to regenerate thumbnails (Regenerate Thumbnails)"
    echo "  3. WordPress will create new versions with shorter names"
    echo ""
fi

if [ "$DRY_RUN" != true ]; then
    echo "Next steps:"
    echo "  • Verify uploads on site: ${SITE_URL}"
    echo "  • Check image functionality"
    echo "  • Test media library in WordPress admin"
    echo ""
    echo "To sync again (only new/changed files will be transferred):"
    echo "  ./sync-uploads.sh ${ENVIRONMENT}"
fi

echo ""
