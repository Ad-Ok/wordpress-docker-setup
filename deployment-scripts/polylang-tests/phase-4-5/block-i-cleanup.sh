#!/bin/bash
# ============================================
# БЛОК I: Очистка (2 теста)
# ============================================

block_i_cleanup() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  БЛОК I: Очистка тестовых данных${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local test_num=53
    
    # [4-5.53] Удаление тестовых постов и их переводов
    echo -e "${BLUE}[4-5.$test_num]${NC} Удаление тестовых постов и переводов..."
    
    local deleted_posts=0
    local deleted_translations=0
    
    local posts_to_delete=(
        "$POST_ARTIST_RU_ID"
        "$POST_COLLECTION_RU_ID"
        "$POST_EVENTS_RU_ID"
        "$POST_VISTAVKI_RU_ID"
    )
    
    # Сначала удаляем RU посты (это удалит и связи post_translations)
    for post_id in "${posts_to_delete[@]}"; do
        if [ -n "$post_id" ] && [ "$post_id" != "0" ]; then
            run_wp_cli post delete $post_id --force 2>/dev/null
            deleted_posts=$((deleted_posts + 1))
        fi
    done
    
    # Теперь удаляем EN переводы (они остались "сиротами")
    local en_posts=(
        "$POST_ARTIST_EN_ID"
        "$POST_COLLECTION_EN_ID"
        "$POST_EVENTS_EN_ID"
        "$POST_VISTAVKI_EN_ID"
    )
    
    for post_id in "${en_posts[@]}"; do
        if [ -n "$post_id" ] && [ "$post_id" != "0" ]; then
            run_wp_cli post delete $post_id --force 2>/dev/null
            deleted_translations=$((deleted_translations + 1))
        fi
    done
    
    test_pass "Удалено $deleted_posts постов + $deleted_translations переводов"
    test_num=$((test_num + 1))
    
    # Удаление переводов медиафайлов (Polylang создает дубликаты)
    echo -e "${BLUE}[4-5.$test_num]${NC} Удаление переводов медиафайлов..."
    
    local deleted_media=0
    
    # Получить все медиафайлы из тестовых изображений
    for img_id in "${TEST_IMAGES[@]}"; do
        if delete_media_translations "$img_id"; then
            deleted_media=$((deleted_media + 1))
        fi
    done
    
    if [ $deleted_media -gt 0 ]; then
        test_pass "Удалено $deleted_media переводов медиафайлов"
    else
        test_info "Переводов медиафайлов не найдено (возможно, не создавались)"
    fi
    test_num=$((test_num + 1))
    
    # [4-5.55] Удаление тестовых терминов
    echo -e "${BLUE}[4-5.$test_num]${NC} Удаление тестовых терминов..."
    
    deleted=0
    
    for taxonomy in "${ALL_TAXONOMIES[@]}"; do
        local ru_id=$(get_term_id_ru "$taxonomy")
        local en_id=$(get_term_id_en "$taxonomy")
        
        if [ -n "$ru_id" ] && [ "$ru_id" != "0" ]; then
            run_wp_cli term delete $taxonomy $ru_id 2>/dev/null
            deleted=$((deleted + 1))
        fi
        
        if [ -n "$en_id" ] && [ "$en_id" != "0" ]; then
            run_wp_cli term delete $taxonomy $en_id 2>/dev/null
            deleted=$((deleted + 1))
        fi
    done
    
    test_pass "Удалено $deleted тестовых терминов"
}
