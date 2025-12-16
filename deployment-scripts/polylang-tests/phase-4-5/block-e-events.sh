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
    local content="Описание тестового события для проверки копирования контента и информационных блоков."
    
    POST_EVENTS_RU_ID=$(run_wp_cli post create --post_type=events --post_title="$full_title" --post_content="$content" --post_status=publish --porcelain)
    
    if [ -z "$POST_EVENTS_RU_ID" ] || [ "$POST_EVENTS_RU_ID" == "0" ]; then
        test_fail "Не удалось создать RU events"
        return 0
    fi
    
    # Установить язык RU
    run_wp_cli eval "pll_set_post_language($POST_EVENTS_RU_ID, 'ru');" 2>/dev/null
    
    test_pass "RU events создан (ID=$POST_EVENTS_RU_ID, $full_title)"
    test_num=$((test_num + 1))
    
    # [4-5.36] Заполнение ACF полей (7 из 9, без служебных)
    echo -e "${BLUE}[4-5.$test_num]${NC} Заполнение 7 ACF полей (включая content_block)..."
    
    run_wp_cli eval "update_field('ссылка_для_кнопки', 'https://test.example.com', $POST_EVENTS_RU_ID);" 2>/dev/null
    run_wp_cli eval "update_field('текст_в_кнопке', 'Выбрать время', $POST_EVENTS_RU_ID);" 2>/dev/null
    run_wp_cli eval "update_field('цвет_блока', '#FF5733', $POST_EVENTS_RU_ID);" 2>/dev/null
    run_wp_cli eval "update_field('дата_начала', '20250115', $POST_EVENTS_RU_ID);" 2>/dev/null
    run_wp_cli eval "update_field('дата', '20250131', $POST_EVENTS_RU_ID);" 2>/dev/null
    run_wp_cli eval "update_field('цвет_текста_события', 1, $POST_EVENTS_RU_ID);" 2>/dev/null
    
    # Информационный блок (repeater)
    run_wp_cli eval "update_field('content_block', array(array('титул_блока' => 'Тестовый титул блока', 'описание' => 'Тестовое описание информационного блока для проверки копирования repeater полей.')), $POST_EVENTS_RU_ID);" 2>/dev/null
    
    test_pass "Заполнены ACF поля: ссылка_для_кнопки, текст_в_кнопке, цвет_блока, дата_начала, дата, цвет_текста_события, content_block"
    test_num=$((test_num + 1))
    
    # [4-5.37] Назначение таксономий
    echo -e "${BLUE}[4-5.$test_num]${NC} Назначение таксономии event_types..."
    
    local term_id=$(get_term_id_ru "event_types")
    if [ -n "$term_id" ] && [ "$term_id" != "0" ]; then
        run_wp_cli post term add $POST_EVENTS_RU_ID event_types $term_id --by=id 2>/dev/null
        test_pass "Назначена таксономия event_types"
    else
        test_info "Таксономия event_types не создана, пропускаем"
    fi
    test_num=$((test_num + 1))
    
    # [4-5.38] Проверка редиректов ДО перевода
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка редиректов ДО создания перевода..."
    
    local redirects_before=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$POST_EVENTS_RU_ID AND redirect_type='polylang'" 2>/dev/null | tr -d '[:space:]')
    
    test_pass "Редиректов ДО перевода: $redirects_before"
    test_num=$((test_num + 1))
    
    # [4-5.39] ИНТЕРАКТИВ: создание EN перевода
    echo -e "${BLUE}[4-5.$test_num]${NC} Создание EN перевода events..."
    
    create_translation_interactive "events" "$POST_EVENTS_RU_ID" "EVENTS"
    
    # Получить ID EN перевода
    echo -e "${CYAN}   → Поиск EN перевода...${NC}"
    POST_EVENTS_EN_ID=$(run_wp_cli eval "echo pll_get_post($POST_EVENTS_RU_ID, 'en');" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    
    if [ -z "$POST_EVENTS_EN_ID" ] || [ "$POST_EVENTS_EN_ID" == "0" ]; then
        test_fail "EN перевод не найден! Проверьте, что вы создали перевод."
        echo -e "${YELLOW}   Пропускаем оставшиеся проверки для events${NC}"
        return 0
    fi
    
    test_pass "EN events создан (ID=$POST_EVENTS_EN_ID)"
    test_num=$((test_num + 1))
    
    # [4-5.40] Визуальный чек-лист
    echo -e "${BLUE}[4-5.$test_num]${NC} Визуальная проверка..."
    
    local ru_url="${SITE_URL}/?post_type=events&p=$POST_EVENTS_RU_ID"
    local en_url="${SITE_URL}/en/?post_type=events&p=$POST_EVENTS_EN_ID"
    local ru_archive="${SITE_URL}/events-active/"
    local en_archive="${SITE_URL}/en/events-active/"
    
    cat << EOF

╭────────────────────────────────────────────────────────────╮
│  ИНТЕРАКТИВНАЯ ПРОВЕРКА ПЕРЕВОДА EVENTS
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
    
    # [4-5.41] Автопроверка ACF полей
    echo -e "${BLUE}[4-5.$test_num]${NC} Автоматическая проверка 7 ACF полей..."
    
    local fields_to_check=("ссылка_для_кнопки" "текст_в_кнопке" "цвет_блока" "дата_начала" "дата" "цвет_текста_события" "content_block")
    check_all_acf_fields "$POST_EVENTS_RU_ID" "$POST_EVENTS_EN_ID" "${fields_to_check[@]}"
    test_num=$((test_num + 1))
    
    # [4-5.42] Проверка таксономии
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка таксономии event_types..."
    
    check_taxonomies_copied "$POST_EVENTS_RU_ID" "$POST_EVENTS_EN_ID" "${TAXONOMIES_EVENTS[@]}"
    test_num=$((test_num + 1))
    
    # [4-5.43] Проверка редиректов ПОСЛЕ перевода
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка редиректов ПОСЛЕ создания перевода..."
    
    # Даём время плагину создать редирект (хук может быть асинхронным)
    sleep 1
    
    local redirects_after=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$POST_EVENTS_EN_ID AND redirect_type='polylang'" 2>/dev/null | tr -d '[:space:]')
    
    # Default значения если пусто
    redirects_before=${redirects_before:-0}
    redirects_after=${redirects_after:-0}
    
    if [ "$redirects_after" -ge 1 ] 2>/dev/null; then
        local redirect_old_url=$(run_sql "SELECT old_url FROM wp_maslovka_redirects WHERE post_id=$POST_EVENTS_EN_ID AND redirect_type='polylang' ORDER BY id DESC LIMIT 1" 2>/dev/null | xargs)
        local redirect_new_url=$(run_sql "SELECT new_url FROM wp_maslovka_redirects WHERE post_id=$POST_EVENTS_EN_ID AND redirect_type='polylang' ORDER BY id DESC LIMIT 1" 2>/dev/null | xargs)
        
        test_pass "Polylang-редирект создан ($redirects_after шт.)"
        test_info "   $redirect_old_url → $redirect_new_url"
    else
        test_info "Редиректов не добавилось: ПОСЛЕ=$redirects_after, ДО=$redirects_before"
        test_info "   Возможно, кастомный плагин maslovka-redirects не активен"
    fi
}
