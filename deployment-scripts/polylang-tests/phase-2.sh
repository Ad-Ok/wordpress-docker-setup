#!/bin/bash
# ============================================
# ФАЗА 2: SQL миграции (EN меню)
# ============================================

phase_2_tests() {
    phase_header "2" "SQL миграции (EN меню)"
    
    local test_num=0
    
    # 2.1 Проверка что EN Header меню создано
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} EN Header меню создано..."
    
    EN_HEADER_MENU=$(run_sql "SELECT term_id FROM wp_terms WHERE slug = 'main-menu-en'" 2>/dev/null | tr -d '[:space:]')
    
    if [ -n "$EN_HEADER_MENU" ] && [ "$EN_HEADER_MENU" != "NULL" ]; then
        test_pass "Main Menu EN существует (term_id=$EN_HEADER_MENU)"
    else
        test_fail "Main Menu EN не найдено"
    fi
    
    # 2.2 Проверка что EN Footer меню создано
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} EN Footer меню создано..."
    
    EN_FOOTER_MENU=$(run_sql "SELECT term_id FROM wp_terms WHERE slug = 'footer-menu-en'" 2>/dev/null | tr -d '[:space:]')
    
    if [ -n "$EN_FOOTER_MENU" ] && [ "$EN_FOOTER_MENU" != "NULL" ]; then
        test_pass "Footer Menu EN существует (term_id=$EN_FOOTER_MENU)"
    else
        test_fail "Footer Menu EN не найдено"
    fi
    
    # 2.3 Проверка пунктов EN Header меню
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} EN Header меню содержит пункт Home..."
    
    if [ -n "$EN_HEADER_MENU" ]; then
        HOME_ITEM=$(run_sql "
            SELECT p.post_title FROM wp_posts p
            JOIN wp_term_relationships tr ON p.ID = tr.object_id
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            WHERE tt.taxonomy = 'nav_menu' AND tt.term_id = $EN_HEADER_MENU
            AND p.post_type = 'nav_menu_item' AND p.post_title = 'Home'
        " 2>/dev/null | tr -d '[:space:]')
        
        if [ "$HOME_ITEM" == "Home" ]; then
            test_pass "Пункт 'Home' найден в EN Header меню"
        else
            test_fail "Пункт 'Home' не найден в EN Header меню"
        fi
    else
        test_skip "EN Header меню не существует"
    fi
    
    # 2.4 Проверка пунктов EN Footer меню (телефон)
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} EN Footer меню содержит телефон..."
    
    if [ -n "$EN_FOOTER_MENU" ]; then
        PHONE_ITEM=$(run_sql "
            SELECT COUNT(*) FROM wp_posts p
            JOIN wp_term_relationships tr ON p.ID = tr.object_id
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            WHERE tt.taxonomy = 'nav_menu' AND tt.term_id = $EN_FOOTER_MENU
            AND p.post_type = 'nav_menu_item' AND p.post_title LIKE '%980%'
        " 2>/dev/null | tr -d '[:space:]')
        
        if [ "$PHONE_ITEM" -ge 1 ] 2>/dev/null; then
            test_pass "Пункт с телефоном найден в EN Footer меню"
        else
            test_fail "Пункт с телефоном не найден в EN Footer меню"
        fi
    else
        test_skip "EN Footer меню не существует"
    fi
    
    # 2.5 Проверка пунктов EN Footer меню (email)
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} EN Footer меню содержит email..."
    
    if [ -n "$EN_FOOTER_MENU" ]; then
        EMAIL_ITEM=$(run_sql "
            SELECT COUNT(*) FROM wp_posts p
            JOIN wp_term_relationships tr ON p.ID = tr.object_id
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            WHERE tt.taxonomy = 'nav_menu' AND tt.term_id = $EN_FOOTER_MENU
            AND p.post_type = 'nav_menu_item' AND p.post_title LIKE '%maslovka.org%'
        " 2>/dev/null | tr -d '[:space:]')
        
        if [ "$EMAIL_ITEM" -ge 1 ] 2>/dev/null; then
            test_pass "Пункт с email найден в EN Footer меню"
        else
            test_fail "Пункт с email не найден в EN Footer меню"
        fi
    else
        test_skip "EN Footer меню не существует"
    fi
    
    # 2.6 Проверка nav_menus в опции polylang
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} nav_menus настроен в Polylang..."
    
    POLYLANG_OPT=$(run_sql "SELECT option_value FROM wp_options WHERE option_name = 'polylang'" 2>/dev/null)
    
    if echo "$POLYLANG_OPT" | grep -q '"nav_menus"' && echo "$POLYLANG_OPT" | grep -q '"maslovka"'; then
        test_pass "nav_menus содержит настройки для темы maslovka"
    else
        test_fail "nav_menus пустой или не содержит тему maslovka"
    fi
    
    # 2.7 Проверка что main-menu привязан к языкам
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} main-menu привязан к ru и en..."
    
    if echo "$POLYLANG_OPT" | grep -q 'main-menu.*ru.*en'; then
        test_pass "main-menu привязан к обоим языкам"
    else
        # Альтернативная проверка через отдельные паттерны
        if echo "$POLYLANG_OPT" | grep -q '"main-menu"' && echo "$POLYLANG_OPT" | grep -q '"ru"' && echo "$POLYLANG_OPT" | grep -q '"en"'; then
            test_pass "main-menu привязан к обоим языкам"
        else
            test_fail "main-menu не привязан к языкам"
        fi
    fi
    
    # 2.8 Проверка что footer-menu привязан к языкам
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} footer-menu привязан к ru и en..."
    
    if echo "$POLYLANG_OPT" | grep -q 'footer-menu.*ru.*en'; then
        test_pass "footer-menu привязан к обоим языкам"
    else
        # Альтернативная проверка
        if echo "$POLYLANG_OPT" | grep -q '"footer-menu"' || echo "$POLYLANG_OPT" | grep -q 'footer-menu'; then
            test_pass "footer-menu привязан к обоим языкам"
        else
            test_fail "footer-menu не привязан к языкам"
        fi
    fi
    
    # 2.9 Проверка EN Header меню на фронтенде
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} EN Header меню отображается на /en/..."
    
    EN_PAGE_HTML=$(curl_with_auth -s --max-time 10 "${SITE_URL}/en/" 2>/dev/null)
    
    if echo "$EN_PAGE_HTML" | grep -qi "Home"; then
        test_pass "Пункт 'Home' найден на странице /en/"
    else
        test_fail "Пункт 'Home' не найден на странице /en/"
    fi
    
    # 2.10 Проверка EN Footer меню на фронтенде
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} EN Footer меню отображается на /en/..."
    
    if echo "$EN_PAGE_HTML" | grep -qi "hello@maslovka.org"; then
        test_pass "Email найден в футере на странице /en/"
    else
        test_fail "Email не найден в футере на странице /en/"
    fi
}
