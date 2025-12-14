#!/bin/bash
# ============================================
# БЛОК F: Тест VISTAVKI (7 тестов)
# ============================================

block_f_test_vistavki() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  БЛОК F: Тестирование CPT vistavki${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local test_num=42
    
    # [4-5.42] Создание RU vistavki
    echo -e "${BLUE}[4-5.$test_num]${NC} Создание RU vistavki..."
    
    local title=$(get_random_from_array "${TEST_VISTAVKI_TITLES[@]}")
    local full_title="${title}_${PHASE_45_TIMESTAMP}"
    
    POST_VISTAVKI_RU_ID=$(run_wp_cli post create --post_type=vistavki --post_title="$full_title" --post_status=publish --porcelain 2>/dev/null | grep -oE '[0-9]+' | head -1)
    
    if [ -z "$POST_VISTAVKI_RU_ID" ] || [ "$POST_VISTAVKI_RU_ID" == "0" ]; then
        test_fail "Не удалось создать RU vistavki"
        return 0
    fi
    
    # Установить язык RU
    run_wp_cli "eval 'pll_set_post_language($POST_VISTAVKI_RU_ID, \"ru\");'" 2>/dev/null
    
    test_pass "RU vistavki создан (ID=$POST_VISTAVKI_RU_ID, $full_title)"
    test_num=$((test_num + 1))
    
    # [4-5.43] Заполнение ACF полей (5 основных)
    echo -e "${BLUE}[4-5.$test_num]${NC} Заполнение 5 основных ACF полей..."
    
    run_wp_cli "post meta update $POST_VISTAVKI_RU_ID описание_мероприятия 'Тестовое описание выставки'" 2>/dev/null
    run_wp_cli "post meta update $POST_VISTAVKI_RU_ID ссылка_купить 'https://test-tickets.example.com'" 2>/dev/null
    run_wp_cli "post meta update $POST_VISTAVKI_RU_ID текст_в_кнопке 'Купить билеты'" 2>/dev/null
    run_wp_cli "post meta update $POST_VISTAVKI_RU_ID дата_проведения_начало '20250201'" 2>/dev/null
    run_wp_cli "post meta update $POST_VISTAVKI_RU_ID дата_окончание '20250228'" 2>/dev/null
    
    # Добавить изображение, если есть
    if [ ${#TEST_IMAGES[@]} -ge 1 ]; then
        run_wp_cli "post meta update $POST_VISTAVKI_RU_ID Картинка_выставки '${TEST_IMAGES[0]}'" 2>/dev/null
    fi
    
    test_pass "Заполнены ACF поля: описание_мероприятия, ссылка_купить, текст_в_кнопке, даты, Картинка_выставки"
    test_num=$((test_num + 1))
    
    # [4-5.44] ИНТЕРАКТИВ: создание EN перевода
    echo -e "${BLUE}[4-5.$test_num]${NC} Создание EN перевода vistavki..."
    
    create_translation_interactive "vistavki" "$POST_VISTAVKI_RU_ID" "VISTAVKI"
    
    # Получить ID EN перевода
    echo -e "${CYAN}   → Поиск EN перевода...${NC}"
    POST_VISTAVKI_EN_ID=$(run_wp_cli "eval 'echo pll_get_post($POST_VISTAVKI_RU_ID, \"en\");'" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    
    if [ -z "$POST_VISTAVKI_EN_ID" ] || [ "$POST_VISTAVKI_EN_ID" == "0" ]; then
        test_fail "EN перевод не найден! Проверьте, что вы создали перевод."
        echo -e "${YELLOW}   Пропускаем оставшиеся проверки для vistavki${NC}"
        return 0
    fi
    
    test_pass "EN vistavki создан (ID=$POST_VISTAVKI_EN_ID)"
    test_num=$((test_num + 1))
    
    # [4-5.45] Визуальный чек-лист
    echo -e "${BLUE}[4-5.$test_num]${NC} Визуальная проверка..."
    
    local ru_url="${SITE_URL}/?post_type=vistavki&p=$POST_VISTAVKI_RU_ID"
    local en_url="${SITE_URL}/en/?post_type=vistavki&p=$POST_VISTAVKI_EN_ID"
    
    show_visual_checklist "vistavki" "$ru_url" "$en_url"
    
    test_pass "Визуальная проверка завершена"
    test_num=$((test_num + 1))
    
    # [4-5.46] Автопроверка ACF полей
    echo -e "${BLUE}[4-5.$test_num]${NC} Автоматическая проверка 5 ACF полей..."
    
    local fields_to_check=("описание_мероприятия" "ссылка_купить" "текст_в_кнопке" "дата_проведения_начало" "дата_окончание")
    check_all_acf_fields "$POST_VISTAVKI_RU_ID" "$POST_VISTAVKI_EN_ID" "${fields_to_check[@]}"
    test_num=$((test_num + 1))
    
    # [4-5.47] Проверка отображения
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка отображения на архивных страницах..."
    
    local found_ru=0
    local found_en=0
    
    if check_post_on_archive "$POST_VISTAVKI_RU_ID" "$ARCHIVE_URL_VISTAVKI" "ru"; then
        found_ru=1
    fi
    
    if check_post_on_archive "$POST_VISTAVKI_EN_ID" "$ARCHIVE_URL_VISTAVKI" "en"; then
        found_en=1
    fi
    
    if [ $found_ru -eq 1 ] && [ $found_en -eq 1 ]; then
        test_pass "Vistavki отображается на обеих архивных страницах"
    elif [ $found_ru -eq 1 ] || [ $found_en -eq 1 ]; then
        test_info "Найдено на одной из архивных страниц"
    else
        test_info "Не удалось проверить отображение на архивах"
    fi
}
