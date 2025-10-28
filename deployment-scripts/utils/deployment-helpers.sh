#!/bin/bash
# 🛠️ Deployment Helper Functions
# Вспомогательные функции для деплоя

# ============================================
# Проверка, первый ли это деплой
# ============================================
is_first_deployment() {
    local SSH_USER=$1
    local SSH_HOST=$2
    local WEBROOT=$3
    
    # Проверяем наличие критичных файлов WordPress на сервере
    local CHECK_RESULT=$(ssh -q "${SSH_USER}@${SSH_HOST}" << ENDSSH
# Проверяем, существует ли директория
if [ ! -d "${WEBROOT}" ]; then
    echo "FIRST"
    exit 0
fi

# Проверяем наличие WordPress файлов
if [ ! -f "${WEBROOT}/wp-config.php" ] && [ ! -f "${WEBROOT}/wp-load.php" ]; then
    echo "FIRST"
    exit 0
fi

# Проверяем наличие .git (признак что деплой уже был)
if [ ! -d "${WEBROOT}/.git" ]; then
    echo "FIRST"
    exit 0
fi

# Проверяем наличие wp-content/themes
if [ ! -d "${WEBROOT}/wp-content/themes" ]; then
    echo "FIRST"
    exit 0
fi

# Если всё на месте - это не первый деплой
echo "NOT_FIRST"
ENDSSH
)
    
    if [ "$CHECK_RESULT" == "FIRST" ]; then
        return 0  # true - это первый деплой
    else
        return 1  # false - не первый деплой
    fi
}

# ============================================
# Получить информацию о текущем состоянии сервера
# ============================================
get_server_info() {
    local SSH_USER=$1
    local SSH_HOST=$2
    local WEBROOT=$3
    
    ssh -q "${SSH_USER}@${SSH_HOST}" << ENDSSH
echo "=== Server Information ==="
echo "Hostname: \$(hostname)"
echo "OS: \$(uname -s)"
echo ""

if [ -d "${WEBROOT}" ]; then
    echo "Webroot exists: YES"
    echo "Webroot path: ${WEBROOT}"
    
    cd "${WEBROOT}"
    
    if [ -d ".git" ]; then
        echo "Git initialized: YES"
        echo "Current branch: \$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
        echo "Current commit: \$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
    else
        echo "Git initialized: NO"
    fi
    
    if [ -f "wp-config.php" ]; then
        echo "WordPress installed: YES"
        
        # Пробуем получить версию WordPress
        if command -v wp &> /dev/null; then
            WP_VERSION=\$(wp core version 2>/dev/null || echo 'unknown')
            echo "WordPress version: \${WP_VERSION}"
        fi
    else
        echo "WordPress installed: NO"
    fi
    
    echo ""
    echo "Directory contents:"
    ls -lah | head -n 20
else
    echo "Webroot exists: NO"
fi
ENDSSH
}

# ============================================
# Проверка доступности rsync
# ============================================
check_rsync_available() {
    if ! command -v rsync &> /dev/null; then
        return 1  # rsync не найден
    fi
    return 0
}

# ============================================
# Проверка доступности WP-CLI на сервере
# ============================================
check_wpcli_available() {
    local SSH_USER=$1
    local SSH_HOST=$2
    
    local WPCLI_CHECK=$(ssh -q "${SSH_USER}@${SSH_HOST}" "command -v wp &> /dev/null && echo 'YES' || echo 'NO'")
    
    if [ "$WPCLI_CHECK" == "YES" ]; then
        return 0  # WP-CLI доступен
    else
        return 1  # WP-CLI не найден
    fi
}

# ============================================
# Получить размер директории на сервере
# ============================================
get_remote_directory_size() {
    local SSH_USER=$1
    local SSH_HOST=$2
    local DIR_PATH=$3
    
    ssh -q "${SSH_USER}@${SSH_HOST}" "du -sh ${DIR_PATH} 2>/dev/null | cut -f1"
}

# ============================================
# Проверка свободного места на сервере
# ============================================
check_disk_space() {
    local SSH_USER=$1
    local SSH_HOST=$2
    local REQUIRED_GB=$3  # Минимум ГБ свободного места
    
    local FREE_SPACE=$(ssh -q "${SSH_USER}@${SSH_HOST}" "df -BG . | tail -1 | awk '{print \$4}' | sed 's/G//'")
    
    if [ "$FREE_SPACE" -lt "$REQUIRED_GB" ]; then
        echo "WARNING: Low disk space. Available: ${FREE_SPACE}GB, Required: ${REQUIRED_GB}GB"
        return 1
    fi
    
    echo "Disk space OK: ${FREE_SPACE}GB available"
    return 0
}

# ============================================
# Создать маркер деплоя
# ============================================
create_deployment_marker() {
    local SSH_USER=$1
    local SSH_HOST=$2
    local WEBROOT=$3
    local DEPLOYMENT_TYPE=$4  # initial, regular, hotfix, rollback
    
    ssh -q "${SSH_USER}@${SSH_HOST}" << ENDSSH
mkdir -p ${WEBROOT}/.deployment-history

cat > ${WEBROOT}/.deployment-history/last-deployment.json << 'EOF'
{
    "type": "${DEPLOYMENT_TYPE}",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "date_human": "$(date)",
    "commit": "$(cd ${WEBROOT} 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo 'unknown')",
    "branch": "$(cd ${WEBROOT} 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
}
EOF

echo "Deployment marker created"
ENDSSH
}

# ============================================
# Получить информацию о последнем деплое
# ============================================
get_last_deployment_info() {
    local SSH_USER=$1
    local SSH_HOST=$2
    local WEBROOT=$3
    
    ssh -q "${SSH_USER}@${SSH_HOST}" << ENDSSH
if [ -f "${WEBROOT}/.deployment-history/last-deployment.json" ]; then
    cat ${WEBROOT}/.deployment-history/last-deployment.json
else
    echo '{"type": "unknown", "timestamp": "never"}'
fi
ENDSSH
}

# ============================================
# Форматированный вывод статуса деплоя
# ============================================
print_deployment_status() {
    local STATUS=$1
    local MESSAGE=$2
    
    case $STATUS in
        "success")
            echo -e "${GREEN}✓${NC} ${MESSAGE}"
            ;;
        "error")
            echo -e "${RED}✗${NC} ${MESSAGE}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️${NC} ${MESSAGE}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️${NC} ${MESSAGE}"
            ;;
        *)
            echo "$MESSAGE"
            ;;
    esac
}

# ============================================
# Проверка синтаксиса PHP файла на сервере
# ============================================
check_php_syntax_remote() {
    local SSH_USER=$1
    local SSH_HOST=$2
    local FILE_PATH=$3
    
    local SYNTAX_CHECK=$(ssh -q "${SSH_USER}@${SSH_HOST}" "php -l ${FILE_PATH} 2>&1")
    
    if [[ "$SYNTAX_CHECK" == *"No syntax errors"* ]]; then
        return 0
    else
        echo "$SYNTAX_CHECK"
        return 1
    fi
}

# ============================================
# Экспорт функций для использования в других скриптах
# ============================================
export -f is_first_deployment
export -f get_server_info
export -f check_rsync_available
export -f check_wpcli_available
export -f get_remote_directory_size
export -f check_disk_space
export -f create_deployment_marker
export -f get_last_deployment_info
export -f print_deployment_status
export -f check_php_syntax_remote
