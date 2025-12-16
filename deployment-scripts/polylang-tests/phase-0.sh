#!/bin/bash
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
            export WP_CLI_AVAILABLE=true
        else
            test_info "WP-CLI недоступен, будет использоваться SQL"
            export WP_CLI_AVAILABLE=false
        fi
    else
        echo -e "${BLUE}[0.2]${NC} WP-CLI пропущен (--force-sql)"
        export WP_CLI_AVAILABLE=false
    fi
    
    # 0.3 Проверка доступности БД
    echo -e "${BLUE}[0.3]${NC} Проверка доступности базы данных..."
    
    local db_result=$(run_sql "SELECT 1" 2>&1)
    if echo "$db_result" | grep -q "1"; then
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
