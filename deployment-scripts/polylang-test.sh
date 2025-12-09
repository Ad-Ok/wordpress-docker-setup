#!/bin/bash
# 🧪 Polylang Integration Tests
# Тестирование настроек Polylang по фазам плана внедрения
# 
# Использование:
#   ./polylang-test.sh --env=local --phase=1
#   ./polylang-test.sh --env=dev --phase=3 --force-sql
#   ./polylang-test.sh --env=prod --phase=8
#
# Параметры:
#   --env=local|dev|prod    Окружение для тестирования (обязательный)
#   --phase=1-9             До какой фазы включительно тестировать (по умолчанию: 1)
#   --force-sql             Пропустить WP-CLI и использовать только SQL
#   --help                  Показать справку

set -eo pipefail

# ============================================
# Загрузка конфигурации
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ============================================
# Переменные
# ============================================
ENVIRONMENT=""
PHASE=1
FORCE_SQL=false
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
WP_CLI_AVAILABLE=false
SSH_AVAILABLE=false

# ============================================
# Парсинг аргументов
# ============================================
show_help() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         Polylang Integration Tests                        ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Использование:"
    echo "  ./polylang-test.sh --env=<environment> [--phase=<n>] [--force-sql]"
    echo ""
    echo "Параметры:"
    echo "  --env=local|dev|prod    Окружение для тестирования (обязательный)"
    echo "  --phase=1-9             До какой фазы включительно тестировать (по умолчанию: 1)"
    echo "  --force-sql             Пропустить WP-CLI и использовать только SQL"
    echo "  --help                  Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  ./polylang-test.sh --env=local --phase=1"
    echo "  ./polylang-test.sh --env=dev --phase=3 --force-sql"
    echo "  ./polylang-test.sh --env=prod --phase=8"
    echo ""
    echo "Фазы:"
    echo "  1 - Установка и настройка Polylang"
    echo "  2 - SQL миграции (меню и строки)"
    echo "  3 - Переводы темы"
    echo "  4 - Кастомные плагины"
    echo "  5 - Демо-контент"
    echo "  6 - SEO оптимизация"
    echo "  7 - Миграция на DEV"
    echo "  8 - Деплой на PROD"
    echo "  9 - Документация"
    exit 0
}

for arg in "$@"; do
    case $arg in
        --env=*)
            ENVIRONMENT="${arg#*=}"
            ;;
        --phase=*)
            PHASE="${arg#*=}"
            ;;
        --force-sql)
            FORCE_SQL=true
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Неизвестный параметр: $arg${NC}"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
done

# Проверка обязательных параметров
if [ -z "$ENVIRONMENT" ]; then
    echo -e "${RED}Ошибка: не указано окружение (--env=local|dev|prod)${NC}"
    echo "Используйте --help для справки"
    exit 1
fi

# Проверка допустимых значений
if [[ ! "$ENVIRONMENT" =~ ^(local|dev|prod)$ ]]; then
    echo -e "${RED}Ошибка: окружение должно быть local, dev или prod${NC}"
    exit 1
fi

if [[ ! "$PHASE" =~ ^[1-9]$ ]]; then
    echo -e "${RED}Ошибка: фаза должна быть от 1 до 9${NC}"
    exit 1
fi

# ============================================
# Настройка переменных окружения
# ============================================
setup_environment() {
    case "$ENVIRONMENT" in
        local)
            SITE_URL="$LOCAL_SITE_URL"
            DB_NAME="$LOCAL_DB_NAME"
            DB_USER="$LOCAL_DB_USER"
            DB_PASS="$LOCAL_DB_PASS"
            DB_HOST="$LOCAL_DB_HOST"
            DB_PORT="$LOCAL_DB_PORT"
            DB_CONTAINER="$LOCAL_DB_CONTAINER"
            WP_PATH="$LOCAL_WP_PATH"
            IS_LOCAL=true
            ;;
        dev)
            SITE_URL="$DEV_SITE_URL"
            DB_NAME="$DEV_DB_NAME"
            DB_USER="$DEV_DB_USER"
            DB_PASS="$DEV_DB_PASS"
            DB_HOST="$DEV_DB_HOST"
            SSH_USER="$DEV_SSH_USER"
            SSH_HOST="$DEV_SSH_HOST"
            SSH_PORT="$DEV_SSH_PORT"
            WP_PATH="$DEV_WP_PATH"
            IS_LOCAL=false
            ;;
        prod)
            SITE_URL="$PROD_SITE_URL"
            DB_NAME="$PROD_DB_NAME"
            DB_USER="$PROD_DB_USER"
            DB_PASS="$PROD_DB_PASS"
            DB_HOST="$PROD_DB_HOST"
            SSH_USER="$PROD_SSH_USER"
            SSH_HOST="$PROD_SSH_HOST"
            SSH_PORT="$PROD_SSH_PORT"
            WP_PATH="$PROD_WP_PATH"
            IS_LOCAL=false
            ;;
    esac
}

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

# ============================================
# ФАЗА 0: Предварительные проверки
# ============================================
phase_0_checks() {
    phase_header "0" "Предварительные проверки"
    
    # 0.1 Проверка SSH соединения (для dev/prod)
    if [ "$IS_LOCAL" = false ]; then
        echo -e "${BLUE}[0.1]${NC} Проверка SSH соединения..."
        
        if ssh -o BatchMode=yes -o ConnectTimeout=10 -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" "echo 'ok'" > /dev/null 2>&1; then
            test_pass "SSH соединение с ${SSH_HOST} работает"
            SSH_AVAILABLE=true
        else
            test_fail "SSH соединение с ${SSH_HOST} не работает"
            echo -e "${RED}   Запустите: ./test-ssh-connection.sh для диагностики${NC}"
            return 1
        fi
    else
        echo -e "${BLUE}[0.1]${NC} Проверка Docker контейнеров..."
        
        if docker compose -f "${LOCAL_PROJECT_ROOT}/docker-compose.yml" ps --format "{{.Name}}" | grep -q "wordpress_php"; then
            test_pass "Docker контейнеры запущены"
        else
            test_fail "Docker контейнеры не запущены"
            echo -e "${RED}   Запустите: cd www && docker compose up -d${NC}"
            return 1
        fi
    fi
    
    # 0.2 Проверка WP-CLI
    if [ "$FORCE_SQL" = false ]; then
        echo -e "${BLUE}[0.2]${NC} Проверка доступности WP-CLI..."
        
        if run_wp_cli "--version" > /dev/null 2>&1; then
            test_pass "WP-CLI доступен"
            WP_CLI_AVAILABLE=true
        else
            test_info "WP-CLI недоступен, будет использоваться SQL"
            WP_CLI_AVAILABLE=false
        fi
    else
        echo -e "${BLUE}[0.2]${NC} WP-CLI пропущен (--force-sql)"
        WP_CLI_AVAILABLE=false
    fi
    
    # 0.3 Проверка доступности БД
    echo -e "${BLUE}[0.3]${NC} Проверка доступности базы данных..."
    
    if run_sql "SELECT 1" > /dev/null 2>&1; then
        test_pass "База данных доступна"
    else
        test_fail "База данных недоступна"
        return 1
    fi
    
    # 0.4 Проверка доступности сайта
    echo -e "${BLUE}[0.4]${NC} Проверка доступности сайта..."
    
    # Следуем редиректам (-L) чтобы получить финальный код
    HTTP_CODE=$(curl_with_auth -s -o /dev/null -w "%{http_code}" -L --max-time 10 "${SITE_URL}/" 2>/dev/null || echo "000")
    
    if [[ "$HTTP_CODE" =~ ^(200|301|302)$ ]]; then
        test_pass "Сайт доступен (${SITE_URL}, HTTP $HTTP_CODE)"
    else
        test_fail "Сайт недоступен (HTTP $HTTP_CODE)"
        return 1
    fi
    
    echo ""
    test_info "Режим тестирования: $([ "$WP_CLI_AVAILABLE" = true ] && echo 'WP-CLI + SQL' || echo 'Только SQL')"
}

# ============================================
# ФАЗА 1: Установка и настройка Polylang
# ============================================
phase_1_tests() {
    phase_header "1" "Установка и настройка Polylang"
    
    local test_num=0
    
    # 1.1 Проверка что Polylang установлен и активен
    test_num=$((test_num + 1))
    echo -e "${BLUE}[1.$test_num]${NC} Polylang установлен и активен..."
    
    if [ "$WP_CLI_AVAILABLE" = true ]; then
        if run_wp_cli "plugin list --status=active --format=csv" 2>/dev/null | grep -q "polylang"; then
            POLYLANG_VERSION=$(run_wp_cli "plugin get polylang --field=version" 2>/dev/null || echo "unknown")
            test_pass "Polylang активен (v${POLYLANG_VERSION})"
        else
            test_fail "Polylang не активен"
        fi
    else
        POLYLANG_CHECK=$(run_sql "SELECT option_value FROM wp_options WHERE option_name = 'active_plugins'" 2>/dev/null)
        if echo "$POLYLANG_CHECK" | grep -q "polylang"; then
            test_pass "Polylang активен (SQL)"
        else
            test_fail "Polylang не активен (SQL)"
        fi
    fi
    
    # 1.2 Проверка языков созданы
    test_num=$((test_num + 1))
    echo -e "${BLUE}[1.$test_num]${NC} Языки созданы (ru, en)..."
    
    LANGUAGES=$(run_sql "SELECT t.slug FROM wp_terms t JOIN wp_term_taxonomy tt ON t.term_id = tt.term_id WHERE tt.taxonomy = 'language' ORDER BY t.slug")
    
    if echo "$LANGUAGES" | grep -q "ru" && echo "$LANGUAGES" | grep -q "en"; then
        test_pass "Языки ru и en созданы"
    else
        test_fail "Языки не созданы (найдено: $LANGUAGES)"
    fi
    
    # 1.3 Проверка дефолтного языка
    test_num=$((test_num + 1))
    echo -e "${BLUE}[1.$test_num]${NC} Дефолтный язык = ru..."
    
    if [ "$WP_CLI_AVAILABLE" = true ]; then
        DEFAULT_LANG=$(run_wp_cli "option get polylang --format=json" 2>/dev/null | grep -o '"default_lang"[^,]*' | cut -d'"' -f4)
    else
        POLYLANG_OPT=$(run_sql "SELECT option_value FROM wp_options WHERE option_name = 'polylang'")
        if echo "$POLYLANG_OPT" | grep -q '"default_lang";s:2:"ru"'; then
            DEFAULT_LANG="ru"
        else
            DEFAULT_LANG=$(echo "$POLYLANG_OPT" | grep -o 'default_lang[^;]*' | head -1)
        fi
    fi
    
    if [ "$DEFAULT_LANG" == "ru" ]; then
        test_pass "Дефолтный язык = ru"
    else
        test_fail "Дефолтный язык = $DEFAULT_LANG (ожидалось: ru)"
    fi
    
    # 1.4 Проверка hide_default = true
    test_num=$((test_num + 1))
    echo -e "${BLUE}[1.$test_num]${NC} hide_default = true..."
    
    POLYLANG_OPT=$(run_sql "SELECT option_value FROM wp_options WHERE option_name = 'polylang'")
    
    if echo "$POLYLANG_OPT" | grep -q '"hide_default";b:1'; then
        test_pass "hide_default = true"
    else
        test_fail "hide_default != true"
    fi
    
    # 1.5 Проверка rewrite = true
    test_num=$((test_num + 1))
    echo -e "${BLUE}[1.$test_num]${NC} rewrite = true..."
    
    if echo "$POLYLANG_OPT" | grep -q '"rewrite";b:1'; then
        test_pass "rewrite = true"
    else
        test_fail "rewrite != true"
    fi
    
    # 1.6 Проверка CPT включены
    test_num=$((test_num + 1))
    echo -e "${BLUE}[1.$test_num]${NC} CPT включены для перевода..."
    
    # Ожидаемые CPT: artist, collection, events, photo, vistavki
    EXPECTED_CPT=("artist" "collection" "events" "photo" "vistavki")
    MISSING_CPT=()
    
    for cpt in "${EXPECTED_CPT[@]}"; do
        if ! echo "$POLYLANG_OPT" | grep -q "\"$cpt\""; then
            MISSING_CPT+=("$cpt")
        fi
    done
    
    if [ ${#MISSING_CPT[@]} -eq 0 ]; then
        test_pass "Все CPT включены: ${EXPECTED_CPT[*]}"
    else
        test_fail "Отсутствуют CPT: ${MISSING_CPT[*]}"
    fi
    
    # 1.7 Проверка URL главной страницы RU
    test_num=$((test_num + 1))
    echo -e "${BLUE}[1.$test_num]${NC} Главная RU доступна (/)..."
    
    HTTP_CODE=$(curl_with_auth -s -o /dev/null -w "%{http_code}" --max-time 10 "${SITE_URL}/" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" == "200" ]; then
        test_pass "/ → HTTP 200"
    else
        test_fail "/ → HTTP $HTTP_CODE"
    fi
    
    # 1.8 Проверка URL главной страницы EN
    test_num=$((test_num + 1))
    echo -e "${BLUE}[1.$test_num]${NC} Главная EN доступна (/en/)..."
    
    HTTP_CODE=$(curl_with_auth -s -o /dev/null -w "%{http_code}" --max-time 10 "${SITE_URL}/en/" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" == "200" ]; then
        test_pass "/en/ → HTTP 200"
    else
        test_fail "/en/ → HTTP $HTTP_CODE"
    fi
    
    # 1.9 Проверка HTML lang атрибута
    test_num=$((test_num + 1))
    echo -e "${BLUE}[1.$test_num]${NC} HTML lang атрибут корректен..."
    
    HTML_LANG_RU=$(curl_with_auth -s --max-time 10 "${SITE_URL}/" 2>/dev/null | grep -o '<html[^>]*lang="[^"]*"' | head -1 || echo "")
    HTML_LANG_EN=$(curl_with_auth -s --max-time 10 "${SITE_URL}/en/" 2>/dev/null | grep -o '<html[^>]*lang="[^"]*"' | head -1 || echo "")
    
    if echo "$HTML_LANG_RU" | grep -qi "ru" && echo "$HTML_LANG_EN" | grep -qi "en"; then
        test_pass "HTML lang: RU=ru, EN=en"
    else
        test_fail "HTML lang некорректен (RU: $HTML_LANG_RU, EN: $HTML_LANG_EN)"
    fi
}

# ============================================
# ФАЗА 2-9: Заглушки
# ============================================
phase_2_tests() {
    phase_header "2" "SQL миграции (меню и строки)"
    test_skip "Тесты Фазы 2 еще не реализованы"
}

phase_3_tests() {
    phase_header "3" "Переводы темы"
    test_skip "Тесты Фазы 3 еще не реализованы"
}

phase_4_tests() {
    phase_header "4" "Кастомные плагины"
    test_skip "Тесты Фазы 4 еще не реализованы"
}

phase_5_tests() {
    phase_header "5" "Демо-контент"
    test_skip "Тесты Фазы 5 еще не реализованы"
}

phase_6_tests() {
    phase_header "6" "SEO оптимизация"
    test_skip "Тесты Фазы 6 еще не реализованы"
}

phase_7_tests() {
    phase_header "7" "Миграция на DEV"
    test_skip "Тесты Фазы 7 еще не реализованы"
}

phase_8_tests() {
    phase_header "8" "Деплой на PROD"
    test_skip "Тесты Фазы 8 еще не реализованы"
}

phase_9_tests() {
    phase_header "9" "Документация"
    test_skip "Тесты Фазы 9 еще не реализованы"
}

# ============================================
# Вывод результатов
# ============================================
print_summary() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Окружение: ${BLUE}$ENVIRONMENT${NC}"
    echo -e "  Фазы: ${BLUE}0-$PHASE${NC}"
    echo -e "  Режим: ${BLUE}$([ "$WP_CLI_AVAILABLE" = true ] && echo 'WP-CLI + SQL' || echo 'Только SQL')${NC}"
    echo ""
    echo -e "  ${GREEN}Пройдено:${NC}  $PASSED_TESTS"
    echo -e "  ${RED}Провалено:${NC} $FAILED_TESTS"
    echo -e "  ${YELLOW}Пропущено:${NC} $SKIPPED_TESTS"
    echo ""
    
    TOTAL=$((PASSED_TESTS + FAILED_TESTS))
    
    if [ $FAILED_TESTS -eq 0 ] && [ $TOTAL -gt 0 ]; then
        echo -e "  ${GREEN}═══ ВСЕ ТЕСТЫ ПРОЙДЕНЫ ═══${NC}"
    elif [ $FAILED_TESTS -gt 0 ]; then
        echo -e "  ${RED}═══ ЕСТЬ ПРОВАЛЫ ($FAILED_TESTS) ═══${NC}"
    fi
    echo ""
}

# ============================================
# Главная функция
# ============================================
main() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         🧪 Polylang Integration Tests                     ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Окружение: ${BLUE}$ENVIRONMENT${NC}"
    echo -e "  Тестирование до фазы: ${BLUE}$PHASE${NC}"
    echo -e "  Force SQL: ${BLUE}$FORCE_SQL${NC}"
    
    # Настройка переменных окружения
    setup_environment
    
    # Фаза 0: Предварительные проверки
    if ! phase_0_checks; then
        echo -e "${RED}Предварительные проверки не пройдены. Тестирование прервано.${NC}"
        print_summary
        exit 1
    fi
    
    # Запуск тестов по фазам
    [ $PHASE -ge 1 ] && phase_1_tests
    [ $PHASE -ge 2 ] && phase_2_tests
    [ $PHASE -ge 3 ] && phase_3_tests
    [ $PHASE -ge 4 ] && phase_4_tests
    [ $PHASE -ge 5 ] && phase_5_tests
    [ $PHASE -ge 6 ] && phase_6_tests
    [ $PHASE -ge 7 ] && phase_7_tests
    [ $PHASE -ge 8 ] && phase_8_tests
    [ $PHASE -ge 9 ] && phase_9_tests
    
    # Вывод результатов
    print_summary
    
    # Exit code
    if [ $FAILED_TESTS -gt 0 ]; then
        exit 1
    fi
    exit 0
}

# Запуск
main
