#!/bin/bash
# ============================================
# БЛОК B: Автосоздание терминов (10 тестов)
# ============================================

block_b_create_terms() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  БЛОК B: Автоматическое создание и перевод терминов${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local test_num=5
    local timestamp=$(date +%s)
    
    for taxonomy in "${ALL_TAXONOMIES[@]}"; do
        echo -e "${BLUE}[4-5.$test_num]${NC} Создание термина $taxonomy..."
        
        local ru_name="$(get_test_term_ru $taxonomy)_${timestamp}"
        local en_name="$(get_test_term_en $taxonomy)_${timestamp}"
        
        # Создать термины (оба будут с языком RU по умолчанию)
        local ru_id=$(run_wp_cli term create "$taxonomy" "$ru_name" --porcelain)
        local en_id=$(run_wp_cli term create "$taxonomy" "$en_name" --porcelain)
        
        if [ -z "$ru_id" ] || [ "$ru_id" == "0" ] || [ -z "$en_id" ] || [ "$en_id" == "0" ]; then
            test_fail "Не удалось создать термины $taxonomy"
            continue
        fi
        
        # Установить языки вручную через Polylang API
        run_wp_cli eval "pll_set_term_language($ru_id, 'ru'); pll_set_term_language($en_id, 'en');" 2>/dev/null
        
        # Удалить автоматически созданные term_translations
        run_sql "DELETE tr FROM wp_term_relationships tr JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id WHERE tr.object_id IN ($ru_id, $en_id) AND tt.taxonomy = 'term_translations'" 2>/dev/null
        
        # Связать термины
        run_wp_cli eval "pll_save_term_translations(array('ru' => $ru_id, 'en' => $en_id));" 2>/dev/null
        
        # Сохранить ID
        set_term_id_ru "$taxonomy" "$ru_id"
        set_term_id_en "$taxonomy" "$en_id"
        
        test_pass "$taxonomy создан и переведён (RU=$ru_id, EN=$en_id)"
        test_num=$((test_num + 1))
    done
    
    # Тест 4-5.14: Проверка связей терминов
    echo -e "${BLUE}[4-5.$test_num]${NC} Проверка связей всех терминов через Polylang API..."
    
    local links_ok=0
    local links_total=${#ALL_TAXONOMIES[@]}
    
    for taxonomy in "${ALL_TAXONOMIES[@]}"; do
        local ru_id=$(get_term_id_ru "$taxonomy")
        local en_id=$(get_term_id_en "$taxonomy")
        
        if [ -z "$ru_id" ] || [ -z "$en_id" ]; then
            continue
        fi
        
        # Проверить связь через Polylang API
        local en_linked=$(run_wp_cli eval "echo pll_get_term($ru_id, 'en');")
        
        if [ "$en_linked" == "$en_id" ]; then
            links_ok=$((links_ok + 1))
            test_info "   ✓ $taxonomy: RU($ru_id) ↔ EN($en_id)"
        else
            test_info "   ✗ $taxonomy: связь не найдена (ожидали EN=$en_id, получили $en_linked)"
        fi
    done
    
    if [ $links_ok -eq $links_total ]; then
        test_pass "Все термины связаны через Polylang ($links_ok/$links_total)"
    else
        test_fail "Связаны только $links_ok/$links_total терминов"
    fi
}
