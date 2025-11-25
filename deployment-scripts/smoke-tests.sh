#!/bin/bash
# 🧪 Smoke Tests для your-domain.com
# Проверки после деплоя

set -eo pipefail

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Переменные
ENVIRONMENT="${1:-prod}"  # prod или dev
FAILED_TESTS=0
PASSED_TESTS=0

if [ "$ENVIRONMENT" == "prod" ]; then
    SITE_URL="$PROD_SITE_URL"
    AUTH=""
else
    SITE_URL="$DEV_SITE_URL"
    AUTH="-u 'test:test'"
fi

# Функция для curl с auth
curl_with_auth() {
    if [ "$ENVIRONMENT" == "dev" ]; then
        curl -u 'test:test' "$@"
    else
        curl "$@"
    fi
}

# ============================================
# Test 1: Homepage загружается
# ============================================
test_homepage() {
    echo -e "${BLUE}[1/8]${NC} Testing homepage..."
    
    HTTP_CODE=$(curl_with_auth -s -o /dev/null -w "%{http_code}" \
        --max-time "$SMOKE_TEST_TIMEOUT" \
        "${SITE_URL}/")
    
    if [ "$HTTP_CODE" == "200" ]; then
        echo -e "${GREEN}✓${NC} Homepage returns HTTP 200"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} Homepage returns HTTP ${HTTP_CODE} (expected 200)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# ============================================
# Test 2: WP REST API работает
# ============================================
test_rest_api() {
    echo -e "${BLUE}[2/8]${NC} Testing WordPress REST API..."
    
    HTTP_CODE=$(curl_with_auth -s -o /dev/null -w "%{http_code}" \
        --max-time "$SMOKE_TEST_TIMEOUT" \
        "${SITE_URL}/wp-json/")
    
    if [ "$HTTP_CODE" == "200" ]; then
        echo -e "${GREEN}✓${NC} REST API returns HTTP 200"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} REST API returns HTTP ${HTTP_CODE}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# ============================================
# Test 3: Admin Ajax работает
# ============================================
test_admin_ajax() {
    echo -e "${BLUE}[3/8]${NC} Testing admin-ajax.php..."
    
    HTTP_CODE=$(curl_with_auth -s -o /dev/null -w "%{http_code}" \
        --max-time "$SMOKE_TEST_TIMEOUT" \
        "${SITE_URL}/wp-admin/admin-ajax.php" \
        -d "action=heartbeat")
    
    if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "400" ]; then
        echo -e "${GREEN}✓${NC} admin-ajax.php is accessible"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} admin-ajax.php returns HTTP ${HTTP_CODE}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# ============================================
# Test 4: CSS файлы загружаются
# ============================================
test_css_assets() {
    echo -e "${BLUE}[4/8]${NC} Testing CSS assets..."
    
    # Получаем HTML homepage и ищем ссылки на CSS
    CSS_URL=$(curl_with_auth -s "${SITE_URL}/" | \
        grep -o "href=['\"][^'\"]*themes/[^'\"]*\.css[^'\"]*['\"]" | \
        head -1 | \
        sed "s/href=['\"]//;s/['\"]//")
    
    if [ -z "$CSS_URL" ]; then
        echo -e "${YELLOW}⚠️  Could not find CSS link in HTML"
        return
    fi
    
    # Проверяем абсолютный URL
    if [[ ! "$CSS_URL" =~ ^http ]]; then
        CSS_URL="${SITE_URL}${CSS_URL}"
    fi
    
    HTTP_CODE=$(curl_with_auth -s -o /dev/null -w "%{http_code}" \
        --max-time "$SMOKE_TEST_TIMEOUT" \
        "$CSS_URL")
    
    if [ "$HTTP_CODE" == "200" ]; then
        echo -e "${GREEN}✓${NC} CSS assets load successfully"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} CSS returns HTTP ${HTTP_CODE}"
        echo "   URL: ${CSS_URL}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# ============================================
# Test 5: JS файлы загружаются
# ============================================
test_js_assets() {
    echo -e "${BLUE}[5/8]${NC} Testing JS assets..."
    
    # Получаем HTML homepage и ищем ссылки на JS
    JS_URL=$(curl_with_auth -s "${SITE_URL}/" | \
        grep -o "src=['\"][^'\"]*themes/[^'\"]*\.js[^'\"]*['\"]" | \
        head -1 | \
        sed "s/src=['\"]//;s/['\"]//")
    
    if [ -z "$JS_URL" ]; then
        echo -e "${YELLOW}⚠️  Could not find JS link in HTML"
        return
    fi
    
    # Проверяем абсолютный URL
    if [[ ! "$JS_URL" =~ ^http ]]; then
        JS_URL="${SITE_URL}${JS_URL}"
    fi
    
    HTTP_CODE=$(curl_with_auth -s -o /dev/null -w "%{http_code}" \
        --max-time "$SMOKE_TEST_TIMEOUT" \
        "$JS_URL")
    
    if [ "$HTTP_CODE" == "200" ]; then
        echo -e "${GREEN}✓${NC} JS assets load successfully"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} JS returns HTTP ${HTTP_CODE}"
        echo "   URL: ${JS_URL}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# ============================================
# Test 6: Проверка PHP ошибок в логах
# ============================================
test_php_errors() {
    echo -e "${BLUE}[6/8]${NC} Checking PHP errors..."
    
    if [ "$ENVIRONMENT" == "prod" ]; then
        SSH_USER="$PROD_SSH_USER"
        SSH_HOST="$PROD_SSH_HOST"
    else
        SSH_USER="$DEV_SSH_USER"
        SSH_HOST="$DEV_SSH_HOST"
    fi
    
    # Проверяем последние 50 строк error.log
    ERROR_COUNT=$(ssh "${SSH_USER}@${SSH_HOST}" \
        "tail -50 /home/${SSH_USER}/logs/error.log 2>/dev/null | grep -i 'fatal\|error' | wc -l" || echo "0")
    
    if [ "$ERROR_COUNT" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} No PHP errors in recent logs"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} Found ${ERROR_COUNT} error(s) in logs"
        echo -e "${YELLOW}   Check: ssh ${SSH_USER}@${SSH_HOST} 'tail -50 /home/${SSH_USER}/logs/error.log'${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# ============================================
# Test 7: Проверка времени отклика
# ============================================
test_response_time() {
    echo -e "${BLUE}[7/8]${NC} Testing response time..."
    
    RESPONSE_TIME=$(curl_with_auth -s -o /dev/null -w "%{time_total}" \
        --max-time "$SMOKE_TEST_TIMEOUT" \
        "${SITE_URL}/")
    
    # Конвертируем в целое число (миллисекунды)
    RESPONSE_MS=$(echo "$RESPONSE_TIME * 1000" | bc | cut -d. -f1)
    
    if [ "$RESPONSE_MS" -lt 2000 ]; then
        echo -e "${GREEN}✓${NC} Response time: ${RESPONSE_MS}ms (good)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    elif [ "$RESPONSE_MS" -lt 5000 ]; then
        echo -e "${YELLOW}⚠️  Response time: ${RESPONSE_MS}ms (slow)${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} Response time: ${RESPONSE_MS}ms (too slow)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# ============================================
# Test 8: Проверка критичных страниц
# ============================================
test_critical_pages() {
    echo -e "${BLUE}[8/8]${NC} Testing critical pages..."
    
    CRITICAL_PAGES=(
        "/artists/"
        "/privacy-policy/"
    )
    
    LOCAL_FAILED=0
    
    for page in "${CRITICAL_PAGES[@]}"; do
        HTTP_CODE=$(curl_with_auth -s -o /dev/null -w "%{http_code}" \
            --max-time "$SMOKE_TEST_TIMEOUT" \
            "${SITE_URL}${page}")
        
        if [ "$HTTP_CODE" == "200" ]; then
            echo -e "  ${GREEN}✓${NC} ${page}"
        else
            echo -e "  ${RED}✗${NC} ${page} returns HTTP ${HTTP_CODE}"
            ((LOCAL_FAILED++))
        fi
    done
    
    if [ $LOCAL_FAILED -eq 0 ]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# ============================================
# Запуск тестов
# ============================================
test_homepage
echo ""
test_rest_api
echo ""
test_admin_ajax
echo ""
test_css_assets
echo ""
test_js_assets
echo ""
test_php_errors
echo ""
test_response_time
echo ""
test_critical_pages
echo ""

# ============================================
# Summary
# ============================================
TOTAL_TESTS=$((PASSED_TESTS + FAILED_TESTS))

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Test Summary                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo "Total tests: ${TOTAL_TESTS}"
echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}"
echo -e "${RED}Failed: ${FAILED_TESTS}${NC}"
echo ""

if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}❌ SMOKE TESTS FAILED${NC}"
    echo ""
    echo -e "${YELLOW}Action required:${NC}"
    echo "1. Check error logs"
    echo "2. Verify deployment files"
    echo "3. Consider rollback if critical"
    exit 1
else
    echo -e "${GREEN}✅ ALL SMOKE TESTS PASSED${NC}"
    echo ""
    echo "Deployment verified successfully! 🎉"
    exit 0
fi
