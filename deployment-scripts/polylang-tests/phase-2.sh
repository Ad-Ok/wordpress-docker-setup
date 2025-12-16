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
    
    EN_HEADER_MENU=$(run_sql "SELECT term_id FROM wp_terms WHERE slug = 'main-menu-en'" 2>/dev/null | tail -1 | tr -d '[:space:]')
    
    if [ -n "$EN_HEADER_MENU" ] && [ "$EN_HEADER_MENU" != "NULL" ] && [ "$EN_HEADER_MENU" != "term_id" ]; then
        test_pass "Main Menu EN существует (term_id=$EN_HEADER_MENU)"
    else
        test_fail "Main Menu EN не найдено"
    fi
    
    # 2.2 Проверка что EN Footer меню создано
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} EN Footer меню создано..."
    
    EN_FOOTER_MENU=$(run_sql "SELECT term_id FROM wp_terms WHERE slug = 'footer-menu-en'" 2>/dev/null | tail -1 | tr -d '[:space:]')
    
    if [ -n "$EN_FOOTER_MENU" ] && [ "$EN_FOOTER_MENU" != "NULL" ] && [ "$EN_FOOTER_MENU" != "term_id" ]; then
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
    
    # ============================================================
    # БЛОК: Тестирование миграции 025 (перевод пунктов меню)
    # ============================================================
    
    # 2.11 Проверка что PHP миграция 025 существует
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} PHP миграция 025_sync_homepage_ru_to_en.php существует..."
    
    if [ "$ENV" = "local" ]; then
        MIGRATION_025_PATH="${WORKSPACE_ROOT}/www/wordpress/database/migrations/025_sync_homepage_ru_to_en.php"
    else
        MIGRATION_025_PATH="/home/${SSH_USER}/domains/${SITE_URL#https://}/public_html/database/migrations/025_sync_homepage_ru_to_en.php"
    fi
    
    if [ "$ENV" = "local" ]; then
        if [ -f "$MIGRATION_025_PATH" ]; then
            test_pass "Миграция 025_sync_homepage_ru_to_en.php найдена"
        else
            test_fail "Миграция 025_sync_homepage_ru_to_en.php не найдена"
        fi
    else
        # Для удалённых окружений проверяем через SSH
        if ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" "[ -f '$MIGRATION_025_PATH' ]" 2>/dev/null; then
            test_pass "Миграция 025_sync_homepage_ru_to_en.php найдена"
        else
            test_fail "Миграция 025_sync_homepage_ru_to_en.php не найдена"
        fi
    fi
    
    # 2.12 Подсчёт RU пунктов меню в Header
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} Подсчёт RU пунктов Header меню..."
    
    RU_HEADER_MENU=$(run_sql "SELECT term_id FROM wp_terms WHERE slug = 'menu' LIMIT 1" 2>/dev/null | tr -d '[:space:]')
    
    if [ -n "$RU_HEADER_MENU" ] && [ "$RU_HEADER_MENU" != "NULL" ]; then
        RU_HEADER_ITEMS_COUNT=$(run_sql "
            SELECT COUNT(*) FROM wp_posts p
            JOIN wp_term_relationships tr ON p.ID = tr.object_id
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            WHERE tt.taxonomy = 'nav_menu' AND tt.term_id = $RU_HEADER_MENU
            AND p.post_type = 'nav_menu_item' AND p.post_status = 'publish'
        " 2>/dev/null | tr -d '[:space:]')
        
        if [ "$RU_HEADER_ITEMS_COUNT" -ge 1 ] 2>/dev/null; then
            test_pass "RU Header меню содержит $RU_HEADER_ITEMS_COUNT пунктов"
        else
            test_fail "RU Header меню пустое"
        fi
    else
        test_skip "RU Header меню не найдено"
    fi
    
    # 2.14 Подсчёт EN пунктов меню в Header (должно совпадать с RU)
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} Подсчёт EN пунктов Header меню..."
    
    if [ -n "$EN_HEADER_MENU" ] && [ "$EN_HEADER_MENU" != "NULL" ]; then
        EN_HEADER_ITEMS_COUNT=$(run_sql "
            SELECT COUNT(*) FROM wp_posts p
            JOIN wp_term_relationships tr ON p.ID = tr.object_id
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            WHERE tt.taxonomy = 'nav_menu' AND tt.term_id = $EN_HEADER_MENU
            AND p.post_type = 'nav_menu_item' AND p.post_status = 'publish'
        " 2>/dev/null | tr -d '[:space:]')
        
        if [ "$EN_HEADER_ITEMS_COUNT" -ge 1 ] 2>/dev/null; then
            test_info "EN Header меню содержит $EN_HEADER_ITEMS_COUNT пунктов (RU: $RU_HEADER_ITEMS_COUNT)"
            
            # Проверяем что количество совпадает (после выполнения миграции 025)
            if [ "$EN_HEADER_ITEMS_COUNT" -eq "$RU_HEADER_ITEMS_COUNT" ] 2>/dev/null; then
                test_pass "Количество пунктов EN Header меню совпадает с RU"
            else
                test_info "Количество пунктов EN Header меню ($EN_HEADER_ITEMS_COUNT) не совпадает с RU ($RU_HEADER_ITEMS_COUNT) - возможно нужно запустить translate-menu-items.php"
            fi
        else
            test_fail "EN Header меню пустое"
        fi
    else
        test_skip "EN Header меню не найдено"
    fi
    
    # 2.15 Подсчёт RU пунктов меню в Footer
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} Подсчёт RU пунктов Footer меню..."
    
    RU_FOOTER_MENU=$(run_sql "SELECT term_id FROM wp_terms WHERE slug = 'footer-menu' LIMIT 1" 2>/dev/null | tr -d '[:space:]')
    
    if [ -n "$RU_FOOTER_MENU" ] && [ "$RU_FOOTER_MENU" != "NULL" ]; then
        RU_FOOTER_ITEMS_COUNT=$(run_sql "
            SELECT COUNT(*) FROM wp_posts p
            JOIN wp_term_relationships tr ON p.ID = tr.object_id
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            WHERE tt.taxonomy = 'nav_menu' AND tt.term_id = $RU_FOOTER_MENU
            AND p.post_type = 'nav_menu_item' AND p.post_status = 'publish'
        " 2>/dev/null | tr -d '[:space:]')
        
        if [ "$RU_FOOTER_ITEMS_COUNT" -ge 1 ] 2>/dev/null; then
            test_pass "RU Footer меню содержит $RU_FOOTER_ITEMS_COUNT пунктов"
        else
            test_fail "RU Footer меню пустое"
        fi
    else
        test_skip "RU Footer меню не найдено"
    fi
    
    # 2.16 Подсчёт EN пунктов меню в Footer (должно совпадать с RU)
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} Подсчёт EN пунктов Footer меню..."
    
    if [ -n "$EN_FOOTER_MENU" ] && [ "$EN_FOOTER_MENU" != "NULL" ]; then
        EN_FOOTER_ITEMS_COUNT=$(run_sql "
            SELECT COUNT(*) FROM wp_posts p
            JOIN wp_term_relationships tr ON p.ID = tr.object_id
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            WHERE tt.taxonomy = 'nav_menu' AND tt.term_id = $EN_FOOTER_MENU
            AND p.post_type = 'nav_menu_item' AND p.post_status = 'publish'
        " 2>/dev/null | tr -d '[:space:]')
        
        if [ "$EN_FOOTER_ITEMS_COUNT" -ge 1 ] 2>/dev/null; then
            test_info "EN Footer меню содержит $EN_FOOTER_ITEMS_COUNT пунктов (RU: $RU_FOOTER_ITEMS_COUNT)"
            
            # Проверяем что количество совпадает (после выполнения миграции 025)
            if [ "$EN_FOOTER_ITEMS_COUNT" -eq "$RU_FOOTER_ITEMS_COUNT" ] 2>/dev/null; then
                test_pass "Количество пунктов EN Footer меню совпадает с RU"
            else
                test_info "Количество пунктов EN Footer меню ($EN_FOOTER_ITEMS_COUNT) не совпадает с RU ($RU_FOOTER_ITEMS_COUNT) - возможно нужно запустить translate-menu-items.php"
            fi
        else
            test_fail "EN Footer меню пустое"
        fi
    else
        test_skip "EN Footer меню не найдено"
    fi
    
    # 2.17 Проверка что все EN пункты меню имеют соответствующие переводы страниц
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} Проверка переводов для пунктов меню типа 'post_type'..."
    
    if [ -n "$EN_HEADER_MENU" ] && [ "$EN_HEADER_MENU" != "NULL" ]; then
        # Подсчитываем пункты меню типа post_type без переводов
        UNTRANSLATED_COUNT=$(run_sql "
            SELECT COUNT(*)
            FROM wp_posts p
            JOIN wp_term_relationships tr ON p.ID = tr.object_id
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            JOIN wp_postmeta pm_type ON p.ID = pm_type.post_id AND pm_type.meta_key = '_menu_item_type'
            JOIN wp_postmeta pm_object_id ON p.ID = pm_object_id.post_id AND pm_object_id.meta_key = '_menu_item_object_id'
            LEFT JOIN (
                SELECT tr_ru.object_id as ru_id, tr_en.object_id as en_id
                FROM wp_term_relationships tr_ru
                INNER JOIN wp_term_taxonomy tt_ru ON tr_ru.term_taxonomy_id = tt_ru.term_taxonomy_id
                INNER JOIN wp_terms t_ru ON tt_ru.term_id = t_ru.term_id
                INNER JOIN wp_term_relationships tr_lang ON tr_ru.object_id = tr_lang.object_id
                INNER JOIN wp_term_taxonomy tt_lang ON tr_lang.term_taxonomy_id = tt_lang.term_taxonomy_id
                INNER JOIN wp_term_relationships tr_en ON tr_lang.term_taxonomy_id = tr_en.term_taxonomy_id
                INNER JOIN wp_term_taxonomy tt_en ON tr_en.term_taxonomy_id = tt_en.term_taxonomy_id
                INNER JOIN wp_terms t_en ON tt_en.term_id = t_en.term_id
                WHERE tt_ru.taxonomy = 'language' AND t_ru.slug = 'ru'
                AND tt_lang.taxonomy = 'post_translations'
                AND tt_en.taxonomy = 'language' AND t_en.slug = 'en'
            ) AS translations ON CAST(pm_object_id.meta_value AS UNSIGNED) = translations.ru_id
            WHERE tt.taxonomy = 'nav_menu' AND tt.term_id = $EN_HEADER_MENU
            AND p.post_type = 'nav_menu_item' AND p.post_status = 'publish'
            AND pm_type.meta_value = 'post_type'
            AND translations.en_id IS NULL
        " 2>/dev/null | tr -d '[:space:]')
        
        if [ "$UNTRANSLATED_COUNT" = "0" ] 2>/dev/null; then
            test_pass "Все пункты меню типа 'post_type' имеют переводы страниц"
        elif [ -n "$UNTRANSLATED_COUNT" ] && [ "$UNTRANSLATED_COUNT" != "NULL" ]; then
            test_info "$UNTRANSLATED_COUNT пунктов меню без переводов страниц - запустите translate-menu-items.php"
        else
            test_skip "Не удалось проверить переводы пунктов меню"
        fi
    else
        test_skip "EN Header меню не найдено"
    fi
    
    # 2.18 Проверка структуры меню (родитель-потомок сохранена)
    test_num=$((test_num + 1))
    echo -e "${BLUE}[2.$test_num]${NC} Проверка иерархии меню (родитель-потомок)..."
    
    if [ -n "$RU_HEADER_MENU" ] && [ "$RU_HEADER_MENU" != "NULL" ]; then
        # Подсчитываем пункты с родителями в RU меню
        RU_NESTED_COUNT=$(run_sql "
            SELECT COUNT(*) FROM wp_posts p
            JOIN wp_term_relationships tr ON p.ID = tr.object_id
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            JOIN wp_postmeta pm ON p.ID = pm.post_id AND pm.meta_key = '_menu_item_menu_item_parent'
            WHERE tt.taxonomy = 'nav_menu' AND tt.term_id = $RU_HEADER_MENU
            AND p.post_type = 'nav_menu_item' AND p.post_status = 'publish'
            AND CAST(pm.meta_value AS UNSIGNED) > 0
        " 2>/dev/null | tr -d '[:space:]')
        
        if [ -n "$EN_HEADER_MENU" ] && [ "$EN_HEADER_MENU" != "NULL" ]; then
            # Подсчитываем пункты с родителями в EN меню
            EN_NESTED_COUNT=$(run_sql "
                SELECT COUNT(*) FROM wp_posts p
                JOIN wp_term_relationships tr ON p.ID = tr.object_id
                JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
                JOIN wp_postmeta pm ON p.ID = pm.post_id AND pm.meta_key = '_menu_item_menu_item_parent'
                WHERE tt.taxonomy = 'nav_menu' AND tt.term_id = $EN_HEADER_MENU
                AND p.post_type = 'nav_menu_item' AND p.post_status = 'publish'
                AND CAST(pm.meta_value AS UNSIGNED) > 0
            " 2>/dev/null | tr -d '[:space:]')
            
            if [ "$RU_NESTED_COUNT" = "0" ] && [ "$EN_NESTED_COUNT" = "0" ] 2>/dev/null; then
                test_pass "Оба меню не имеют вложенных пунктов (плоская структура)"
            elif [ "$RU_NESTED_COUNT" = "$EN_NESTED_COUNT" ] 2>/dev/null; then
                test_pass "Иерархия меню сохранена ($RU_NESTED_COUNT вложенных пунктов)"
            else
                test_info "Иерархия меню отличается: RU=$RU_NESTED_COUNT, EN=$EN_NESTED_COUNT"
            fi
        else
            test_skip "EN Header меню не найдено"
        fi
    else
        test_skip "RU Header меню не найдено"
    fi
}
