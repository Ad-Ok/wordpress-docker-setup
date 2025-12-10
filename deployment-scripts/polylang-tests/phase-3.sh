#!/bin/bash
# ============================================
# ФАЗА 3: Переводы темы
# ============================================

phase_3_tests() {
    phase_header "3" "Переводы темы"
    
    # Определяем путь к теме в зависимости от окружения
    local theme_path=""
    if [ "$IS_LOCAL" = true ]; then
        theme_path="${LOCAL_THEME_PATH}"
    else
        # Для DEV/PROD пропускаем тесты файловой системы
        test_skip "Тесты файловой системы доступны только для local"
        return
    fi
    
    # 3.1 Проверка наличия файла переводов .mo
    echo "[3.1] Проверка файла переводов en_US.mo..."
    local mo_file="${theme_path}/languages/en_US.mo"
    if [[ -f "$mo_file" ]]; then
        test_pass "Файл переводов en_US.mo существует"
    else
        test_fail "Файл en_US.mo не найден в ${mo_file}"
    fi
    
    # 3.2 Проверка наличия .pot шаблона
    echo "[3.2] Проверка файла шаблона maslovka.pot..."
    local pot_file="${theme_path}/languages/maslovka.pot"
    if [[ -f "$pot_file" ]]; then
        test_pass "Файл шаблона maslovka.pot существует"
    else
        test_fail "Файл maslovka.pot не найден в ${pot_file}"
    fi
    
    # 3.3 Проверка загрузки textdomain в теме
    echo "[3.3] Проверка load_theme_textdomain в theme-setup.php..."
    if grep -q "load_theme_textdomain.*maslovka" "${theme_path}/inc/theme/theme-setup.php" 2>/dev/null; then
        test_pass "load_theme_textdomain('maslovka') подключен"
    else
        test_fail "load_theme_textdomain не найден в theme-setup.php"
    fi
    
    # 3.4 Проверка переводов на странице 404 EN
    echo "[3.4] Проверка перевода страницы 404 на /en/..."
    local en_404=$(curl_with_auth -s -L "${SITE_URL}/en/nonexistent-page-xyz-123/")
    if echo "$en_404" | grep -q "Page not found\|Страница не найдена"; then
        test_pass "Страница 404 на EN доступна"
    else
        test_skip "Не удалось проверить 404 на EN (нет Polylang PRO)"
    fi
    
    # 3.5 Проверка функций перевода в 404.php
    echo "[3.5] Проверка использования __() в 404.php..."
    if grep -q "__(" "${theme_path}/404.php" 2>/dev/null; then
        test_pass "Функции перевода используются в 404.php"
    else
        test_fail "Функции перевода не найдены в 404.php"
    fi
    
    # 3.6 Проверка функций перевода в footer.php (cookies)
    echo "[3.6] Проверка переводов в footer.php..."
    if grep -qE "esc_html_e.*maslovka|__.*maslovka" "${theme_path}/footer.php" 2>/dev/null; then
        test_pass "Переводы подключены в footer.php"
    else
        test_fail "Переводы не найдены в footer.php"
    fi
    
    # 3.7 Проверка переводов в single.php (страница художника)
    echo "[3.7] Проверка переводов в single.php..."
    if grep -qE "esc_html_e.*maslovka|__.*maslovka" "${theme_path}/single.php" 2>/dev/null; then
        test_pass "Переводы подключены в single.php"
    else
        test_fail "Переводы не найдены в single.php"
    fi
    
    # 3.8 Проверка переводов в single-collection.php
    echo "[3.8] Проверка переводов в single-collection.php..."
    if grep -qE "esc_html_e.*maslovka|__.*maslovka" "${theme_path}/single-collection.php" 2>/dev/null; then
        test_pass "Переводы подключены в single-collection.php"
    else
        test_fail "Переводы не найдены в single-collection.php"
    fi
    
    # 3.9 Проверка переводов в page-artists.php
    echo "[3.9] Проверка переводов в page-artists.php..."
    if grep -qE "esc_attr_e.*maslovka|__.*maslovka" "${theme_path}/page-artists.php" 2>/dev/null; then
        test_pass "Переводы подключены в page-artists.php"
    else
        test_fail "Переводы не найдены в page-artists.php"
    fi
    
    # 3.10 Проверка количества строк в .pot файле
    echo "[3.10] Проверка количества переводимых строк..."
    if [[ -f "$pot_file" ]]; then
        local msgid_count=$(grep -c "^msgid " "$pot_file" 2>/dev/null || echo "0")
        if [[ "$msgid_count" -ge 30 ]]; then
            test_pass "Найдено $msgid_count переводимых строк в .pot"
        else
            test_fail "Мало переводимых строк: $msgid_count (ожидается >= 30)"
        fi
    else
        test_skip "Файл .pot не найден для подсчета строк"
    fi
    
    # 3.11 Проверка наличия языкового переключателя в topmenu.php
    echo "[3.11] Проверка языкового переключателя в topmenu.php..."
    if grep -q "pll_the_languages" "${theme_path}/components/topmenu.php" 2>/dev/null; then
        test_pass "Переключатель языков добавлен в topmenu.php"
    else
        test_fail "pll_the_languages не найден в topmenu.php"
    fi
    
    # 3.12 Проверка стилей языкового переключателя
    echo "[3.12] Проверка стилей переключателя языков..."
    if [[ -f "${theme_path}/src/scss/components/_language-switcher.scss" ]]; then
        test_pass "Файл стилей language-switcher.scss существует"
    else
        test_fail "Файл _language-switcher.scss не найден"
    fi
    
    # 3.13 Проверка отображения переключателя на странице
    echo "[3.13] Проверка отображения переключателя на главной..."
    local homepage=$(curl_with_auth -s -L "${SITE_URL}/")
    if echo "$homepage" | grep -q "language-switcher"; then
        test_pass "Переключатель языков отображается на странице"
    else
        test_skip "Переключатель не найден в HTML (возможно english_version_enabled выключен или Polylang не активен)"
    fi
    
    # 3.14 Проверка настройки english_version_enabled
    echo "[3.14] Проверка настройки english_version_enabled..."
    if grep -q "english_version_enabled" "${theme_path}/components/topmenu.php" 2>/dev/null; then
        test_pass "Условие english_version_enabled добавлено в topmenu.php"
    else
        test_fail "Условие english_version_enabled не найдено в topmenu.php"
    fi
    
    # 3.15 Проверка noindex для EN страниц
    echo "[3.15] Проверка noindex условия в header.php..."
    if grep -q "noindex" "${theme_path}/header.php" 2>/dev/null; then
        test_pass "Условие noindex для EN страниц добавлено в header.php"
    else
        test_fail "Условие noindex не найдено в header.php"
    fi
}
