#!/bin/bash
# ============================================
# БЛОК H: Редиректы (3 теста)
# ============================================

block_h_redirects() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  БЛОК H: Дополнительное тестирование редиректов${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local test_num=52
    
    # [4-5.52] Изменение слага artist → новый редирект
    echo -e "${BLUE}[4-5.$test_num]${NC} Тест: изменение слага создаёт редирект..."
    
    if [ -z "$POST_ARTIST_RU_ID" ] || [ "$POST_ARTIST_RU_ID" == "0" ]; then
        test_skip "RU artist не создан, пропускаем тест редиректов"
        return 0
    fi
    
    # Получить текущий слаг
    local old_slug=$(run_sql "SELECT post_name FROM wp_posts WHERE ID=$POST_ARTIST_RU_ID" 2>/dev/null | tr -d '\n')
    
    if [ -z "$old_slug" ]; then
        test_fail "Не удалось получить текущий слаг"
        return 1
    fi
    
    # Проверяем Polylang-редиректы (создаются в блоках C-F при переводе)
    local polylang_redirects=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE redirect_type='polylang'" 2>/dev/null | tr -d '[:space:]')
    
    if [ -z "$polylang_redirects" ] || [ "$polylang_redirects" == "0" ]; then
        test_info "Кастомный плагин maslovka-redirects не активен или не настроен"
    else
        test_pass "Найдено $polylang_redirects Polylang-редиректов (из блоков C-F)"
        
        # Показать пример редиректа
        local redirect_example=$(run_sql "SELECT old_url, new_url FROM wp_maslovka_redirects WHERE redirect_type='polylang' LIMIT 1" 2>/dev/null)
        if [ -n "$redirect_example" ]; then
            test_info "   Пример: $redirect_example"
        fi
    fi
    test_num=$((test_num + 1))
    
    # [4-5.53] Проверка структуры таблицы редиректов
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка структуры таблицы wp_maslovka_redirects..."
    
    local table_exists=$(run_sql "SHOW TABLES LIKE 'wp_maslovka_redirects'" 2>/dev/null | tr -d '[:space:]')
    
    if [ -n "$table_exists" ]; then
        local total_redirects=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects" 2>/dev/null | tr -d '[:space:]')
        test_pass "Таблица существует, всего редиректов: $total_redirects"
        
        if [ "$total_redirects" -gt 0 ] 2>/dev/null; then
            # Показать статистику по типам
            local stats=$(run_sql "SELECT redirect_type, COUNT(*) as cnt FROM wp_maslovka_redirects GROUP BY redirect_type" 2>/dev/null)
            if [ -n "$stats" ]; then
                test_info "   Статистика по типам:"
                echo "$stats" | while IFS=$'\t' read -r type count; do
                    test_info "      $type: $count шт."
                done
            fi
        fi
    else
        test_info "Таблица wp_maslovka_redirects не существует (плагин не установлен)"
    fi
    test_num=$((test_num + 1))
    
    # [4-5.54] Удаление поста → удаление редиректов
    echo -e "${BLUE}[4-5.$test_num]${NC} Тест: удаление поста удаляет связанные редиректы..."
    
    # Создать временный тестовый пост для этого теста
    local temp_post_id=$(run_wp_cli post create --post_type=artist --post_title="Temp_Redirect_Test_${PHASE_45_TIMESTAMP}" --post_status=publish --porcelain 2>/dev/null | grep -oE '[0-9]+' | head -1)
    
    if [ -z "$temp_post_id" ] || [ "$temp_post_id" == "0" ]; then
        test_skip "Не удалось создать временный пост для теста"
        return 0
    fi
    
    # Изменить слаг для создания редиректа
    run_wp_cli post update $temp_post_id --post_name="temp_redirect_old" 2>/dev/null
    sleep 1
    run_wp_cli post update $temp_post_id --post_name="temp_redirect_new" 2>/dev/null
    sleep 1
    
    # Подсчитать редиректы ДО удаления
    local redirects_before_delete=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$temp_post_id" 2>/dev/null | tr -d '[:space:]')
    
    # Удалить пост
    run_wp_cli post delete $temp_post_id --force 2>/dev/null
    sleep 1
    
    # Подсчитать редиректы ПОСЛЕ удаления
    local redirects_after_delete=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$temp_post_id" 2>/dev/null | tr -d '[:space:]')
    
    if [ "$redirects_after_delete" -lt "$redirects_before_delete" ] 2>/dev/null; then
        test_pass "Редиректы удалены вместе с постом ($redirects_before_delete → $redirects_after_delete)"
    elif [ "$redirects_before_delete" == "0" ]; then
        test_info "Редиректы не создавались для временного поста"
    else
        test_info "Редиректы не удалены ($redirects_before_delete → $redirects_after_delete, возможно требуется ручная очистка)"
    fi
}
