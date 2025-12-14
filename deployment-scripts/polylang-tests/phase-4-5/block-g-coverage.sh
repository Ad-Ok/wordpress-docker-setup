#!/bin/bash
# ============================================
# БЛОК G: Полнота переводов таксономий (4 теста)
# ============================================

block_g_taxonomy_coverage() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  БЛОК G: Анализ покрытия переводов таксономий${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local test_num=48
    
    # [4-5.48] Подсчёт покрытия для ВСЕХ 9 таксономий
    echo -e "${BLUE}[4-5.$test_num]${NC} Подсчёт покрытия переводов для 9 таксономий..."
    
    declare -A coverage_data
    
    for taxonomy in "${ALL_TAXONOMIES[@]}"; do
        # Подсчитать общее количество терминов
        local total=$(run_sql "SELECT COUNT(DISTINCT t.term_id) FROM wp_terms t JOIN wp_term_taxonomy tt ON t.term_id = tt.term_id WHERE tt.taxonomy = '$taxonomy'" 2>/dev/null | tr -d '[:space:]')
        
        # Подсчитать количество переведённых (есть связь в term_translations)
        local translated=$(run_sql "
            SELECT COUNT(DISTINCT t1.term_id) 
            FROM wp_terms t1
            JOIN wp_term_taxonomy tt1 ON t1.term_id = tt1.term_id
            JOIN wp_term_relationships tr1 ON tt1.term_taxonomy_id = tr1.object_id
            JOIN wp_term_taxonomy tt2 ON tr1.term_taxonomy_id = tt2.term_taxonomy_id
            WHERE tt1.taxonomy = '$taxonomy'
            AND tt2.taxonomy = 'term_translations'
        " 2>/dev/null | tr -d '[:space:]')
        
        coverage_data[$taxonomy]="$translated/$total"
    done
    
    test_pass "Покрытие подсчитано для всех таксономий"
    test_num=$((test_num + 1))
    
    # [4-5.49] Итоговый отчёт (таблица)
    echo -e "${BLUE}[4-5.$test_num]${NC} Итоговый отчёт покрытия переводов..."
    echo ""
    echo -e "${CYAN}╔════════════════════╦═══════════╦════════════╗${NC}"
    echo -e "${CYAN}║ Таксономия         ║ Переведено║ Покрытие % ║${NC}"
    echo -e "${CYAN}╠════════════════════╬═══════════╬════════════╣${NC}"
    
    local total_translated=0
    local total_terms=0
    
    for taxonomy in "${ALL_TAXONOMIES[@]}"; do
        local data="${coverage_data[$taxonomy]}"
        local translated=$(echo "$data" | cut -d'/' -f1)
        local total=$(echo "$data" | cut -d'/' -f2)
        
        local percentage=0
        if [ "$total" -gt 0 ] 2>/dev/null; then
            percentage=$((translated * 100 / total))
        fi
        
        total_translated=$((total_translated + translated))
        total_terms=$((total_terms + total))
        
        printf "${CYAN}║${NC} %-18s ${CYAN}║${NC} %4s/%-4s ${CYAN}║${NC} %9s%% ${CYAN}║${NC}\n" "$taxonomy" "$translated" "$total" "$percentage"
    done
    
    echo -e "${CYAN}╠════════════════════╬═══════════╬════════════╣${NC}"
    
    local overall_percentage=0
    if [ "$total_terms" -gt 0 ] 2>/dev/null; then
        overall_percentage=$((total_translated * 100 / total_terms))
    fi
    
    printf "${CYAN}║${NC} ${GREEN}ИТОГО${NC}              ${CYAN}║${NC} %4s/%-4s ${CYAN}║${NC} ${GREEN}%9s%%${NC} ${CYAN}║${NC}\n" "$total_translated" "$total_terms" "$overall_percentage"
    echo -e "${CYAN}╚════════════════════╩═══════════╩════════════╝${NC}"
    echo ""
    
    test_pass "Итоговый отчёт: $overall_percentage% терминов переведено"
    test_num=$((test_num + 1))
    
    # [4-5.50] TOP-10 непереведённых терминов
    echo -e "${BLUE}[4-5.$test_num]${NC} TOP-10 непереведённых терминов..."
    
    local untranslated=$(run_sql "
        SELECT tt.taxonomy, t.name, tt.count
        FROM wp_terms t
        JOIN wp_term_taxonomy tt ON t.term_id = tt.term_id
        LEFT JOIN wp_term_relationships tr ON tt.term_taxonomy_id = tr.object_id
        LEFT JOIN wp_term_taxonomy tt2 ON tr.term_taxonomy_id = tt2.term_taxonomy_id AND tt2.taxonomy = 'term_translations'
        WHERE tt.taxonomy IN ('$(echo "${ALL_TAXONOMIES[@]}" | sed "s/ /','/g")')
        AND tt2.term_taxonomy_id IS NULL
        ORDER BY tt.count DESC
        LIMIT 10
    " 2>/dev/null)
    
    if [ -n "$untranslated" ]; then
        echo ""
        echo -e "${YELLOW}   Самые используемые непереведённые термины:${NC}"
        echo "$untranslated" | while IFS=$'\t' read -r taxonomy name count; do
            echo -e "   • ${YELLOW}$taxonomy${NC}: $name (используется $count раз)"
        done
        echo ""
        test_pass "Найдено непереведённых терминов для анализа"
    else
        test_pass "Все термины переведены или не используются"
    fi
    test_num=$((test_num + 1))
    
    # [4-5.51] Рекомендации по переводам
    echo -e "${BLUE}[4-5.$test_num]${NC} Рекомендации по улучшению покрытия..."
    
    echo ""
    echo -e "${CYAN}   РЕКОМЕНДАЦИИ:${NC}"
    
    local needs_attention=0
    for taxonomy in "${ALL_TAXONOMIES[@]}"; do
        local data="${coverage_data[$taxonomy]}"
        local translated=$(echo "$data" | cut -d'/' -f1)
        local total=$(echo "$data" | cut -d'/' -f2)
        
        local percentage=0
        if [ "$total" -gt 0 ] 2>/dev/null; then
            percentage=$((translated * 100 / total))
        fi
        
        if [ "$percentage" -lt 50 ] 2>/dev/null && [ "$total" -gt 0 ] 2>/dev/null; then
            echo -e "   ${RED}⚠${NC}  $taxonomy: только $percentage% переведено — требует внимания!"
            needs_attention=$((needs_attention + 1))
        elif [ "$percentage" -lt 80 ] 2>/dev/null && [ "$total" -gt 0 ] 2>/dev/null; then
            echo -e "   ${YELLOW}⚡${NC} $taxonomy: $percentage% переведено — рекомендуется дополнить"
        fi
    done
    
    if [ $needs_attention -eq 0 ]; then
        echo -e "   ${GREEN}✓${NC}  Все таксономии имеют хорошее покрытие переводов"
    fi
    echo ""
    
    test_pass "Анализ покрытия завершён"
}
