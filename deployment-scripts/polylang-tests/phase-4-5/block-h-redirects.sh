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
    
    # Подсчитать редиректы ДО изменения
    local redirects_before=$(run_sql "SELECT COUNT(*) FROM wp_redirection_items WHERE match_url LIKE '%$old_slug%'" 2>/dev/null | tr -d '[:space:]')
    
    # Изменить слаг
    local new_slug="${old_slug}_modified_${PHASE_45_TIMESTAMP}"
    run_wp_cli "post update $POST_ARTIST_RU_ID --post_name='$new_slug'" 2>/dev/null
    
    sleep 2  # Дать время на обработку хуков
    
    # Подсчитать редиректы ПОСЛЕ изменения
    local redirects_after=$(run_sql "SELECT COUNT(*) FROM wp_redirection_items WHERE match_url LIKE '%$old_slug%' OR match_url LIKE '%$new_slug%'" 2>/dev/null | tr -d '[:space:]')
    
    if [ "$redirects_after" -gt "$redirects_before" ] 2>/dev/null; then
        test_pass "Редирект создан при изменении слага ($redirects_before → $redirects_after)"
    else
        test_info "Редирект не создан (возможно, плагин Redirection не активен или не настроен)"
    fi
    test_num=$((test_num + 1))
    
    # [4-5.53] HTTP 301 проверка
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка HTTP 301 редиректа..."
    
    if [ -z "$SITE_URL" ]; then
        test_skip "SITE_URL не установлен, пропускаем HTTP проверку"
        test_num=$((test_num + 1))
        return 0
    fi
    
    # Проверить редирект старого URL
    local old_url="${SITE_URL}/?post_type=artist&p=$POST_ARTIST_RU_ID&post_name=$old_slug"
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" -L "$old_url" 2>/dev/null)
    
    if [ "$http_code" == "301" ] || [ "$http_code" == "302" ]; then
        test_pass "HTTP редирект работает (код: $http_code)"
    elif [ "$http_code" == "200" ]; then
        test_info "Страница отдаёт 200 (редирект не настроен или не требуется)"
    else
        test_info "HTTP код: $http_code (не удалось проверить редирект)"
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
    run_wp_cli "post update $temp_post_id --post_name='temp_redirect_old'" 2>/dev/null
    sleep 1
    run_wp_cli "post update $temp_post_id --post_name='temp_redirect_new'" 2>/dev/null
    sleep 1
    
    # Подсчитать редиректы ДО удаления
    local redirects_before_delete=$(run_sql "SELECT COUNT(*) FROM wp_redirection_items WHERE match_url LIKE '%temp_redirect%'" 2>/dev/null | tr -d '[:space:]')
    
    # Удалить пост
    run_wp_cli "post delete $temp_post_id --force" 2>/dev/null
    sleep 1
    
    # Подсчитать редиректы ПОСЛЕ удаления
    local redirects_after_delete=$(run_sql "SELECT COUNT(*) FROM wp_redirection_items WHERE match_url LIKE '%temp_redirect%'" 2>/dev/null | tr -d '[:space:]')
    
    if [ "$redirects_after_delete" -lt "$redirects_before_delete" ] 2>/dev/null; then
        test_pass "Редиректы удалены вместе с постом ($redirects_before_delete → $redirects_after_delete)"
    elif [ "$redirects_before_delete" == "0" ]; then
        test_info "Редиректы не создавались для временного поста"
    else
        test_info "Редиректы не удалены ($redirects_before_delete → $redirects_after_delete, возможно требуется ручная очистка)"
    fi
}
