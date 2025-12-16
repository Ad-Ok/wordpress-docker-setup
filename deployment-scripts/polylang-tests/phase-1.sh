#!/bin/bash
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
    
    # Поддержка как JSON так и serialized PHP формата
    if echo "$POLYLANG_OPT" | grep -qE '("hide_default";b:1|"hide_default":true|"hide_default":1)'; then
        test_pass "hide_default = true"
    else
        test_fail "hide_default != true"
    fi
    
    # 1.5 Проверка rewrite = true
    test_num=$((test_num + 1))
    echo -e "${BLUE}[1.$test_num]${NC} rewrite = true..."
    
    # Поддержка как JSON так и serialized PHP формата
    if echo "$POLYLANG_OPT" | grep -qE '("rewrite";b:1|"rewrite":true|"rewrite":1)'; then
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
    
    # 1.10 Проверка что все посты имеют язык (нет постов без языка)
    test_num=$((test_num + 1))
    echo -e "${BLUE}[1.$test_num]${NC} Все опубликованные посты имеют язык..."
    
    # Считаем посты без языка (исключаем служебные типы)
    POSTS_WITHOUT_LANG=$(run_sql "
        SELECT COUNT(*) FROM wp_posts p
        WHERE p.post_status = 'publish'
        AND p.post_type IN ('post', 'page', 'artist', 'collection', 'events', 'vistavki', 'photo')
        AND p.ID NOT IN (
            SELECT tr.object_id FROM wp_term_relationships tr
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            WHERE tt.taxonomy = 'language'
        )
    " 2>/dev/null | tail -1 | tr -d '[:space:]')
    
    # Проверка: пустая строка или 0
    if [ -z "$POSTS_WITHOUT_LANG" ] || [ "$POSTS_WITHOUT_LANG" == "0" ]; then
        test_pass "Все посты имеют язык"
    else
        test_fail "Найдено $POSTS_WITHOUT_LANG постов без языка! Нажмите ссылку в админке: 'Set language to all posts without language'"
    fi
}
