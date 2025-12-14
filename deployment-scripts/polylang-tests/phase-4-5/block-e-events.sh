#!/bin/bash
# ============================================
# БЛОК E: Тест EVENTS (7 тестов)
# ============================================

block_e_test_events() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  БЛОК E: Тестирование CPT events${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local test_num=35
    
    # [4-5.35] Создание RU events
    echo -e "${BLUE}[4-5.$test_num]${NC} Создание RU events..."
    
    local title=$(get_random_from_array "${TEST_EVENTS_TITLES[@]}")
    local full_title="${title}_${PHASE_45_TIMESTAMP}"
    
    POST_EVENTS_RU_ID=$(run_wp_cli post create --post_type=events --post_title="$full_title" --post_status=publish --porcelain 2>/dev/null | grep -oE '[0-9]+' | head -1)
    
    if [ -z "$POST_EVENTS_RU_ID" ] || [ "$POST_EVENTS_RU_ID" == "0" ]; then
        test_fail "Не удалось создать RU events"
        return 0
    fi
    
    # Установить язык RU
    run_wp_cli "eval 'pll_set_post_language($POST_EVENTS_RU_ID, \"ru\");'" 2>/dev/null
    
    test_pass "RU events создан (ID=$POST_EVENTS_RU_ID, $full_title)"
    test_num=$((test_num + 1))
    
    # [4-5.36] Заполнение ACF полей (6 из 8, без служебных)
    echo -e "${BLUE}[4-5.$test_num]${NC} Заполнение 6 основных ACF полей..."
    
    run_wp_cli "post meta update $POST_EVENTS_RU_ID ссылка_для_кнопки 'https://test.example.com'" 2>/dev/null
    run_wp_cli "post meta update $POST_EVENTS_RU_ID текст_в_кнопке 'Купить билет'" 2>/dev/null
    run_wp_cli "post meta update $POST_EVENTS_RU_ID цвет_блока '#ff0000'" 2>/dev/null
    run_wp_cli "post meta update $POST_EVENTS_RU_ID дата_начала '20250101'" 2>/dev/null
    run_wp_cli "post meta update $POST_EVENTS_RU_ID дата '20250131'" 2>/dev/null
    run_wp_cli "post meta update $POST_EVENTS_RU_ID цвет_текста_события '#ffffff'" 2>/dev/null
    
    test_pass "Заполнены ACF поля: ссылка_для_кнопки, текст_в_кнопке, цвет_блока, дата_начала, дата, цвет_текста_события"
    test_num=$((test_num + 1))
    
    # [4-5.37] Назначение таксономий
    echo -e "${BLUE}[4-5.$test_num]${NC} Назначение таксономии event_types..."
    
    local term_id=$(get_term_id_ru "event_types")
    if [ -n "$term_id" ] && [ "$term_id" != "0" ]; then
        run_wp_cli "post term add $POST_EVENTS_RU_ID event_types $term_id" 2>/dev/null
        test_pass "Назначена таксономия event_types"
    else
        test_info "Таксономия event_types не создана, пропускаем"
    fi
    test_num=$((test_num + 1))
    
    # [4-5.38] ИНТЕРАКТИВ: создание EN перевода
    echo -e "${BLUE}[4-5.$test_num]${NC} Создание EN перевода events..."
    
    create_translation_interactive "events" "$POST_EVENTS_RU_ID" "EVENTS"
    
    # Получить ID EN перевода
    echo -e "${CYAN}   → Поиск EN перевода...${NC}"
    POST_EVENTS_EN_ID=$(run_wp_cli "eval 'echo pll_get_post($POST_EVENTS_RU_ID, \"en\");'" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    
    if [ -z "$POST_EVENTS_EN_ID" ] || [ "$POST_EVENTS_EN_ID" == "0" ]; then
        test_fail "EN перевод не найден! Проверьте, что вы создали перевод."
        echo -e "${YELLOW}   Пропускаем оставшиеся проверки для events${NC}"
        return 0
    fi
    
    test_pass "EN events создан (ID=$POST_EVENTS_EN_ID)"
    test_num=$((test_num + 1))
    
    # [4-5.39] Визуальный чек-лист
    echo -e "${BLUE}[4-5.$test_num]${NC} Визуальная проверка..."
    
    local ru_url="${SITE_URL}/?post_type=events&p=$POST_EVENTS_RU_ID"
    local en_url="${SITE_URL}/en/?post_type=events&p=$POST_EVENTS_EN_ID"
    
    show_visual_checklist "events" "$ru_url" "$en_url"
    
    test_pass "Визуальная проверка завершена"
    test_num=$((test_num + 1))
    
    # [4-5.40] Автопроверка ACF полей
    echo -e "${BLUE}[4-5.$test_num]${NC} Автоматическая проверка 6 ACF полей..."
    
    local fields_to_check=("ссылка_для_кнопки" "текст_в_кнопке" "цвет_блока" "дата_начала" "дата" "цвет_текста_события")
    check_all_acf_fields "$POST_EVENTS_RU_ID" "$POST_EVENTS_EN_ID" "${fields_to_check[@]}"
    test_num=$((test_num + 1))
    
    # [4-5.41] Проверка таксономии
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка таксономии event_types..."
    
    check_taxonomies_copied "$POST_EVENTS_RU_ID" "$POST_EVENTS_EN_ID" "${TAXONOMIES_EVENTS[@]}"
}
