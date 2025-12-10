#!/bin/bash
# ============================================
# ФАЗА 4: Кастомные плагины (ACF копирование)
# ============================================

phase_4_tests() {
    phase_header "4" "Кастомные плагины (ACF копирование)"
    
    local test_num=0
    
    # =========================================
    # Проверка mu-plugin
    # =========================================
    test_num=$((test_num + 1))
    echo -e "${BLUE}[4.$test_num]${NC} Проверка mu-plugin maslovka-polylang-acf.php..."
    
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
    
    # =========================================
    # Проверка что sync НЕ включает post_meta
    # =========================================
    test_num=$((test_num + 1))
    echo -e "${BLUE}[4.$test_num]${NC} Проверка что post_meta НЕ в sync (защита от перезаписи)..."
    
    POLYLANG_SYNC=$(run_sql "SELECT option_value FROM wp_options WHERE option_name = 'polylang'" 2>/dev/null)
    
    # Проверяем что post_meta НЕ присутствует в массиве sync
    # Или что mu-plugin фильтрует его через maslovka_control_meta_sync
    if echo "$POLYLANG_SYNC" | grep -q '"sync"' && echo "$POLYLANG_SYNC" | grep -q '"post_meta"'; then
        test_info "post_meta включён в настройках Polylang, проверяем mu-plugin фильтр..."
        
        # Проверяем что mu-plugin содержит фильтр maslovka_control_meta_sync
        if [ "$IS_LOCAL" = true ]; then
            FILTER_CHECK=$(docker compose -f "${LOCAL_PROJECT_ROOT}/docker-compose.yml" exec -T php grep -c "maslovka_control_meta_sync" /var/www/html/wp-content/mu-plugins/maslovka-polylang-acf.php 2>/dev/null || echo "0")
        else
            FILTER_CHECK=$(ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" "grep -c 'maslovka_control_meta_sync' ${WP_PATH}/wp-content/mu-plugins/maslovka-polylang-acf.php" 2>/dev/null || echo "0")
        fi
        
        if [ "$FILTER_CHECK" -gt "0" ]; then
            test_pass "mu-plugin содержит фильтр maslovka_control_meta_sync для защиты от перезаписи"
        else
            test_fail "post_meta в sync и нет защитного фильтра! Риск перезаписи оригинала!"
        fi
    else
        test_pass "post_meta НЕ включён в sync настройках Polylang"
    fi
    
    # =========================================
    # Интерактивный тест: создание и перевод поста
    # =========================================
    test_num=$((test_num + 1))
    echo -e "${BLUE}[4.$test_num]${NC} Интерактивный тест ACF копирования..."
    
    if [ "$WP_CLI_AVAILABLE" = false ]; then
        test_skip "Требуется WP-CLI для интеграционного теста"
        return 0
    fi
    
    echo -e "${CYAN}   → Создание тестового художника...${NC}"
    
    # Генерируем уникальные данные
    TEST_SUFFIX=$(date +%s)
    
    # Рандомные фамилии для теста
    SURNAMES=("Иванов" "Петров" "Сидоров" "Козлов" "Новиков" "Морозов" "Волков" "Соколов")
    RANDOM_SURNAME=${SURNAMES[$((RANDOM % ${#SURNAMES[@]}))]}
    TEST_TITLE="${RANDOM_SURNAME}_Test_${TEST_SUFFIX}"
    
    # Рандомный контент
    CONTENT_TEXT="Это тестовый контент для художника ${RANDOM_SURNAME}. Создан автоматически для проверки копирования ACF полей при переводе. Timestamp: ${TEST_SUFFIX}"
    
    # Создаём пост через WP-CLI с контентом
    TEST_POST_ID=$(run_wp_cli "post create --post_type=artist --post_title=${TEST_TITLE} --post_status=publish --porcelain" 2>/dev/null | tr -d '[:space:]')
    
    if [ -z "$TEST_POST_ID" ] || [ "$TEST_POST_ID" == "0" ]; then
        test_fail "Не удалось создать тестовый пост"
        return 1
    fi
    
    echo -e "${GREEN}   ✓${NC} Создан RU пост ID=$TEST_POST_ID (${RANDOM_SURNAME})"
    
    # Устанавливаем язык RU через SQL
    RU_LANG_TERM=$(run_sql "SELECT t.term_taxonomy_id FROM wp_terms t JOIN wp_term_taxonomy tt ON t.term_id = tt.term_id WHERE tt.taxonomy = 'language' AND t.slug = 'ru'" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$RU_LANG_TERM" ]; then
        run_sql "INSERT IGNORE INTO wp_term_relationships (object_id, term_taxonomy_id) VALUES ($TEST_POST_ID, $RU_LANG_TERM)" 2>/dev/null
    fi
    
    # Обновляем контент поста
    run_sql "UPDATE wp_posts SET post_content='$CONTENT_TEXT' WHERE ID=$TEST_POST_ID" 2>/dev/null
    echo -e "${GREEN}   ✓${NC} Добавлен контент"
    
    # Получаем слаг RU поста для проверок редиректов
    RU_SLUG=$(run_sql "SELECT post_name FROM wp_posts WHERE ID=$TEST_POST_ID" 2>/dev/null | tr -d '[:space:]')
    echo -e "${GREEN}   ✓${NC} Slug RU: $RU_SLUG"
    
    # =========================================
    # REDIRECT TEST 1: Редиректа НЕ должно быть до создания перевода
    # =========================================
    echo -e "${CYAN}   → Проверка редиректов (до создания перевода)...${NC}"
    
    REDIRECT_BEFORE=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$TEST_POST_ID AND redirect_type='polylang'" 2>/dev/null | tr -d '[:space:]')
    
    if [ "$REDIRECT_BEFORE" == "0" ]; then
        echo -e "${GREEN}   ✓${NC} Polylang-редирект отсутствует (ожидаемо)"
    else
        echo -e "${YELLOW}   ⚠${NC} Polylang-редирект уже существует ($REDIRECT_BEFORE записей) - неожиданно"
    fi
    
    # =========================================
    # Получаем изображения для теста
    # =========================================
    
    # 3 рандомных RU изображения
    RU_IMAGES=$(run_sql "
        SELECT p.ID FROM wp_posts p
        JOIN wp_term_relationships tr ON p.ID = tr.object_id
        JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
        JOIN wp_terms t ON tt.term_id = t.term_id
        WHERE p.post_type = 'attachment' 
        AND p.post_mime_type LIKE 'image/%'
        AND tt.taxonomy = 'language' AND t.slug = 'ru'
        ORDER BY RAND() LIMIT 3
    " 2>/dev/null | tr '\n' ' ')
    
    # 1 изображение с EN переводом (берём RU версию)
    # Сначала находим EN изображение, потом ищем его RU пару
    EN_IMAGE=$(run_sql "
        SELECT p.ID FROM wp_posts p
        JOIN wp_term_relationships tr ON p.ID = tr.object_id
        JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
        JOIN wp_terms t ON tt.term_id = t.term_id
        WHERE p.post_type = 'attachment' 
        AND p.post_mime_type LIKE 'image/%'
        AND tt.taxonomy = 'language' AND t.slug = 'en'
        LIMIT 1
    " 2>/dev/null | tr -d '[:space:]')
    
    # Ищем RU пару для EN изображения через post_translations
    if [ -n "$EN_IMAGE" ]; then
        RU_PAIR=$(run_sql "
            SELECT tr2.object_id FROM wp_term_relationships tr1
            JOIN wp_term_relationships tr2 ON tr1.term_taxonomy_id = tr2.term_taxonomy_id
            JOIN wp_term_taxonomy tt ON tr1.term_taxonomy_id = tt.term_taxonomy_id
            WHERE tr1.object_id = $EN_IMAGE 
            AND tt.taxonomy = 'post_translations'
            AND tr2.object_id != $EN_IMAGE
        " 2>/dev/null | tr -d '[:space:]')
    fi
    
    # Если не нашли пару, берём любое RU изображение
    if [ -z "$RU_PAIR" ]; then
        RU_PAIR=$(run_sql "
            SELECT p.ID FROM wp_posts p
            JOIN wp_term_relationships tr ON p.ID = tr.object_id
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            JOIN wp_terms t ON tt.term_id = t.term_id
            WHERE p.post_type = 'attachment' 
            AND p.post_mime_type LIKE 'image/%'
            AND tt.taxonomy = 'language' AND t.slug = 'ru'
            ORDER BY RAND() LIMIT 1
        " 2>/dev/null | tr -d '[:space:]')
    fi
    
    # Собираем все изображения для галереи (4 штуки: 3 рандомных + 1 с переводом)
    ALL_IMAGES="$RU_IMAGES $RU_PAIR"
    ALL_IMAGES=$(echo "$ALL_IMAGES" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')
    
    # Берём первое изображение как миниатюру
    THUMBNAIL_ID=$(echo "$RU_IMAGES" | awk '{print $1}')
    
    echo -e "${CYAN}   → Добавление полей...${NC}"
    
    # =========================================
    # 1. Миниатюра (Featured Image)
    # =========================================
    if [ -n "$THUMBNAIL_ID" ]; then
        run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, '_thumbnail_id', '$THUMBNAIL_ID')" 2>/dev/null
        echo -e "${GREEN}   ✓${NC} Миниатюра: ID=$THUMBNAIL_ID"
    fi
    
    # =========================================
    # 2. Галерея работ (работы_художника) - 4 изображения
    # =========================================
    GALLERY_IDS=$(echo "$ALL_IMAGES" | tr ' ' '\n' | grep -v '^$')
    GALLERY_COUNT=$(echo "$GALLERY_IDS" | wc -l | tr -d '[:space:]')
    
    if [ "$GALLERY_COUNT" -gt 0 ]; then
        # Формируем PHP сериализованный массив
        GALLERY_SERIALIZED=$(echo "$GALLERY_IDS" | awk -v count="$GALLERY_COUNT" 'BEGIN{printf "a:%d:{", count} {printf "i:%d;s:%d:\"%s\";", NR-1, length($0), $0} END{printf "}"}')
        run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, 'работы_художника', '$GALLERY_SERIALIZED')" 2>/dev/null
        run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, '_работы_художника', 'field_6890b75b646e5')" 2>/dev/null
        echo -e "${GREEN}   ✓${NC} Галерея работ: $GALLERY_COUNT изображений"
    fi
    
    # =========================================
    # 3. Информативный блок (content_block repeater)
    # =========================================
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, 'content_block', '1')" 2>/dev/null
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, '_content_block', 'field_688c06f80905f')" 2>/dev/null
    
    # Первый блок контента
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, 'content_block_0_титул_блока', 'Биография художника')" 2>/dev/null
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, '_content_block_0_титул_блока', 'field_688c075c09060')" 2>/dev/null
    
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, 'content_block_0_описание', 'Тестовое описание биографии художника ${RANDOM_SURNAME}. Родился в 1950 году, работал в различных техниках.')" 2>/dev/null
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, '_content_block_0_описание', 'field_688c08a093685')" 2>/dev/null
    
    echo -e "${GREEN}   ✓${NC} Информативный блок: 1 запись"
    
    # =========================================
    # 4. Даты жизни
    # =========================================
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, 'годы_жизни', '1950 — 2020')" 2>/dev/null
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, '_годы_жизни', 'field_68916b5033e26')" 2>/dev/null
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, 'birth_date', '19500115')" 2>/dev/null
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, '_birth_date', 'field_artist_birth_date')" 2>/dev/null
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, 'death_date', '20201231')" 2>/dev/null
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, '_death_date', 'field_artist_death_date')" 2>/dev/null
    echo -e "${GREEN}   ✓${NC} Даты жизни: 1950-2020"
    
    # =========================================
    # 5. Имя/Отчество
    # =========================================
    FIRST_NAMES=("Иван" "Пётр" "Сергей" "Андрей" "Михаил")
    PATRONYMICS=("Иванович" "Петрович" "Сергеевич" "Андреевич" "Михайлович")
    RANDOM_FIRST=${FIRST_NAMES[$((RANDOM % ${#FIRST_NAMES[@]}))]}
    RANDOM_PATRONYMIC=${PATRONYMICS[$((RANDOM % ${#PATRONYMICS[@]}))]}
    
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, 'first_name', '$RANDOM_FIRST')" 2>/dev/null
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, '_first_name', 'field_artist_first_name')" 2>/dev/null
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, 'patronymic', '$RANDOM_PATRONYMIC')" 2>/dev/null
    run_sql "INSERT INTO wp_postmeta (post_id, meta_key, meta_value) VALUES ($TEST_POST_ID, '_patronymic', 'field_artist_patronymic')" 2>/dev/null
    echo -e "${GREEN}   ✓${NC} ФИО: $RANDOM_FIRST $RANDOM_PATRONYMIC ${RANDOM_SURNAME}"
    
    # =========================================
    # 6. Таксономии (art_form, period)
    # =========================================
    # Получаем случайные термины
    ART_FORM_TERM=$(run_sql "SELECT term_taxonomy_id FROM wp_term_taxonomy WHERE taxonomy='art_form' ORDER BY RAND() LIMIT 1" 2>/dev/null | tr -d '[:space:]')
    PERIOD_TERM=$(run_sql "SELECT term_taxonomy_id FROM wp_term_taxonomy WHERE taxonomy='period' ORDER BY RAND() LIMIT 1" 2>/dev/null | tr -d '[:space:]')
    
    if [ -n "$ART_FORM_TERM" ]; then
        run_sql "INSERT IGNORE INTO wp_term_relationships (object_id, term_taxonomy_id) VALUES ($TEST_POST_ID, $ART_FORM_TERM)" 2>/dev/null
        ART_FORM_NAME=$(run_sql "SELECT t.name FROM wp_terms t JOIN wp_term_taxonomy tt ON t.term_id=tt.term_id WHERE tt.term_taxonomy_id=$ART_FORM_TERM" 2>/dev/null | tr -d '\n')
        echo -e "${GREEN}   ✓${NC} Форма искусства: $ART_FORM_NAME"
    fi
    
    if [ -n "$PERIOD_TERM" ]; then
        run_sql "INSERT IGNORE INTO wp_term_relationships (object_id, term_taxonomy_id) VALUES ($TEST_POST_ID, $PERIOD_TERM)" 2>/dev/null
        PERIOD_NAME=$(run_sql "SELECT t.name FROM wp_terms t JOIN wp_term_taxonomy tt ON t.term_id=tt.term_id WHERE tt.term_taxonomy_id=$PERIOD_TERM" 2>/dev/null | tr -d '\n')
        echo -e "${GREEN}   ✓${NC} Период: $PERIOD_NAME"
    fi
    
    # URL для редактирования поста
    EDIT_URL="${SITE_URL}/wp-admin/post.php?post=${TEST_POST_ID}&action=edit"
    
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║  🖐️  РУЧНОЙ ШАГ: Создайте EN перевод                              ║${NC}"
    echo -e "${MAGENTA}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${MAGENTA}║                                                                   ║${NC}"
    echo -e "${MAGENTA}║  1. Откройте в браузере:                                          ║${NC}"
    echo -e "${CYAN}║     $EDIT_URL${NC}"
    echo -e "${MAGENTA}║                                                                   ║${NC}"
    echo -e "${MAGENTA}║  2. В сайдбаре Languages найдите '+ Add new'                      ║${NC}"
    echo -e "${MAGENTA}║     напротив English и кликните                                   ║${NC}"
    echo -e "${MAGENTA}║                                                                   ║${NC}"
    echo -e "${MAGENTA}║  3. В новом окне СРАЗУ нажмите 'Опубликовать/Publish'             ║${NC}"
    echo -e "${MAGENTA}║     (без изменений!)                                              ║${NC}"
    echo -e "${MAGENTA}║                                                                   ║${NC}"
    echo -e "${MAGENTA}║  4. Вернитесь сюда и нажмите Enter                                ║${NC}"
    echo -e "${MAGENTA}║                                                                   ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Открываем браузер автоматически (macOS)
    if command -v open &> /dev/null; then
        open "$EDIT_URL" 2>/dev/null
    fi
    
    read -p "Нажмите Enter после создания EN перевода... "
    
    # =========================================
    # Находим созданный EN перевод через Polylang translations
    # =========================================
    echo -e "${CYAN}   → Поиск EN перевода...${NC}"
    
    # Ищем EN перевод связанный с нашим RU постом через post_translations
    EN_POST_ID=$(run_sql "
        SELECT tr2.object_id 
        FROM wp_term_relationships tr1
        JOIN wp_term_relationships tr2 ON tr1.term_taxonomy_id = tr2.term_taxonomy_id
        JOIN wp_term_taxonomy tt ON tr1.term_taxonomy_id = tt.term_taxonomy_id
        JOIN wp_term_relationships lang ON tr2.object_id = lang.object_id
        JOIN wp_term_taxonomy lang_tt ON lang.term_taxonomy_id = lang_tt.term_taxonomy_id
        JOIN wp_terms lang_t ON lang_tt.term_id = lang_t.term_id
        WHERE tr1.object_id = $TEST_POST_ID 
        AND tt.taxonomy = 'post_translations'
        AND tr2.object_id != $TEST_POST_ID
        AND lang_tt.taxonomy = 'language' AND lang_t.slug = 'en'
    " 2>/dev/null | tr -d '[:space:]')
    
    # Если не нашли через translations, ищем последний EN artist с похожим названием
    if [ -z "$EN_POST_ID" ] || [ "$EN_POST_ID" == "0" ]; then
        EN_POST_ID=$(run_sql "
            SELECT p.ID FROM wp_posts p
            JOIN wp_term_relationships tr ON p.ID = tr.object_id
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            JOIN wp_terms t ON tt.term_id = t.term_id
            WHERE tt.taxonomy = 'language' AND t.slug = 'en'
            AND p.post_type = 'artist'
            AND p.post_status = 'publish'
            AND p.post_title LIKE '%${TEST_SUFFIX}%'
            ORDER BY p.ID DESC LIMIT 1
        " 2>/dev/null | tr -d '[:space:]')
    fi
    
    # Последний fallback - последний созданный EN artist
    if [ -z "$EN_POST_ID" ] || [ "$EN_POST_ID" == "0" ]; then
        EN_POST_ID=$(run_sql "
            SELECT p.ID FROM wp_posts p
            JOIN wp_term_relationships tr ON p.ID = tr.object_id
            JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            JOIN wp_terms t ON tt.term_id = t.term_id
            WHERE tt.taxonomy = 'language' AND t.slug = 'en'
            AND p.post_type = 'artist'
            AND p.post_status = 'publish'
            AND p.ID > $TEST_POST_ID
            ORDER BY p.ID DESC LIMIT 1
        " 2>/dev/null | tr -d '[:space:]')
    fi
    
    if [ -z "$EN_POST_ID" ] || [ "$EN_POST_ID" == "0" ] || [ "$EN_POST_ID" == "$TEST_POST_ID" ]; then
        test_fail "EN перевод не найден. Возможно вы не создали перевод?"
        # Очистка
        run_wp_cli "post delete $TEST_POST_ID --force" 2>/dev/null
        return 1
    fi
    
    echo -e "${CYAN}   → Найден EN перевод ID=$EN_POST_ID${NC}"
    
    # Получаем слаг EN поста
    EN_SLUG=$(run_sql "SELECT post_name FROM wp_posts WHERE ID=$EN_POST_ID" 2>/dev/null | tr -d '[:space:]')
    echo -e "${CYAN}   → Slug EN: $EN_SLUG${NC}"
    
    # =========================================
    # REDIRECT TEST 2: Редирект ДОЛЖЕН появиться после создания перевода
    # =========================================
    echo -e "${CYAN}   → Проверка редиректов (после создания перевода)...${NC}"
    
    # Даём время плагину создать редирект (хук может быть асинхронным)
    sleep 1
    
    REDIRECT_AFTER=$(run_sql "SELECT id, old_url, new_url FROM wp_maslovka_redirects WHERE post_id=$EN_POST_ID AND redirect_type='polylang' LIMIT 1" 2>/dev/null)
    REDIRECT_COUNT=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$EN_POST_ID AND redirect_type='polylang'" 2>/dev/null | tr -d '[:space:]')
    
    if [ "$REDIRECT_COUNT" -ge 1 ] 2>/dev/null; then
        REDIRECT_OLD_URL=$(run_sql "SELECT old_url FROM wp_maslovka_redirects WHERE post_id=$EN_POST_ID AND redirect_type='polylang' ORDER BY id DESC LIMIT 1" 2>/dev/null | xargs)
        echo -e "${GREEN}   ✓${NC} Polylang-редирект создан ($REDIRECT_COUNT шт.)"
        
        # Проверяем HTTP ответ редиректа (если URL доступен)
        if [ -n "$REDIRECT_OLD_URL" ]; then
            HTTP_REDIRECT=$(curl_with_auth -s -o /dev/null -w "%{http_code}" -L --max-redirs 0 "${SITE_URL}${REDIRECT_OLD_URL}" 2>/dev/null || echo "000")
            if [ "$HTTP_REDIRECT" == "301" ]; then
                echo -e "${GREEN}   ✓${NC} HTTP 301 редирект работает"
            elif [ "$HTTP_REDIRECT" == "404" ]; then
                echo -e "${YELLOW}   ⚠${NC} HTTP 404 - редирект не обрабатывается (возможно слаги совпадают)"
            else
                echo -e "${YELLOW}   ⚠${NC} HTTP код: $HTTP_REDIRECT (ожидался 301)"
            fi
        fi
    else
        echo -e "${YELLOW}   ⚠${NC} Polylang-редирект НЕ создан (возможно слаги совпадают или плагин не активен)"
    fi
    
    # =========================================
    # Проверка скопированных полей
    # =========================================
    echo -e "${CYAN}   → Проверка скопированных полей...${NC}"
    echo ""
    
    local acf_tests_passed=0
    local acf_tests_total=0
    
    # 1. Проверка миниатюры
    acf_tests_total=$((acf_tests_total + 1))
    EN_THUMBNAIL=$(run_sql "SELECT meta_value FROM wp_postmeta WHERE post_id=$EN_POST_ID AND meta_key='_thumbnail_id'" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$EN_THUMBNAIL" ] && [ "$EN_THUMBNAIL" != "NULL" ] && [ "$EN_THUMBNAIL" != "" ]; then
        echo -e "${GREEN}      ✓${NC} Миниатюра скопирована: ID=$EN_THUMBNAIL"
        acf_tests_passed=$((acf_tests_passed + 1))
    else
        echo -e "${RED}      ✗${NC} Миниатюра НЕ скопирована"
    fi
    
    # 2. Проверка контента
    acf_tests_total=$((acf_tests_total + 1))
    EN_CONTENT=$(run_sql "SELECT LENGTH(post_content) FROM wp_posts WHERE ID=$EN_POST_ID" 2>/dev/null | tr -d '[:space:]')
    if [ "$EN_CONTENT" -gt 10 ] 2>/dev/null; then
        echo -e "${GREEN}      ✓${NC} Контент скопирован: $EN_CONTENT символов"
        acf_tests_passed=$((acf_tests_passed + 1))
    else
        echo -e "${RED}      ✗${NC} Контент НЕ скопирован (длина: $EN_CONTENT)"
    fi
    
    # 3. Проверка галереи работ
    acf_tests_total=$((acf_tests_total + 1))
    EN_GALLERY=$(run_sql "SELECT meta_value FROM wp_postmeta WHERE post_id=$EN_POST_ID AND meta_key='работы_художника'" 2>/dev/null)
    # Ищем и строки (s:N:"ID") и целые числа (i:N;i:ID)
    EN_GALLERY_COUNT=$(echo "$EN_GALLERY" | grep -oE '(s:[0-9]+:"[0-9]+"|i:[0-9]+;i:[0-9]+)' | wc -l | tr -d '[:space:]')
    
    if [ "$EN_GALLERY_COUNT" -ge "$GALLERY_COUNT" ] 2>/dev/null && [ "$GALLERY_COUNT" -gt 0 ]; then
        echo -e "${GREEN}      ✓${NC} Галерея работ скопирована: $EN_GALLERY_COUNT изображений"
        acf_tests_passed=$((acf_tests_passed + 1))
    else
        echo -e "${RED}      ✗${NC} Галерея работ: ожидалось $GALLERY_COUNT, получено $EN_GALLERY_COUNT"
    fi
    
    # 4. Проверка информативного блока (repeater)
    acf_tests_total=$((acf_tests_total + 1))
    EN_CONTENT_BLOCK=$(run_sql "SELECT meta_value FROM wp_postmeta WHERE post_id=$EN_POST_ID AND meta_key='content_block'" 2>/dev/null | tr -d '[:space:]')
    EN_BLOCK_TITLE=$(run_sql "SELECT meta_value FROM wp_postmeta WHERE post_id=$EN_POST_ID AND meta_key='content_block_0_титул_блока'" 2>/dev/null | tr -d '[:space:]')
    
    if [ "$EN_CONTENT_BLOCK" == "1" ] && [ -n "$EN_BLOCK_TITLE" ]; then
        echo -e "${GREEN}      ✓${NC} Информативный блок скопирован: '$EN_BLOCK_TITLE'"
        acf_tests_passed=$((acf_tests_passed + 1))
    else
        echo -e "${RED}      ✗${NC} Информативный блок НЕ скопирован (count=$EN_CONTENT_BLOCK)"
    fi
    
    # 5. Проверка дат жизни
    acf_tests_total=$((acf_tests_total + 1))
    EN_YEARS=$(run_sql "SELECT meta_value FROM wp_postmeta WHERE post_id=$EN_POST_ID AND meta_key='годы_жизни'" 2>/dev/null | tr -d '[:space:]')
    EN_BIRTH=$(run_sql "SELECT meta_value FROM wp_postmeta WHERE post_id=$EN_POST_ID AND meta_key='birth_date'" 2>/dev/null | tr -d '[:space:]')
    
    if [ -n "$EN_YEARS" ] || [ "$EN_BIRTH" == "19500115" ]; then
        echo -e "${GREEN}      ✓${NC} Даты жизни скопированы: $EN_YEARS (birth=$EN_BIRTH)"
        acf_tests_passed=$((acf_tests_passed + 1))
    else
        echo -e "${RED}      ✗${NC} Даты жизни НЕ скопированы"
    fi
    
    # 6. Проверка ФИО
    acf_tests_total=$((acf_tests_total + 1))
    EN_FIRST_NAME=$(run_sql "SELECT meta_value FROM wp_postmeta WHERE post_id=$EN_POST_ID AND meta_key='first_name'" 2>/dev/null | tr -d '[:space:]')
    EN_PATRONYMIC=$(run_sql "SELECT meta_value FROM wp_postmeta WHERE post_id=$EN_POST_ID AND meta_key='patronymic'" 2>/dev/null | tr -d '[:space:]')
    
    if [ -n "$EN_FIRST_NAME" ] && [ -n "$EN_PATRONYMIC" ]; then
        echo -e "${GREEN}      ✓${NC} ФИО скопировано: $EN_FIRST_NAME $EN_PATRONYMIC"
        acf_tests_passed=$((acf_tests_passed + 1))
    else
        echo -e "${RED}      ✗${NC} ФИО НЕ скопировано (first=$EN_FIRST_NAME, patronymic=$EN_PATRONYMIC)"
    fi
    
    # 7. Проверка таксономий
    acf_tests_total=$((acf_tests_total + 1))
    EN_ART_FORM=$(run_sql "
        SELECT t.name FROM wp_terms t
        JOIN wp_term_taxonomy tt ON t.term_id = tt.term_id
        JOIN wp_term_relationships tr ON tt.term_taxonomy_id = tr.term_taxonomy_id
        WHERE tr.object_id = $EN_POST_ID AND tt.taxonomy = 'art_form'
    " 2>/dev/null | tr -d '\n')
    
    if [ -n "$EN_ART_FORM" ]; then
        echo -e "${GREEN}      ✓${NC} Таксономия art_form скопирована: $EN_ART_FORM"
        acf_tests_passed=$((acf_tests_passed + 1))
    else
        echo -e "${RED}      ✗${NC} Таксономия art_form НЕ скопирована"
    fi
    
    echo ""
    
    # Итоговый результат
    if [ "$acf_tests_passed" -eq "$acf_tests_total" ]; then
        test_pass "Все поля скопированы ($acf_tests_passed/$acf_tests_total)"
    else
        test_fail "Поля скопированы частично ($acf_tests_passed/$acf_tests_total)"
    fi
    
    # =========================================
    # Проверка что оригинал НЕ изменён
    # =========================================
    test_num=$((test_num + 1))
    echo -e "${BLUE}[4.$test_num]${NC} Проверка что оригинал (RU) не изменён..."
    
    RU_FIRST_NAME=$(run_sql "SELECT meta_value FROM wp_postmeta WHERE post_id=$TEST_POST_ID AND meta_key='first_name'" 2>/dev/null | tr -d '[:space:]')
    RU_GALLERY_COUNT=$(run_sql "SELECT meta_value FROM wp_postmeta WHERE post_id=$TEST_POST_ID AND meta_key='работы_художника'" 2>/dev/null | grep -oE '(s:[0-9]+:"[0-9]+"|i:[0-9]+;i:[0-9]+)' | wc -l | tr -d '[:space:]')
    
    if [ "$RU_FIRST_NAME" == "$RANDOM_FIRST" ] && [ "$RU_GALLERY_COUNT" -ge "$GALLERY_COUNT" ] 2>/dev/null; then
        test_pass "Оригинальный пост (ID=$TEST_POST_ID) не изменён"
    else
        test_fail "Оригинальный пост был изменён! (first_name: $RU_FIRST_NAME vs $RANDOM_FIRST, gallery: $RU_GALLERY_COUNT vs $GALLERY_COUNT)"
    fi
    
    # =========================================
    # REDIRECT TEST 3: Изменение слага EN перевода
    # =========================================
    test_num=$((test_num + 1))
    echo -e "${BLUE}[4.$test_num]${NC} Тест изменения слага EN перевода..."
    
    # Проверяем статус поста (редирект создаётся только для publish)
    EN_STATUS=$(run_sql "SELECT post_status FROM wp_posts WHERE ID=$EN_POST_ID" 2>/dev/null | tr -d '[:space:]')
    
    if [ "$EN_STATUS" == "publish" ]; then
        # Сохраняем старый слаг и текущее количество редиректов
        OLD_EN_SLUG=$(run_sql "SELECT post_name FROM wp_posts WHERE ID=$EN_POST_ID" 2>/dev/null | tr -d '[:space:]')
        REDIRECT_COUNT_BEFORE=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$EN_POST_ID AND redirect_type='polylang'" 2>/dev/null | tr -d '[:space:]')
        
        # Генерируем новый слаг
        NEW_SLUG_SUFFIX=$(date +%s)
        NEW_EN_SLUG="${OLD_EN_SLUG}-updated-${NEW_SLUG_SUFFIX}"
        
        # Обновляем слаг через WP-CLI (чтобы сработали хуки)
        run_wp_cli "post update $EN_POST_ID --post_name=$NEW_EN_SLUG" 2>/dev/null
        
        # Даём время плагину обновить редирект
        sleep 1
        
        # Проверяем что создался новый редирект для старого слага
        NEW_REDIRECT_COUNT=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$EN_POST_ID AND redirect_type='polylang'" 2>/dev/null | tr -d '[:space:]')
        LATEST_REDIRECT_OLD=$(run_sql "SELECT old_url FROM wp_maslovka_redirects WHERE post_id=$EN_POST_ID AND redirect_type='polylang' ORDER BY id DESC LIMIT 1" 2>/dev/null | xargs)
        
        if [ "$NEW_REDIRECT_COUNT" -gt "$REDIRECT_COUNT_BEFORE" ] 2>/dev/null; then
            echo -e "${GREEN}   ✓${NC} Новый редирект создан для старого слага"
            
            # Проверяем HTTP ответ нового редиректа
            if [ -n "$LATEST_REDIRECT_OLD" ]; then
                HTTP_REDIRECT_NEW=$(curl_with_auth -s -o /dev/null -w "%{http_code}" -L --max-redirs 0 "${SITE_URL}${LATEST_REDIRECT_OLD}" 2>/dev/null || echo "000")
            if [ "$HTTP_REDIRECT_NEW" == "301" ]; then
                test_pass "Новый редирект для старого слага создан и работает (HTTP 301)"
            else
                test_info "HTTP код: $HTTP_REDIRECT_NEW (редирект может не требоваться если слаги совпадают)"
            fi
            fi
        else
            test_info "Новый редирект не создан (возможно слаги совпадают с RU версией)"
        fi
        
        # Выводим общее количество редиректов
        echo -e "${CYAN}   ℹ${NC} Всего polylang-редиректов для EN поста: $NEW_REDIRECT_COUNT"
    else
        test_skip "EN пост не опубликован (status=$EN_STATUS), редиректы не создаются"
    fi
    
    # =========================================
    # Очистка тестовых данных
    # =========================================
    test_num=$((test_num + 1))
    echo -e "${BLUE}[4.$test_num]${NC} Очистка тестовых данных..."
    
    echo -e "${YELLOW}   Удалить тестовые посты? (y/n)${NC}"
    read -p "   > " CLEANUP_ANSWER
    
    if [ "$CLEANUP_ANSWER" == "y" ] || [ "$CLEANUP_ANSWER" == "Y" ]; then
        # Запоминаем ID для проверки редиректов после удаления
        EN_POST_ID_FOR_REDIRECT_CHECK=$EN_POST_ID
        
        # Удаляем EN перевод
        if [ -n "$EN_POST_ID" ] && [ "$EN_POST_ID" != "0" ]; then
            run_wp_cli "post delete $EN_POST_ID --force" 2>/dev/null
        fi
        
        # Удаляем оригинал
        run_wp_cli "post delete $TEST_POST_ID --force" 2>/dev/null
        
        # Даём время плагину удалить редиректы
        sleep 1
        
        # Проверяем удаление постов
        DELETED_CHECK=$(run_sql "SELECT COUNT(*) FROM wp_posts WHERE ID IN ($TEST_POST_ID, $EN_POST_ID_FOR_REDIRECT_CHECK)" 2>/dev/null | tr -d '[:space:]')
        
        if [ "$DELETED_CHECK" == "0" ]; then
            test_pass "Тестовые данные удалены"
        else
            test_fail "Тестовые данные не полностью удалены"
        fi
        
        # =========================================
        # REDIRECT TEST 4: Редиректы должны быть удалены после удаления поста
        # =========================================
        test_num=$((test_num + 1))
        echo -e "${BLUE}[4.$test_num]${NC} Проверка удаления редиректов..."
        
        REDIRECT_AFTER_DELETE=$(run_sql "SELECT COUNT(*) FROM wp_maslovka_redirects WHERE post_id=$EN_POST_ID_FOR_REDIRECT_CHECK AND redirect_type='polylang'" 2>/dev/null | tr -d '[:space:]')
        
        if [ "$REDIRECT_AFTER_DELETE" == "0" ]; then
            test_pass "Polylang-редиректы удалены вместе с постом"
        else
            test_fail "Polylang-редиректы НЕ удалены ($REDIRECT_AFTER_DELETE записей осталось)"
        fi
    else
        test_info "Тестовые посты оставлены: RU=$TEST_POST_ID, EN=$EN_POST_ID"
    fi
}
