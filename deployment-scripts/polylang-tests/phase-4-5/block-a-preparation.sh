#!/bin/bash
# ============================================
# БЛОК A: Подготовка окружения (4 теста)
# ============================================

block_a_preparation() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  БЛОК A: Подготовка окружения${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Тест 4-5.1: Проверка mu-plugin
    local test_num=1
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка mu-plugin maslovka-polylang-acf.php..."
    
    if [ "$IS_LOCAL" = true ]; then
        if docker compose -f "${LOCAL_PROJECT_ROOT}/docker-compose.yml" exec -T php test -f /var/www/html/wp-content/mu-plugins/maslovka-polylang-acf.php 2>/dev/null; then
            test_pass "mu-plugin maslovka-polylang-acf.php существует"
        else
            test_fail "mu-plugin maslovka-polylang-acf.php не найден"
            echo -e "${RED}   Необходимо создать mu-plugin для копирования ACF полей${NC}"
            return 1
        fi
    else
        if ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" "test -f ${WP_PATH}/wp-content/mu-plugins/maslovka-polylang-acf.php" 2>/dev/null; then
            test_pass "mu-plugin maslovka-polylang-acf.php существует"
        else
            test_fail "mu-plugin maslovka-polylang-acf.php не найден"
            return 1
        fi
    fi
    
    # Тест 4-5.2: Проверка защиты post_meta
    test_num=$((test_num + 1))
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка защиты post_meta (не в sync)..."
    
    POLYLANG_SYNC=$(run_sql "SELECT option_value FROM wp_options WHERE option_name = 'polylang'" 2>/dev/null)
    
    if echo "$POLYLANG_SYNC" | grep -q '"sync"' && echo "$POLYLANG_SYNC" | grep -q '"post_meta"'; then
        test_info "post_meta в настройках sync, проверяем фильтр mu-plugin..."
        
        if [ "$IS_LOCAL" = true ]; then
            FILTER_CHECK=$(docker compose -f "${LOCAL_PROJECT_ROOT}/docker-compose.yml" exec -T php grep -c "maslovka_control_meta_sync" /var/www/html/wp-content/mu-plugins/maslovka-polylang-acf.php 2>/dev/null || echo "0")
        else
            FILTER_CHECK=$(ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" "grep -c 'maslovka_control_meta_sync' ${WP_PATH}/wp-content/mu-plugins/maslovka-polylang-acf.php" 2>/dev/null || echo "0")
        fi
        
        if [ "$FILTER_CHECK" -gt "0" ]; then
            test_pass "Фильтр maslovka_control_meta_sync защищает от перезаписи"
        else
            test_fail "post_meta в sync без защитного фильтра! Риск перезаписи!"
        fi
    else
        test_pass "post_meta НЕ в sync настройках"
    fi
    
    # Тест 4-5.3: Проверка медиабиблиотеки
    test_num=$((test_num + 1))
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка медиабиблиотеки (≥3 изображения)..."
    
    IMAGE_COUNT=$(run_sql "SELECT COUNT(*) FROM wp_posts WHERE post_type='attachment' AND post_mime_type LIKE 'image/%'" 2>/dev/null | tr -d '[:space:]')
    
    if [ "$IMAGE_COUNT" -ge 3 ] 2>/dev/null; then
        test_pass "Доступно $IMAGE_COUNT изображений для тестов"
        
        # Получить 3 случайных изображения для использования в тестах
        TEST_IMAGES=($(run_sql "SELECT ID FROM wp_posts WHERE post_type='attachment' AND post_mime_type LIKE 'image/%' ORDER BY RAND() LIMIT 3" 2>/dev/null | tr '\n' ' '))
        test_info "Выбраны изображения для тестов: ${TEST_IMAGES[*]}"
    else
        test_fail "Недостаточно изображений ($IMAGE_COUNT, нужно ≥3)"
        echo -e "${RED}   Загрузите минимум 3 изображения в медиабиблиотеку${NC}"
        return 1
    fi
    
    # Тест 4-5.4: Информация о структуре данных
    test_num=$((test_num + 1))
    echo -e "${BLUE}[4-5.$test_num]${NC} Информация о структуре проекта..."
    
    echo ""
    echo -e "${CYAN}   Таксономии:${NC}"
    echo -e "   • artist:     ${#TAXONOMIES_ARTIST[@]} таксономий (${TAXONOMIES_ARTIST[*]})"
    echo -e "   • collection: ${#TAXONOMIES_COLLECTION[@]} таксономий (${TAXONOMIES_COLLECTION[*]})"
    echo -e "   • events:     ${#TAXONOMIES_EVENTS[@]} таксономий (${TAXONOMIES_EVENTS[*]})"
    echo -e "   • ВСЕГО:      ${#ALL_TAXONOMIES[@]} таксономий"
    
    echo ""
    echo -e "${CYAN}   ACF поля:${NC}"
    echo -e "   • artist:     ${#ACF_ARTIST[@]} полей"
    echo -e "   • collection: ${#ACF_COLLECTION[@]} полей"
    echo -e "   • events:     ${#ACF_EVENTS[@]} полей"
    echo -e "   • vistavki:   ${#ACF_VISTAVKI[@]} полей"
    
    echo ""
    echo -e "${CYAN}   URL архивов:${NC}"
    echo -e "   • artist: $ARCHIVE_URL_ARTIST"
    echo -e "   • collection: $ARCHIVE_URL_COLLECTION"
    echo -e "   • events: $ARCHIVE_URL_EVENTS"
    echo -e "   • vistavki: $ARCHIVE_URL_VISTAVKI"
    
    test_pass "Структура проекта проанализирована"
}
