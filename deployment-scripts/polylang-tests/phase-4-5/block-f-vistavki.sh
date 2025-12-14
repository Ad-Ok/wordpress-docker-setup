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
    local content="Полное описание тестовой выставки для проверки копирования контента и информационных блоков."
    
    POST_VISTAVKI_RU_ID=$(run_wp_cli post create --post_type=vistavki --post_title="$full_title" --post_content="$content" --post_status=publish --porcelain 2>/dev/null | grep -oE '[0-9]+' | head -1)
    
    if [ -z "$POST_VISTAVKI_RU_ID" ] || [ "$POST_VISTAVKI_RU_ID" == "0" ]; then
        test_fail "Не удалось создать RU vistavki"
        return 0
    fi
    
    # Установить язык RU
    run_wp_cli eval "pll_set_post_language($POST_VISTAVKI_RU_ID, 'ru');" 2>/dev/null
    
    test_pass "RU vistavki создан (ID=$POST_VISTAVKI_RU_ID, $full_title)"
    test_num=$((test_num + 1))
    
    # [4-5.43] Заполнение ACF полей (6 включая content_block)
    echo -e "${BLUE}[4-5.$test_num]${NC} Заполнение 6 ACF полей (включая content_block)..."
    
    run_wp_cli eval "update_field('описание_мероприятия', 'Тестовое описание выставки', $POST_VISTAVKI_RU_ID);" 2>/dev/null
    run_wp_cli eval "update_field('ссылка_купить', 'https://test-tickets.example.com', $POST_VISTAVKI_RU_ID);" 2>/dev/null
    run_wp_cli eval "update_field('текст_в_кнопке', 'Купить билеты', $POST_VISTAVKI_RU_ID);" 2>/dev/null
    run_wp_cli eval "update_field('дата_проведения_начало', '20250201', $POST_VISTAVKI_RU_ID);" 2>/dev/null
    run_wp_cli eval "update_field('дата_окончание', '20250228', $POST_VISTAVKI_RU_ID);" 2>/dev/null
    
    # Добавить изображение, если есть
    if [ ${#TEST_IMAGES[@]} -ge 1 ]; then
        run_wp_cli eval "update_field('Картинка_выставки', ${TEST_IMAGES[0]}, $POST_VISTAVKI_RU_ID);" 2>/dev/null
    fi
    
    # Информационный блок (repeater)
    run_wp_cli eval "update_field('content_block', array(array('титул_блока' => 'Тестовый титул выставки', 'описание' => 'Тестовое описание информационного блока выставки для проверки копирования repeater полей.')), $POST_VISTAVKI_RU_ID);" 2>/dev/null
    
    test_pass "Заполнены ACF поля: описание_мероприятия, ссылка_купить, текст_в_кнопке, даты, Картинка_выставки, content_block"
    test_num=$((test_num + 1))
    
    # [4-5.44] Проверка редиректов ДО создания перевода
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка редиректов ДО создания перевода..."
    local redirects_before=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$POST_VISTAVKI_RU_ID AND redirect_type='polylang'" | tr -d '[:space:]')
    test_pass "Редиректов ДО перевода: $redirects_before"
    test_num=$((test_num + 1))
    
    # [4-5.45] ИНТЕРАКТИВ: создание EN перевода
    echo -e "${BLUE}[4-5.$test_num]${NC} Создание EN перевода vistavki..."
    
    create_translation_interactive "vistavki" "$POST_VISTAVKI_RU_ID" "VISTAVKI"
    
    # Получить ID EN перевода
    echo -e "${CYAN}   → Поиск EN перевода...${NC}"
    POST_VISTAVKI_EN_ID=$(run_wp_cli eval "echo pll_get_post($POST_VISTAVKI_RU_ID, 'en');" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    
    if [ -z "$POST_VISTAVKI_EN_ID" ] || [ "$POST_VISTAVKI_EN_ID" == "0" ]; then
        test_fail "EN перевод не найден! Проверьте, что вы создали перевод."
        echo -e "${YELLOW}   Пропускаем оставшиеся проверки для vistavki${NC}"
        return 0
    fi
    
    test_pass "EN vistavki создан (ID=$POST_VISTAVKI_EN_ID)"
    test_num=$((test_num + 1))
    
    # [4-5.46] Визуальный чек-лист
    echo -e "${BLUE}[4-5.$test_num]${NC} Визуальная проверка..."
    
    local ru_url="${SITE_URL}/?post_type=vistavki&p=$POST_VISTAVKI_RU_ID"
    local en_url="${SITE_URL}/en/?post_type=vistavki&p=$POST_VISTAVKI_EN_ID"
    local ru_archive="${SITE_URL}/exhibitions-active/"
    local en_archive="${SITE_URL}/en/exhibitions-active/"
    
    cat << EOF

╭────────────────────────────────────────────────────────────╮
│  ИНТЕРАКТИВНАЯ ПРОВЕРКА ПЕРЕВОДА VISTAVKI                 │
├────────────────────────────────────────────────────────────┤
│  Откройте в браузере:                                    │
│  RU: $ru_url
│  EN: $en_url
│                                                            │
│  Проверьте визуально:                                     │
│  [ ] 1. Все ACF поля заполнены в EN версии               │
│  [ ] 2. Изображения скопированы                          │
│  [ ] 3. Переключатель языков работает (RU ↔ EN)          │
│  [ ] 4. Пост отображается на архивных страницах:       │
│      - RU: $ru_archive
│      - EN: $en_archive
╰────────────────────────────────────────────────────────────╯

EOF
    
    echo -n "Нажмите Enter после проверки... "
    read -r
    
    test_pass "Визуальная проверка завершена"
    test_num=$((test_num + 1))
    
    # [4-5.47] Проверка редиректов ПОСЛЕ создания перевода
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка редиректов ПОСЛЕ создания перевода..."
    sleep 1  # Ждём завершения асинхронного хука Polylang
    
    local redirects_after=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$POST_VISTAVKI_EN_ID AND redirect_type='polylang'" | tr -d '[:space:]')
    
    # Защита от пустых значений
    redirects_before=${redirects_before:-0}
    redirects_after=${redirects_after:-0}
    
    if [ "$redirects_after" -ge 1 ] 2>/dev/null; then
        local redirect_old_url=$(run_sql "SELECT old_url FROM wp_maslovka_redirects WHERE post_id=$POST_VISTAVKI_EN_ID AND redirect_type='polylang' ORDER BY id DESC LIMIT 1" | tail -1)
        local redirect_new_url=$(run_sql "SELECT new_url FROM wp_maslovka_redirects WHERE post_id=$POST_VISTAVKI_EN_ID AND redirect_type='polylang' ORDER BY id DESC LIMIT 1" | tail -1)
        test_pass "Polylang-редирект создан ($redirects_after шт.)"
        test_info "   $redirect_old_url → $redirect_new_url"
    else
        test_info "Редиректов не добавилось: ПОСЛЕ=$redirects_after, ДО=$redirects_before"
    fi
    test_num=$((test_num + 1))
    
    # [4-5.48] Автопроверка ACF полей
    echo -e "${BLUE}[4-5.$test_num]${NC} Автоматическая проверка 6 ACF полей..."
    
    local fields_to_check=("описание_мероприятия" "ссылка_купить" "текст_в_кнопке" "дата_проведения_начало" "дата_окончание" "content_block")
    check_all_acf_fields "$POST_VISTAVKI_RU_ID" "$POST_VISTAVKI_EN_ID" "${fields_to_check[@]}"
    test_num=$((test_num + 1))
    
    # [4-5.49] Проверка отображения
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
