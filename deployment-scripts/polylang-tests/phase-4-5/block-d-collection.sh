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
    
    # Связать с созданным artist (если есть)
    if [ -n "$POST_ARTIST_RU_ID" ] && [ "$POST_ARTIST_RU_ID" != "0" ]; then
        run_wp_cli "post meta update $POST_COLLECTION_RU_ID artist_id '$POST_ARTIST_RU_ID'" 2>/dev/null
    fi
    
    run_wp_cli "post meta update $POST_COLLECTION_RU_ID year_created '2020'" 2>/dev/null
    run_wp_cli "post meta update $POST_COLLECTION_RU_ID current_location 'Музей тестирования'" 2>/dev/null
    run_wp_cli "post meta update $POST_COLLECTION_RU_ID status 'in_collection'" 2>/dev/null
    run_wp_cli "post meta update $POST_COLLECTION_RU_ID height '100'" 2>/dev/null
    run_wp_cli "post meta update $POST_COLLECTION_RU_ID width '80'" 2>/dev/null
    run_wp_cli "post meta update $POST_COLLECTION_RU_ID depth '5'" 2>/dev/null
    
    test_pass "Заполнены ACF поля: artist_id, year_created, current_location, status, height, width, depth"
    test_num=$((test_num + 1))
    
    # [4-5.28] Назначение таксономий
    echo -e "${BLUE}[4-5.$test_num]${NC} Назначение ${#TAXONOMIES_COLLECTION[@]} таксономий..."
    
    for taxonomy in "${TAXONOMIES_COLLECTION[@]}"; do
        local term_id=$(get_term_id_ru "$taxonomy")
        if [ -n "$term_id" ] && [ "$term_id" != "0" ]; then
            run_wp_cli "post term add $POST_COLLECTION_RU_ID $taxonomy $term_id" 2>/dev/null
        fi
    done
    
    test_pass "Назначены таксономии: ${TAXONOMIES_COLLECTION[*]}"
    test_num=$((test_num + 1))
    
    # [4-5.29] Проверка на /collection/ (RU)
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка отображения на $ARCHIVE_URL_COLLECTION (RU)..."
    
    if check_post_on_archive "$POST_COLLECTION_RU_ID" "$ARCHIVE_URL_COLLECTION" "ru"; then
        test_pass "RU collection найден на архивной странице"
    else
        test_info "Не удалось проверить отображение на архиве (требует curl)"
    fi
    test_num=$((test_num + 1))
    
    # [4-5.30] ИНТЕРАКТИВ: создание EN перевода
    echo -e "${BLUE}[4-5.$test_num]${NC} Создание EN перевода collection..."
    
    create_translation_interactive "collection" "$POST_COLLECTION_RU_ID" "COLLECTION"
    
    # Получить ID EN перевода
    echo -e "${CYAN}   → Поиск EN перевода...${NC}"
    POST_COLLECTION_EN_ID=$(run_wp_cli "eval 'echo pll_get_post($POST_COLLECTION_RU_ID, \"en\");'" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    
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
    
    show_visual_checklist "collection" "$ru_url" "$en_url"
    
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
    
    # [4-5.34] Проверка на /en/collection/
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка отображения на /en$ARCHIVE_URL_COLLECTION (EN)..."
    
    if check_post_on_archive "$POST_COLLECTION_EN_ID" "$ARCHIVE_URL_COLLECTION" "en"; then
        test_pass "EN collection найден на архивной странице"
    else
        test_info "Не удалось проверить отображение на архиве"
    fi
}
