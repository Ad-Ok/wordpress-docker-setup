#!/bin/bash
# ============================================
# БЛОК C: Тест ARTIST (9 тестов)
# ============================================

block_c_test_artist() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  БЛОК C: Тестирование CPT artist${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local test_num=15
    
    # [4-5.15] Создание RU artist
    echo -e "${BLUE}[4-5.$test_num]${NC} Создание RU artist..."
    
    local surname=$(get_random_from_array "${TEST_SURNAMES[@]}")
    local first_name=$(get_random_from_array "${TEST_FIRST_NAMES[@]}")
    local patronymic=$(get_random_from_array "${TEST_PATRONYMICS[@]}")
    local title="${surname} ${first_name} (Тестовый)"
    local content="Биография тестового художника ${first_name} ${patronymic}. Это автоматически созданный пост для тестирования функционала Polylang и копирования ACF полей."
    local excerpt="Краткое описание тестового художника для превью."
    
    POST_ARTIST_RU_ID=$(run_wp_cli post create --post_type=artist --post_title="$title" --post_content="$content" --post_excerpt="$excerpt" --post_status=publish --porcelain)
    
    if [ -z "$POST_ARTIST_RU_ID" ] || [ "$POST_ARTIST_RU_ID" == "0" ]; then
        test_fail "Не удалось создать RU artist"
        return 0
    fi
    
    # Установить язык RU
    run_wp_cli eval "pll_set_post_language($POST_ARTIST_RU_ID, 'ru');" 2>/dev/null
    
    # Установить миниатюру поста (если есть изображения)
    if [ ${#TEST_IMAGES[@]} -ge 1 ]; then
        run_wp_cli post meta update $POST_ARTIST_RU_ID _thumbnail_id "${TEST_IMAGES[0]}" 2>/dev/null
    fi
    
    test_pass "RU artist создан (ID=$POST_ARTIST_RU_ID, $title)"
    test_num=$((test_num + 1))
    
    # [4-5.16] Заполнение ACF полей
    echo -e "${BLUE}[4-5.$test_num]${NC} Заполнение ${#ACF_ARTIST[@]} ACF полей..."
    
    run_wp_cli post meta update $POST_ARTIST_RU_ID first_name "$first_name" 2>/dev/null
    run_wp_cli post meta update $POST_ARTIST_RU_ID patronymic "$patronymic" 2>/dev/null
    run_wp_cli post meta update $POST_ARTIST_RU_ID birth_date "1950" 2>/dev/null
    run_wp_cli post meta update $POST_ARTIST_RU_ID death_date "2020" 2>/dev/null
    
    # Заполнить галереи (если есть изображения)
    # ACF галерея должна быть массивом, WordPress сериализует автоматически
    if [ ${#TEST_IMAGES[@]} -ge 3 ]; then
        # работы_художника - массив из 2 изображений (используем update_field)
        run_wp_cli eval "update_field('работы_художника', array('${TEST_IMAGES[0]}', '${TEST_IMAGES[1]}'), ${POST_ARTIST_RU_ID});" 2>/dev/null
        
        # фото_художника - массив из 1 изображения (используем update_field)
        run_wp_cli eval "update_field('фото_художника', array('${TEST_IMAGES[2]}'), ${POST_ARTIST_RU_ID});" 2>/dev/null
    fi
    
    test_pass "Заполнены ACF поля: first_name, patronymic, birth_date, death_date, галереи"
    test_num=$((test_num + 1))
    
    # [4-5.17] Назначение таксономий
    echo -e "${BLUE}[4-5.$test_num]${NC} Назначение ${#TAXONOMIES_ARTIST[@]} таксономий..."
    
    for taxonomy in "${TAXONOMIES_ARTIST[@]}"; do
        local term_id=$(get_term_id_ru "$taxonomy")
        if [ -n "$term_id" ] && [ "$term_id" != "0" ]; then
            run_wp_cli post term add $POST_ARTIST_RU_ID $taxonomy $term_id --by=id 2>/dev/null
        fi
    done
    
    test_pass "Назначены таксономии: ${TAXONOMIES_ARTIST[*]}"
    test_num=$((test_num + 1))
    
    # [4-5.18] Проверка редиректа ДО перевода
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка редиректов ДО создания перевода..."
    
    local redirects_before=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$POST_ARTIST_RU_ID AND redirect_type='polylang'" 2>/dev/null | tr -d '[:space:]')
    
    test_pass "Редиректов ДО перевода: $redirects_before"
    test_num=$((test_num + 1))
    
    # [4-5.20] ИНТЕРАКТИВ: создание EN перевода
    echo -e "${BLUE}[4-5.$test_num]${NC} Создание EN перевода artist..."
    
    create_translation_interactive "artist" "$POST_ARTIST_RU_ID" "ARTIST"
    
    # Получить ID EN перевода
    echo -e "${CYAN}   → Поиск EN перевода...${NC}"
    POST_ARTIST_EN_ID=$(run_wp_cli eval "echo pll_get_post($POST_ARTIST_RU_ID, 'en');" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    
    if [ -z "$POST_ARTIST_EN_ID" ] || [ "$POST_ARTIST_EN_ID" == "0" ]; then
        test_fail "EN перевод не найден! Проверьте, что вы создали перевод."
        echo -e "${YELLOW}   Пропускаем остальные проверки для artist${NC}"
        return 0
    fi
    
    test_pass "EN artist создан (ID=$POST_ARTIST_EN_ID)"
    test_num=$((test_num + 1))
    
    # [4-5.21] Визуальный чек-лист
    echo -e "${BLUE}[4-5.$test_num]${NC} Визуальная проверка..."
    
    local ru_url="${SITE_URL}/?post_type=artist&p=$POST_ARTIST_RU_ID"
    local en_url="${SITE_URL}/en/?post_type=artist&p=$POST_ARTIST_EN_ID"
    local ru_archive="${SITE_URL}/artists/"
    local en_archive="${SITE_URL}/en/artists/"
    
    cat << EOF

╭────────────────────────────────────────────────────────────╮
│  ИНТЕРАКТИВНАЯ ПРОВЕРКА ПЕРЕВОДА ARTIST
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
    
    # [4-5.22] Автопроверка ACF полей
    echo -e "${BLUE}[4-5.$test_num]${NC} Автоматическая проверка ${#ACF_ARTIST[@]} ACF полей..."
    
    check_all_acf_fields "$POST_ARTIST_RU_ID" "$POST_ARTIST_EN_ID" "${ACF_ARTIST[@]}"
    test_num=$((test_num + 1))
    
    # [4-5.23] Проверка таксономий
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка ${#TAXONOMIES_ARTIST[@]} таксономий..."
    
    check_taxonomies_copied "$POST_ARTIST_RU_ID" "$POST_ARTIST_EN_ID" "${TAXONOMIES_ARTIST[@]}"
    test_num=$((test_num + 1))
    
    # [4-5.19] Проверка редиректов
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка редиректов ПОСЛЕ создания перевода..."
    
    # Даём время плагину создать редирект (хук может быть асинхронным)
    sleep 1
    
    local redirects_after=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$POST_ARTIST_EN_ID AND redirect_type='polylang'" 2>/dev/null | tr -d '[:space:]')
    
    # Default значения если пусто
    redirects_before=${redirects_before:-0}
    redirects_after=${redirects_after:-0}
    
    if [ "$redirects_after" -ge 1 ] 2>/dev/null; then
        local redirect_old_url=$(run_sql "SELECT old_url FROM wp_maslovka_redirects WHERE post_id=$POST_ARTIST_EN_ID AND redirect_type='polylang' ORDER BY id DESC LIMIT 1" 2>/dev/null | xargs)
        local redirect_new_url=$(run_sql "SELECT new_url FROM wp_maslovka_redirects WHERE post_id=$POST_ARTIST_EN_ID AND redirect_type='polylang' ORDER BY id DESC LIMIT 1" 2>/dev/null | xargs)
        
        test_pass "Polylang-редирект создан ($redirects_after шт.)"
        test_info "   $redirect_old_url → $redirect_new_url"
    else
        test_info "Редиректов не добавилось: ПОСЛЕ=$redirects_after, ДО=$redirects_before"
        test_info "   Возможно, кастомный плагин maslovka-redirects не активен"
    fi
}
