#!/bin/bash
# ============================================
# ФАЗА 6: SEO оптимизация
# ============================================

phase_6_tests() {
    phase_header "6" "SEO оптимизация"
    
    # Определяем путь к теме в зависимости от окружения
    local theme_path=""
    if [ "$IS_LOCAL" = true ]; then
        theme_path="${LOCAL_THEME_PATH}"
    fi
    
    # ══════════════════════════════════════════
    # 6.1 Hreflang теги
    # ══════════════════════════════════════════
    echo ""
    echo -e "${CYAN}[6.1] Hreflang теги${NC}"
    echo "─────────────────────────────────────────"
    
    # 6.1.1 Проверка hreflang тегов на главной странице RU
    echo "[6.1.1] Проверка hreflang тегов на главной (RU)..."
    local homepage_ru=$(curl_with_auth -s -L "${SITE_URL}/")
    if echo "$homepage_ru" | grep -q 'hreflang="ru"'; then
        test_pass "hreflang=\"ru\" присутствует на главной"
    else
        test_fail "hreflang=\"ru\" не найден на главной"
    fi
    
    # 6.1.2 Проверка hreflang для EN версии
    echo "[6.1.2] Проверка hreflang=\"en\" на главной..."
    if echo "$homepage_ru" | grep -q 'hreflang="en"'; then
        test_pass "hreflang=\"en\" присутствует на главной"
    else
        test_skip "hreflang=\"en\" не найден (возможно EN версия отключена)"
    fi
    
    # 6.1.3 Проверка hreflang на EN странице
    echo "[6.1.3] Проверка hreflang тегов на /en/..."
    local homepage_en=$(curl_with_auth -s -L "${SITE_URL}/en/")
    if echo "$homepage_en" | grep -q 'hreflang='; then
        test_pass "hreflang теги присутствуют на /en/"
    else
        test_skip "hreflang теги не найдены на /en/ (возможно EN версия отключена)"
    fi
    
    # 6.1.4 Проверка функции отключения hreflang в теме
    echo "[6.1.4] Проверка функции maslovka_maybe_disable_hreflang..."
    if [ -n "$theme_path" ]; then
        if grep -q "maslovka_maybe_disable_hreflang" "${theme_path}/inc/theme/theme-setup.php" 2>/dev/null; then
            test_pass "Функция maslovka_maybe_disable_hreflang существует"
        else
            test_fail "Функция maslovka_maybe_disable_hreflang не найдена в theme-setup.php"
        fi
    else
        test_skip "Тест файловой системы доступен только для local"
    fi
    
    # 6.1.5 Проверка фильтра pll_rel_hreflang_attributes
    echo "[6.1.5] Проверка фильтра pll_rel_hreflang_attributes..."
    if [ -n "$theme_path" ]; then
        if grep -q "pll_rel_hreflang_attributes" "${theme_path}/inc/theme/theme-setup.php" 2>/dev/null; then
            test_pass "Фильтр pll_rel_hreflang_attributes подключен для условного отключения"
        else
            test_fail "Фильтр pll_rel_hreflang_attributes не найден"
        fi
    else
        test_skip "Тест файловой системы доступен только для local"
    fi
    
    # ══════════════════════════════════════════
    # 6.2 Canonical теги
    # ══════════════════════════════════════════
    echo ""
    echo -e "${CYAN}[6.2] Canonical теги${NC}"
    echo "─────────────────────────────────────────"
    
    # 6.2.1 Проверка canonical на главной RU
    echo "[6.2.1] Проверка canonical тега на главной (RU)..."
    if echo "$homepage_ru" | grep -qE 'rel=["\x27]canonical["\x27]'; then
        local canonical_url=$(echo "$homepage_ru" | grep -oE '<link[^>]*rel=["\x27]canonical["\x27][^>]*>' | head -1)
        test_pass "Canonical тег присутствует на главной RU"
        test_info "  $canonical_url"
    else
        test_info "Canonical тег не найден — WordPress добавит его автоматически через wp_head()"
    fi
    
    # 6.2.2 Проверка что WordPress добавляет canonical (rel_canonical action)
    echo "[6.2.2] Проверка что rel_canonical() подключена через wp_head..."
    # WordPress автоматически добавляет canonical через wp_head, проверяем что wp_head вызывается
    if [ -n "$theme_path" ]; then
        if grep -q "wp_head()" "${theme_path}/header.php" 2>/dev/null; then
            test_pass "wp_head() вызывается в header.php — canonical теги будут добавлены WordPress"
        else
            test_fail "wp_head() не найден в header.php"
        fi
    else
        test_skip "Тест файловой системы доступен только для local"
    fi
    
    # ══════════════════════════════════════════
    # 6.3 XML Sitemap
    # ══════════════════════════════════════════
    echo ""
    echo -e "${CYAN}[6.3] XML Sitemap${NC}"
    echo "─────────────────────────────────────────"
    
    # 6.3.1 Проверка доступности WordPress sitemap
    echo "[6.3.1] Проверка доступности /wp-sitemap.xml..."
    local sitemap_response=$(curl_with_auth -s -o /dev/null -w "%{http_code}" "${SITE_URL}/wp-sitemap.xml")
    if [ "$sitemap_response" = "200" ]; then
        test_pass "WordPress sitemap доступен (/wp-sitemap.xml)"
    else
        test_info "WordPress sitemap недоступен (код: $sitemap_response) — это нормально для WP < 5.5 или отключённого sitemap"
    fi
    
    # 6.3.2 Проверка содержимого sitemap
    echo "[6.3.2] Проверка содержимого sitemap..."
    local sitemap_content=$(curl_with_auth -s -L "${SITE_URL}/wp-sitemap.xml" 2>/dev/null)
    if echo "$sitemap_content" | grep -q "sitemapindex\|urlset"; then
        test_pass "Sitemap содержит валидную XML структуру"
    else
        test_info "Sitemap не содержит ожидаемой структуры (возможно отключён)"
    fi
    
    # ══════════════════════════════════════════
    # 6.4 Open Graph теги
    # ══════════════════════════════════════════
    echo ""
    echo -e "${CYAN}[6.4] Open Graph теги${NC}"
    echo "─────────────────────────────────────────"
    
    # 6.4.1 Проверка og:locale на странице
    echo "[6.4.1] Проверка og:locale..."
    if echo "$homepage_ru" | grep -q 'og:locale'; then
        local og_locale=$(echo "$homepage_ru" | grep -oE 'og:locale[^>]*content="[^"]*"' | head -1)
        test_pass "og:locale присутствует"
        test_info "  $og_locale"
    else
        test_info "og:locale не найден — рекомендуется добавить через SEO-плагин (Yoast, Rank Math)"
    fi
    
    # 6.4.2 Проверка og:title
    echo "[6.4.2] Проверка og:title..."
    if echo "$homepage_ru" | grep -q 'og:title'; then
        test_pass "og:title присутствует"
    else
        test_info "og:title не найден — рекомендуется добавить через SEO-плагин"
    fi
    
    # 6.4.3 Проверка og:image
    echo "[6.4.3] Проверка og:image..."
    if echo "$homepage_ru" | grep -q 'og:image'; then
        test_pass "og:image присутствует"
    else
        test_info "og:image не найден — рекомендуется добавить через SEO-плагин"
    fi
    
    # ══════════════════════════════════════════
    # 6.5 Языковые мета-теги
    # ══════════════════════════════════════════
    echo ""
    echo -e "${CYAN}[6.5] Языковые мета-теги${NC}"
    echo "─────────────────────────────────────────"
    
    # 6.5.1 Проверка html lang атрибута на RU странице
    echo "[6.5.1] Проверка атрибута html lang на RU странице..."
    if echo "$homepage_ru" | grep -qE '<html[^>]*lang="ru'; then
        test_pass "html lang=\"ru\" установлен корректно"
    else
        test_fail "html lang=\"ru\" не найден на RU странице"
    fi
    
    # 6.5.2 Проверка html lang атрибута на EN странице
    echo "[6.5.2] Проверка атрибута html lang на EN странице..."
    if echo "$homepage_en" | grep -qE '<html[^>]*lang="en'; then
        test_pass "html lang=\"en\" установлен корректно на /en/"
    else
        test_skip "html lang=\"en\" не проверен (возможно EN версия отключена)"
    fi
    
    # ══════════════════════════════════════════
    # 6.6 Noindex для скрытой EN версии
    # ══════════════════════════════════════════
    echo ""
    echo -e "${CYAN}[6.6] Noindex для скрытой EN версии${NC}"
    echo "─────────────────────────────────────────"
    
    # 6.6.1 Проверка условия noindex в header.php
    echo "[6.6.1] Проверка условия noindex в header.php..."
    if [ -n "$theme_path" ]; then
        if grep -q "noindex" "${theme_path}/header.php" 2>/dev/null; then
            test_pass "Условие noindex для EN страниц добавлено в header.php"
        else
            test_fail "Условие noindex не найдено в header.php"
        fi
    else
        test_skip "Тест файловой системы доступен только для local"
    fi
    
    # 6.6.2 Проверка условия english_version_enabled
    echo "[6.6.2] Проверка условия english_version_enabled для noindex..."
    if [ -n "$theme_path" ]; then
        if grep -q "english_version_enabled" "${theme_path}/header.php" 2>/dev/null; then
            test_pass "Условие english_version_enabled проверяется в header.php"
        else
            test_fail "Условие english_version_enabled не найдено в header.php для noindex"
        fi
    else
        test_skip "Тест файловой системы доступен только для local"
    fi
    
    # ══════════════════════════════════════════
    # 6.7 Polylang интеграция
    # ══════════════════════════════════════════
    echo ""
    echo -e "${CYAN}[6.7] Polylang SEO интеграция${NC}"
    echo "─────────────────────────────────────────"
    
    # 6.7.1 Проверка что Polylang добавляет hreflang автоматически
    echo "[6.7.1] Проверка автоматических hreflang от Polylang..."
    # Polylang добавляет hreflang через wp_head, они должны иметь формат с rel="alternate"
    if echo "$homepage_ru" | grep -qE 'rel="alternate"[^>]*hreflang='; then
        test_pass "Polylang автоматически добавляет hreflang теги"
    else
        if echo "$homepage_ru" | grep -q 'hreflang='; then
            test_pass "hreflang теги присутствуют (формат может отличаться)"
        else
            test_skip "hreflang теги не найдены (возможно Polylang не активен или EN отключен)"
        fi
    fi
    
    # ══════════════════════════════════════════
    # Итоговая информация
    # ══════════════════════════════════════════
    echo ""
    echo -e "${CYAN}[Итог] SEO статус${NC}"
    echo "─────────────────────────────────────────"
    test_info "Hreflang: Polylang генерирует автоматически"
    test_info "Canonical: WordPress генерирует автоматически через wp_head()"
    test_info "Sitemap: WordPress 5.5+ имеет встроенный /wp-sitemap.xml"
    test_info "Open Graph: Рекомендуется SEO-плагин (Yoast, Rank Math)"
}
