#!/bin/bash
# ============================================
# Общие функции и данные для фазы 4-5
# ============================================

# ============================================
# РЕАЛЬНЫЕ ДАННЫЕ ПРОЕКТА
# ============================================

# === Таксономии (из файлов inc/taxonomies/) ===
TAXONOMIES_ARTIST=("art_form" "period" "genres" "styles" "artist_group" "education")
TAXONOMIES_COLLECTION=("art_form" "period" "genres" "styles" "techniques" "materials")
TAXONOMIES_EVENTS=("event_types")

ALL_TAXONOMIES=("art_form" "period" "genres" "styles" "techniques" "materials" "artist_group" "education" "event_types")

# === ACF поля (из файлов inc/acf-fields/) ===
ACF_ARTIST=("first_name" "patronymic" "birth_date" "death_date" "работы_художника" "фото_художника")
ACF_COLLECTION=("artist_id" "year_created" "current_location" "height" "width" "depth")
ACF_EVENTS=("ссылка_для_кнопки" "текст_в_кнопке" "цвет_блока" "дата_начала" "дата" "цвет_текста_события" "content_block")
ACF_VISTAVKI=("описание_мероприятия" "ссылка_купить" "текст_в_кнопке" "Картинка_выставки" "content_block")

# === URL архивов ===
ARCHIVE_URL_ARTIST="/artists/"
ARCHIVE_URL_COLLECTION="/collection/"
ARCHIVE_URL_EVENTS="/events-active/"
ARCHIVE_URL_VISTAVKI="/exhibitions-active/"

# === Тестовые данные ===
TEST_SURNAMES=("Тестов" "Проверкин" "Автоматов")
TEST_FIRST_NAMES=("Иван" "Пётр" "Сергей")
TEST_PATRONYMICS=("Иванович" "Петрович" "Сергеевич")

TEST_COLLECTION_TITLES=("Тестовый_Пейзаж" "Проверочный_Портрет")
TEST_EVENTS_TITLES=("Тестовое_Событие" "Проверочное_Мероприятие")
TEST_VISTAVKI_TITLES=("Тестовая_Выставка" "Проверочная_Экспозиция")

# Названия терминов (RU и EN переводы)
TEST_TERM_RU_art_form="Тестовая_Форма_Искусства"
TEST_TERM_RU_period="Тестовый_Период"
TEST_TERM_RU_genres="Тестовый_Жанр"
TEST_TERM_RU_styles="Тестовый_Стиль"
TEST_TERM_RU_techniques="Тестовая_Техника"
TEST_TERM_RU_materials="Тестовый_Материал"
TEST_TERM_RU_artist_group="Тестовая_Группа"
TEST_TERM_RU_education="Тестовое_Образование"
TEST_TERM_RU_event_types="Тестовый_Тип_События"

TEST_TERM_EN_art_form="Test_Art_Form"
TEST_TERM_EN_period="Test_Period"
TEST_TERM_EN_genres="Test_Genre"
TEST_TERM_EN_styles="Test_Style"
TEST_TERM_EN_techniques="Test_Technique"
TEST_TERM_EN_materials="Test_Material"
TEST_TERM_EN_artist_group="Test_Group"
TEST_TERM_EN_education="Test_Education"
TEST_TERM_EN_event_types="Test_Event_Type"

# ============================================
# ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
# ============================================

# ID созданных терминов (будем использовать переменные TERM_ID_RU_taxonomy и TERM_ID_EN_taxonomy)

# ID созданных постов
POST_ARTIST_RU_ID=""
POST_ARTIST_EN_ID=""
POST_COLLECTION_RU_ID=""
POST_COLLECTION_EN_ID=""
POST_EVENTS_RU_ID=""
POST_EVENTS_EN_ID=""
POST_VISTAVKI_RU_ID=""
POST_VISTAVKI_EN_ID=""

# ID изображений для тестов
TEST_IMAGES=()

# Timestamp для уникальных имен
PHASE_45_TIMESTAMP=""

# ============================================
# ФУНКЦИИ ИНИЦИАЛИЗАЦИИ
# ============================================

init_phase_4_5_vars() {
    PHASE_45_TIMESTAMP=$(date +%s)
    
    # Очистить массивы
    TEST_IMAGES=()
    
    # Очистить ID постов
    POST_ARTIST_RU_ID=""
    POST_ARTIST_EN_ID=""
    POST_COLLECTION_RU_ID=""
    POST_COLLECTION_EN_ID=""
    POST_EVENTS_RU_ID=""
    POST_EVENTS_EN_ID=""
    POST_VISTAVKI_RU_ID=""
    POST_VISTAVKI_EN_ID=""
}

# ============================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ============================================

# Проверить копирование ACF поля
check_acf_field_copied() {
    local ru_post_id="$1"
    local en_post_id="$2"
    local field_name="$3"
    local field_label="$4"  # Опционально, для красивого вывода
    
    if [ -z "$field_label" ]; then
        field_label="$field_name"
    fi
    
    local ru_value=$(run_sql "SELECT meta_value FROM wp_postmeta WHERE post_id=$ru_post_id AND meta_key='$field_name' LIMIT 1" 2>/dev/null | tr -d '\n')
    local en_value=$(run_sql "SELECT meta_value FROM wp_postmeta WHERE post_id=$en_post_id AND meta_key='$field_name' LIMIT 1" 2>/dev/null | tr -d '\n')
    
    if [ -z "$ru_value" ]; then
        test_info "   ⊘ $field_label: не заполнено в RU (пропускаем)"
        return 0
    fi
    
    if [ "$ru_value" = "$en_value" ]; then
        test_info "   ✓ $field_label: скопировано"
        return 0
    else
        # Специальная проверка для artist_id (post-to-post relationship)
        # Polylang копирует связь, но с EN версией artist
        if [ "$field_name" = "artist_id" ]; then
            # Проверяем, что EN значение - это перевод RU artist
            if [ -n "$en_value" ] && [ "$en_value" != "0" ]; then
                local expected_en_artist=$(run_wp_cli eval "echo pll_get_post($ru_value, 'en');" 2>/dev/null | grep -oE '[0-9]+' | head -1)
                if [ "$en_value" = "$expected_en_artist" ]; then
                    test_info "   ✓ $field_label: скопировано с переводом (RU=$ru_value → EN=$en_value)"
                    return 0
                else
                    test_info "   ✗ $field_label: ссылка не на перевод (EN=$en_value, ожидалось=$expected_en_artist)"
                    return 1
                fi
            else
                test_info "   ✗ $field_label: не заполнено в EN"
                return 1
            fi
        fi
        
        # Для галерей (массивов) проверяем количество элементов, а не ID
        # Polylang дублирует медиафайлы, поэтому ID будут разные
        if [[ "$field_name" =~ галерея|gallery|работы|фото ]] || [[ "$ru_value" =~ ^a:[0-9]+:\{ ]]; then
            # Это сериализованный массив - извлекаем количество из "a:2:{...}"
            local ru_count=$(echo "$ru_value" | grep -oE '^a:[0-9]+' | grep -oE '[0-9]+' | head -1)
            local en_count=$(echo "$en_value" | grep -oE '^a:[0-9]+' | grep -oE '[0-9]+' | head -1)
            
            test_info "   📊 $field_label: RU=$ru_count элементов, EN=$en_count элементов"
            
            if [ "$ru_count" = "$en_count" ] && [ -n "$ru_count" ] && [ "$ru_count" != "0" ]; then
                test_info "   ✓ $field_label: скопировано (одинаковое количество)"
                return 0
            else
                test_info "   ✗ $field_label: НЕ скопировано (разное количество)"
                return 1
            fi
        else
            test_info "   ✗ $field_label: НЕ скопировано (RU≠EN)"
            return 1
        fi
    fi
}

# Проверить копирование всех ACF полей
check_all_acf_fields() {
    local ru_post_id="$1"
    local en_post_id="$2"
    shift 2
    local fields=("$@")
    
    local copied=0
    local total=${#fields[@]}
    
    for field in "${fields[@]}"; do
        if check_acf_field_copied "$ru_post_id" "$en_post_id" "$field"; then
            copied=$((copied + 1))
        fi
    done
    
    if [ $copied -eq $total ]; then
        test_pass "Все ACF поля скопированы ($copied/$total)"
        return 0
    else
        test_fail "Скопировано только $copied/$total полей"
        return 1
    fi
}

# Проверить копирование таксономий
check_taxonomies_copied() {
    local ru_post_id="$1"
    local en_post_id="$2"
    shift 2
    local taxonomies=("$@")
    
    local copied=0
    local total=${#taxonomies[@]}
    
    for taxonomy in "${taxonomies[@]}"; do
        # Получить ID термина RU поста
        local ru_term_id=$(run_sql "
            SELECT t.term_id
            FROM wp_term_relationships tr
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            JOIN wp_terms t ON tt.term_id = t.term_id
            WHERE tr.object_id = $ru_post_id AND tt.taxonomy = '$taxonomy'
            LIMIT 1
        " 2>/dev/null | grep -oE '[0-9]+' | head -1)
        
        if [ -z "$ru_term_id" ]; then
            test_info "   ⊘ $taxonomy: не назначена в RU"
            continue
        fi
        
        # Получить ID термина EN поста
        local en_term_id=$(run_sql "
            SELECT t.term_id
            FROM wp_term_relationships tr
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            JOIN wp_terms t ON tt.term_id = t.term_id
            WHERE tr.object_id = $en_post_id AND tt.taxonomy = '$taxonomy'
            LIMIT 1
        " 2>/dev/null | grep -oE '[0-9]+' | head -1)
        
        if [ -z "$en_term_id" ]; then
            test_info "   ✗ $taxonomy: не назначена в EN (RU term_id=$ru_term_id)"
            continue
        fi
        
        # Проверить, что EN термин - это перевод RU термина через Polylang API
        local expected_en_id=$(run_wp_cli eval "echo pll_get_term($ru_term_id, 'en');" 2>/dev/null | grep -oE '[0-9]+' | head -1)
        
        if [ "$en_term_id" = "$expected_en_id" ]; then
            test_info "   ✓ $taxonomy: скопирована с переводом (RU=$ru_term_id → EN=$en_term_id)"
            copied=$((copied + 1))
        else
            test_info "   ✗ $taxonomy: термин не переведён (EN=$en_term_id, ожидалось=$expected_en_id)"
        fi
    done
    
    if [ $copied -eq $total ]; then
        test_pass "Все таксономии скопированы с переводом ($copied/$total)"
        return 0
    else
        test_info "Скопировано $copied/$total таксономий"
        return 1
    fi
}

# Удалить переводы медиафайлов (Polylang дублирует attachments)
delete_media_translations() {
    local ru_attachment_id="$1"
    
    # Получить EN перевод через Polylang API
    local en_attachment_id=$(run_wp_cli eval "echo pll_get_post($ru_attachment_id, 'en');" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    
    if [ -n "$en_attachment_id" ] && [ "$en_attachment_id" != "0" ] && [ "$en_attachment_id" != "$ru_attachment_id" ]; then
        # Удалить EN медиафайл (с файлом)
        run_wp_cli post delete $en_attachment_id --force 2>/dev/null
        return 0
    fi
    
    return 1
}

# Проверить наличие поста на архивной странице
check_post_on_archive() {
    local post_id="$1"
    local archive_url="$2"
    local lang="$3"
    
    if [ -z "$SITE_URL" ]; then
        test_info "   ⊘ SITE_URL не установлен, пропускаем проверку архива"
        return 0
    fi
    
    local full_url="${SITE_URL}${archive_url}"
    if [ "$lang" = "en" ]; then
        full_url="${SITE_URL}/en${archive_url}"
    fi
    
    # Проверить через curl (базовая проверка)
    local post_slug=$(run_sql "SELECT post_name FROM wp_posts WHERE ID=$post_id" 2>/dev/null | tr -d '\n')
    
    if [ -z "$post_slug" ]; then
        test_info "   ⊘ Не удалось получить slug поста"
        return 1
    fi
    
    # Простая проверка: есть ли slug в HTML архива (с Basic Auth test:test)
    local http_code=$(curl -s -u test:test -o /dev/null -w "%{http_code}" "$full_url" 2>/dev/null)
    
    if [ "$http_code" != "200" ]; then
        test_info "   ✗ Архив недоступен: HTTP $http_code ($full_url)"
        return 1
    fi
    
    local found=$(curl -s -u test:test "$full_url" 2>/dev/null | grep -c "$post_slug" || echo "0")
    
    if [ "$found" -gt 0 ] 2>/dev/null; then
        test_info "   ✓ Пост найден на $full_url"
        return 0
    else
        test_info "   ✗ Пост НЕ найден на $full_url (slug='$post_slug' не найден в HTML)"
        test_info "   Возможно, нужно время на обновление архива или flush rewrite rules"
        return 1
    fi
}

# Получить случайное значение из массива
get_random_from_array() {
    local arr=("$@")
    local size=${#arr[@]}
    local index=$((RANDOM % size))
    echo "${arr[$index]}"
}

# Получить имя термина RU по таксономии
get_test_term_ru() {
    local taxonomy="$1"
    local var_name="TEST_TERM_RU_${taxonomy}"
    eval echo "\$$var_name"
}

# Получить имя термина EN по таксономии
get_test_term_en() {
    local taxonomy="$1"
    local var_name="TEST_TERM_EN_${taxonomy}"
    eval echo "\$$var_name"
}

# Сохранить ID термина RU
set_term_id_ru() {
    local taxonomy="$1"
    local id="$2"
    eval "TERM_ID_RU_${taxonomy}=$id"
}

# Сохранить ID термина EN
set_term_id_en() {
    local taxonomy="$1"
    local id="$2"
    eval "TERM_ID_EN_${taxonomy}=$id"
}

# Получить ID термина RU
get_term_id_ru() {
    local taxonomy="$1"
    local var_name="TERM_ID_RU_${taxonomy}"
    eval echo "\$$var_name"
}

# Получить ID термина EN
get_term_id_en() {
    local taxonomy="$1"
    local var_name="TERM_ID_EN_${taxonomy}"
    eval echo "\$$var_name"
}

# Визуальный чек-лист для интерактивной проверки
show_visual_checklist() {
    local post_type="$1"
    local ru_url="$2"
    local en_url="$3"
    
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ИНТЕРАКТИВНАЯ ПРОВЕРКА ПЕРЕВОДА $(echo $post_type | tr '[:lower:]' '[:upper:]')${NC}"
    echo -e "${YELLOW}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  Откройте в браузере:                                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  RU: $ru_url"
    echo -e "${YELLOW}║${NC}  EN: $en_url"
    echo -e "${YELLOW}║${NC}                                                            ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  Проверьте визуально:                                     ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  [ ] 1. Все ACF поля заполнены в EN версии               ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  [ ] 2. Таксономии отображаются на EN языке              ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  [ ] 3. Изображения/галереи скопированы                  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  [ ] 4. Переключатель языков работает (RU ↔ EN)          ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  [ ] 5. Пост отображается на архивной странице           ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Автоматически открыть браузер (macOS/Linux)
    if command -v open &> /dev/null; then
        open "$ru_url" 2>/dev/null
        sleep 1
        open "$en_url" 2>/dev/null
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$ru_url" 2>/dev/null &
        sleep 1
        xdg-open "$en_url" 2>/dev/null &
    fi
    
    read -p "Нажмите Enter после проверки..."
}

# Интерактивное создание EN перевода
create_translation_interactive() {
    local post_type="$1"
    local post_id="$2"
    local post_type_label="$3"
    
    if [ -z "$SITE_URL" ]; then
        echo -e "${RED}Ошибка: SITE_URL не установлен${NC}"
        return 1
    fi
    
    local edit_url="${SITE_URL}/wp-admin/post.php?post=${post_id}&action=edit"
    
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║  🖐️  РУЧНОЙ ШАГ: Создайте EN перевод ${post_type_label}${NC}"
    echo -e "${MAGENTA}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${MAGENTA}║                                                                   ║${NC}"
    echo -e "${MAGENTA}║  1. Откройте в браузере (автоматически):                          ║${NC}"
    echo -e "${CYAN}║     $edit_url${NC}"
    echo -e "${MAGENTA}║                                                                   ║${NC}"
    echo -e "${MAGENTA}║  2. В блоке Languages (справа) найдите '+ EN' или '+ Add new'    ║${NC}"
    echo -e "${MAGENTA}║     напротив English и кликните                                   ║${NC}"
    echo -e "${MAGENTA}║                                                                   ║${NC}"
    echo -e "${MAGENTA}║  3. В новом окне СРАЗУ нажмите 'Опубликовать/Publish'             ║${NC}"
    echo -e "${MAGENTA}║     (ACF поля скопируются автоматически!)                         ║${NC}"
    echo -e "${MAGENTA}║                                                                   ║${NC}"
    echo -e "${MAGENTA}║  4. Вернитесь сюда и нажмите Enter                                ║${NC}"
    echo -e "${MAGENTA}║                                                                   ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Автоматически открыть браузер
    if command -v open &> /dev/null; then
        open "$edit_url" 2>/dev/null
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$edit_url" 2>/dev/null &
    fi
    
    read -p "Нажмите Enter после создания EN перевода... "
}
