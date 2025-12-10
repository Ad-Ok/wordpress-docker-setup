#!/bin/bash
# ============================================
# Общие утилиты для Polylang тестов
# ============================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ============================================
# Утилиты
# ============================================

# Функция для curl с auth (для LOCAL и DEV) и -k для самоподписанных сертификатов
curl_with_auth() {
    local extra_opts=""
    
    # Basic Auth для LOCAL и DEV
    if [ "$ENVIRONMENT" == "dev" ] || [ "$ENVIRONMENT" == "local" ]; then
        extra_opts="-u test:test"
    fi
    
    # Игнорировать SSL ошибки для LOCAL (самоподписанный сертификат)
    if [ "$ENVIRONMENT" == "local" ]; then
        extra_opts="$extra_opts -k"
    fi
    
    curl $extra_opts "$@"
}

# Выполнение SQL запроса
run_sql() {
    local query="$1"
    
    if [ "$IS_LOCAL" = true ]; then
        # Для LOCAL - через docker
        docker compose -f "${LOCAL_PROJECT_ROOT}/docker-compose.yml" exec -T mysql \
            mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -e "$query" 2>/dev/null
    else
        # Для DEV/PROD - через SSH
        ssh -o ConnectTimeout=10 -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" \
            "mysql -u'$DB_USER' -p'$DB_PASS' '$DB_NAME' -N -e \"$query\"" 2>/dev/null
    fi
}

# Выполнение WP-CLI команды
run_wp_cli() {
    local cmd="$1"
    
    if [ "$IS_LOCAL" = true ]; then
        # Для LOCAL - через docker
        docker compose -f "${LOCAL_PROJECT_ROOT}/docker-compose.yml" exec -T php \
            wp $cmd --allow-root 2>/dev/null
    else
        # Для DEV/PROD - через SSH
        ssh -o ConnectTimeout=10 -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" \
            "cd '$WP_PATH' && wp $cmd" 2>/dev/null
    fi
}

# Вывод результата теста
test_pass() {
    local msg="$1"
    echo -e "${GREEN}✓${NC} $msg"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

test_fail() {
    local msg="$1"
    echo -e "${RED}✗${NC} $msg"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

test_skip() {
    local msg="$1"
    echo -e "${YELLOW}○${NC} $msg (пропущен)"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
}

test_info() {
    local msg="$1"
    echo -e "${BLUE}ℹ${NC} $msg"
}

phase_header() {
    local phase_num="$1"
    local phase_name="$2"
    echo ""
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  ФАЗА $phase_num: $phase_name${NC}"
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════${NC}"
    echo ""
}
