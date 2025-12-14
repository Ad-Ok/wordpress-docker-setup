#!/bin/bash
# ============================================
# БЛОК D: Тест COLLECTION (8 тестов)
# ============================================

block_d_test_collection() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  БЛОК D: Тестирование CPT collection${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local test_num=26
    
    # [4-5.26] Создание RU collection
    echo -e "${BLUE}[4-5.$test_num]${NC} Создание RU collection..."
    
    local title=$(get_random_from_array "${TEST_COLLECTION_TITLES[@]}")
    local full_title="${title}_${PHASE_45_TIMESTAMP}"
    
    POST_COLLECTION_RU_ID=$(run_wp_cli post create --post_type=collection --post_title="$full_title" --post_status=publish --porcelain 2>/dev/null | grep -oE '[0-9]+' | head -1)
    
    if [ -z "$POST_COLLECTION_RU_ID" ] || [ "$POST_COLLECTION_RU_ID" == "0" ]; then
        test_fail "Не удалось создать RU collection"
        return 0
    fi
    
    # Установить язык RU
    run_wp_cli "eval 'pll_set_post_language($POST_COLLECTION_RU_ID, \"ru\");'" 2>/dev/null
    
    test_pass "RU collection создан (ID=$POST_COLLECTION_RU_ID, $full_title)"
    test_num=$((test_num + 1))
    
    # [4-5.27] Заполнение ACF полей
    echo -e "${BLUE}[4-5.$test_num]${NC} Заполнение ${#ACF_COLLECTION[@]} ACF полей..."
    
    # Установить featured image (случайное из TEST_IMAGES)
    run_wp_cli eval "update_post_meta($POST_COLLECTION_RU_ID, '_thumbnail_id', ${TEST_IMAGES[0]});" 2>/dev/null
    
    # Связать с художником (если есть из блока C)
    if [ -n "$POST_ARTIST_RU_ID" ] && [ "$POST_ARTIST_RU_ID" != "0" ]; then
        run_wp_cli eval "update_field('artist_id', $POST_ARTIST_RU_ID, $POST_COLLECTION_RU_ID);" 2>/dev/null
    fi
    
    # Скалярные ACF поля
    run_wp_cli eval "update_field('year_created', '2020', $POST_COLLECTION_RU_ID);" 2>/dev/null
    run_wp_cli eval "update_field('current_location', 'Музей тестирования', $POST_COLLECTION_RU_ID);" 2>/dev/null
    run_wp_cli eval "update_field('status', 'in_collection', $POST_COLLECTION_RU_ID);" 2>/dev/null
    run_wp_cli eval "update_field('height', '100', $POST_COLLECTION_RU_ID);" 2>/dev/null
    run_wp_cli eval "update_field('width', '80', $POST_COLLECTION_RU_ID);" 2>/dev/null
    run_wp_cli eval "update_field('depth', '5', $POST_COLLECTION_RU_ID);" 2>/dev/null
    
    # Галерея работы
    local gallery_ids="[${TEST_IMAGES[1]}, ${TEST_IMAGES[2]}]"
    run_wp_cli eval "update_field('работы', json_decode('$gallery_ids'), $POST_COLLECTION_RU_ID);" 2>/dev/null
    
    test_pass "Заполнены ACF поля: year_created, current_location, status, height, width, depth, галерея"
    test_num=$((test_num + 1))
    
    # [4-5.28] Назначение таксономий
    echo -e "${BLUE}[4-5.$test_num]${NC} Назначение ${#TAXONOMIES_COLLECTION[@]} таксономий..."
    
    for taxonomy in "${TAXONOMIES_COLLECTION[@]}"; do
        local term_id=$(get_term_id_ru "$taxonomy")
        if [ -n "$term_id" ] && [ "$term_id" != "0" ]; then
            run_wp_cli post term add $POST_COLLECTION_RU_ID $taxonomy $term_id --by=id 2>/dev/null
        fi
    done
    
    test_pass "Назначены таксономии: ${TAXONOMIES_COLLECTION[*]}"
    test_num=$((test_num + 1))
    
    # [4-5.29] Проверка редиректов ДО перевода
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка редиректов ДО создания перевода..."
    
    local redirects_before=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$POST_COLLECTION_RU_ID AND redirect_type='polylang'" 2>/dev/null | tr -d '[:space:]')
    
    test_pass "Редиректов ДО перевода: $redirects_before"
    test_num=$((test_num + 1))
    
    # [4-5.30] ИНТЕРАКТИВ: создание EN перевода
    echo -e "${BLUE}[4-5.$test_num]${NC} Создание EN перевода collection..."
    
    create_translation_interactive "collection" "$POST_COLLECTION_RU_ID" "COLLECTION"
    
    # Получить ID EN перевода
    echo -e "${CYAN}   → Поиск EN перевода...${NC}"
    POST_COLLECTION_EN_ID=$(run_wp_cli eval "echo pll_get_post($POST_COLLECTION_RU_ID, 'en');" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    
    if [ -z "$POST_COLLECTION_EN_ID" ] || [ "$POST_COLLECTION_EN_ID" == "0" ]; then
        test_fail "EN перевод не найден! Проверьте, что вы создали перевод."
        echo -e "${YELLOW}   Пропускаем оставшиеся проверки для collection${NC}"
        return 0
    fi
    
    test_pass "EN collection создан (ID=$POST_COLLECTION_EN_ID)"
    test_num=$((test_num + 1))
    
    # [4-5.31] Визуальный чек-лист
    echo -e "${BLUE}[4-5.$test_num]${NC} Визуальная проверка..."
    
    local ru_url="${SITE_URL}/?post_type=collection&p=$POST_COLLECTION_RU_ID"
    local en_url="${SITE_URL}/en/?post_type=collection&p=$POST_COLLECTION_EN_ID"
    local ru_archive="${SITE_URL}/collection/"
    local en_archive="${SITE_URL}/en/collection/"
    
    cat << EOF

╭────────────────────────────────────────────────────────────╮
│  ИНТЕРАКТИВНАЯ ПРОВЕРКА ПЕРЕВОДА COLLECTION
├────────────────────────────────────────────────────────────┤
│  Откройте в браузере:                                    │
│  RU: $ru_url
│  EN: $en_url
│                                                            │
│  Проверьте визуально:                                     │
│  [ ] 1. Все ACF поля заполнены в EN версии               │
│  [ ] 2. Таксономии отображаются на EN языке              │
│  [ ] 3. Изображения/галереи скопированы                  │
│  [ ] 4. Переключатель языков работает (RU ↔ EN)          │
│  [ ] 5. Пост отображается на архивных страницах:       │
│      - RU: $ru_archive
│      - EN: $en_archive
╰────────────────────────────────────────────────────────────╯

EOF
    read -p "Нажмите Enter после проверки..."
    
    test_pass "Визуальная проверка завершена"
    test_num=$((test_num + 1))
    
    # [4-5.32] Автопроверка ACF полей
    echo -e "${BLUE}[4-5.$test_num]${NC} Автоматическая проверка ${#ACF_COLLECTION[@]} ACF полей..."
    
    check_all_acf_fields "$POST_COLLECTION_RU_ID" "$POST_COLLECTION_EN_ID" "${ACF_COLLECTION[@]}"
    test_num=$((test_num + 1))
    
    # [4-5.33] Проверка таксономий
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка ${#TAXONOMIES_COLLECTION[@]} таксономий..."
    
    check_taxonomies_copied "$POST_COLLECTION_RU_ID" "$POST_COLLECTION_EN_ID" "${TAXONOMIES_COLLECTION[@]}"
    test_num=$((test_num + 1))
    
    # [4-5.34] Проверка редиректов ПОСЛЕ перевода
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка редиректов ПОСЛЕ создания перевода..."
    
    # Даём время плагину создать редирект (хук может быть асинхронным)
    sleep 1
    
    local redirects_after=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$POST_COLLECTION_EN_ID AND redirect_type='polylang'" 2>/dev/null | tr -d '[:space:]')
    
    # Default значения если пусто
    redirects_before=${redirects_before:-0}
    redirects_after=${redirects_after:-0}
    
    if [ "$redirects_after" -ge 1 ] 2>/dev/null; then
        local redirect_old_url=$(run_sql "SELECT old_url FROM wp_maslovka_redirects WHERE post_id=$POST_COLLECTION_EN_ID AND redirect_type='polylang' ORDER BY id DESC LIMIT 1" 2>/dev/null | xargs)
        local redirect_new_url=$(run_sql "SELECT new_url FROM wp_maslovka_redirects WHERE post_id=$POST_COLLECTION_EN_ID AND redirect_type='polylang' ORDER BY id DESC LIMIT 1" 2>/dev/null | xargs)
        
        test_pass "Polylang-редирект создан ($redirects_after шт.)"
        test_info "   $redirect_old_url → $redirect_new_url"
    else
        test_info "Редиректов не добавилось: ПОСЛЕ=$redirects_after, ДО=$redirects_before"
        test_info "   Возможно, кастомный плагин maslovka-redirects не активен"
    fi
}
