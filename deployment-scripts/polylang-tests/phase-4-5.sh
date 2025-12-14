#!/bin/bash
# ============================================
# ФАЗА 4-5: Кастомные плагины и демо-контент
# ============================================
# Комплексное тестирование автокопирования ACF полей
# при переводе постов и терминов таксономий

# Загрузить общие функции и данные
source "${SCRIPT_DIR}/polylang-tests/phase-4-5/common.sh"

# Загрузить модули тестов
source "${SCRIPT_DIR}/polylang-tests/phase-4-5/block-a-preparation.sh"
source "${SCRIPT_DIR}/polylang-tests/phase-4-5/block-b-terms.sh"
source "${SCRIPT_DIR}/polylang-tests/phase-4-5/block-c-artist.sh"
source "${SCRIPT_DIR}/polylang-tests/phase-4-5/block-d-collection.sh"
source "${SCRIPT_DIR}/polylang-tests/phase-4-5/block-e-events.sh"
source "${SCRIPT_DIR}/polylang-tests/phase-4-5/block-f-vistavki.sh"
source "${SCRIPT_DIR}/polylang-tests/phase-4-5/block-g-coverage.sh"
source "${SCRIPT_DIR}/polylang-tests/phase-4-5/block-h-redirects.sh"
source "${SCRIPT_DIR}/polylang-tests/phase-4-5/block-i-cleanup.sh"

# ============================================
# ГЛАВНАЯ ФУНКЦИЯ ФАЗЫ
# ============================================

phase_4_5_tests() {
    phase_header "4-5" "Кастомные плагины и демо-контент"
    
    if [ "$WP_CLI_AVAILABLE" = false ]; then
        test_skip "Фаза 4-5 требует WP-CLI для создания тестовых постов и терминов"
        return 0
    fi
    
    # Инициализация переменных
    init_phase_4_5_vars
    
    # Блок A: Подготовка
    block_a_preparation
    
    # Блок B: Автосоздание терминов
    block_b_create_terms
    
    # Блок C: Тест artist
    block_c_test_artist
    
    # Блок D: Тест collection
    # block_d_test_collection
    
    # Блок E: Тест events
    # block_e_test_events
    
    # Блок F: Тест vistavki
    # block_f_test_vistavki
    
    # Блок G: Полнота переводов таксономий
    # block_g_taxonomy_coverage
    
    # Блок H: Редиректы
    # block_h_redirects
    
    # Блок I: Очистка
    block_i_cleanup
}
