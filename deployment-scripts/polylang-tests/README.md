# Polylang Testing Suite

Комплексная система тестирования многоязычности WordPress сайта с использованием Polylang + ACF.

## Обзор

Тестовый набор проверяет полную интеграцию Polylang с кастомными типами постов, ACF полями, таксономиями и SEO оптимизацией. Всего: **~90+ автоматических тестов** + интерактивные проверки.

## Структура фаз

### Фаза 0: Предварительные проверки (5 тестов)
**Цель:** Проверка готовности окружения к тестированию

**Что проверяется:**
- ✅ SSH соединение (dev/prod) или Docker контейнеры (local)
- ✅ Доступность WP-CLI
- ✅ Подключение к базе данных
- ✅ Доступность сайта (HTTP статус 200)
- ✅ WordPress загружен корректно

**Команда:**
```bash
./polylang-test.sh --env=local --only=0
```

---

### Фаза 1: Установка и настройка Polylang (12 тестов)
**Цель:** Проверка базовой конфигурации Polylang

**Что проверяется:**
- ✅ Polylang плагин установлен и активен
- ✅ Языки созданы (ru, en)
- ✅ Дефолтный язык = ru
- ✅ URL структура (язык в пути: `/`, `/en/`)
- ✅ Синхронизация таксономий включена
- ✅ Синхронизация кастомных полей включена
- ✅ Настройки темы и ACF опций
- ✅ Языковая таблица `wp_term_relationships`

**Команда:**
```bash
./polylang-test.sh --env=local --only=1
```

---

### Фаза 2: SQL миграции (EN меню) (12 тестов)
**Цель:** Проверка миграции структуры навигации

**Что проверяется:**
- ✅ EN Header меню создано
- ✅ EN Footer меню создано
- ✅ Пункты меню скопированы (Home, About, etc.)
- ✅ Структура меню сохранена (родитель-потомок)
- ✅ Языковые связи установлены (RU ↔ EN)
- ✅ Меню назначено в локации `header-menu-en`, `footer-menu-en`

**Команда:**
```bash
./polylang-test.sh --env=local --only=2
```

---

### Фаза 3: Переводы темы (14 тестов)
**Цель:** Проверка локализации темы

**Что проверяется:**
- ✅ Файлы переводов существуют (`en_US.mo`, `maslovka.pot`)
- ✅ `load_theme_textdomain()` подключен в теме
- ✅ Страница 404 переведена на EN
- ✅ Search форма переведена на EN
- ✅ Переключатель языков работает
- ✅ Архивы CPT доступны на EN (`/en/artists/`, `/en/collection/`)
- ✅ Single посты доступны на EN (`/en/artist/...`)
- ✅ Редирект с `/en/artist/` на `/en/artists/` (единственное число)

**Команда:**
```bash
./polylang-test.sh --env=local --only=3
```

---

### Фаза 4-5: Кастомные плагины и демо-контент (61 тест)
**Цель:** Комплексное тестирование автоматического копирования ACF полей и таксономий

**Блочная структура:**
- **Блок A** (4 теста) — Подготовка окружения
- **Блок B** (10 тестов) — Автосоздание терминов с переводами
- **Блок C** (9 тестов) — Тестирование CPT `artist`
- **Блок D** (8 тестов) — Тестирование CPT `collection`
- **Блок E** (9 тестов) — Тестирование CPT `events`
- **Блок F** (7 тестов) — Тестирование CPT `vistavki`
- **Блок G** (4 теста) — Анализ покрытия переводов таксономий
- **Блок H** (3 теста) — Проверка Polylang редиректов
- **Блок I** (3 теста) — Очистка тестовых данных

**Что проверяется:**
- ✅ mu-plugin `maslovka-polylang-acf.php` автоматически копирует ACF поля
- ✅ Связи таксономий копируются с автоматическим переводом терминов
- ✅ Галереи изображений копируются (Polylang дублирует attachments)
- ✅ Post-to-post relationships (`artist_id`) копируются с переводом
- ✅ Repeater поля (`content_block`) копируются с вложенными значениями
- ✅ Polylang автоматически создаёт редиректы при создании переводов
- ✅ Очистка тестовых данных не затрагивает продакшн контент

**Реальные данные проекта:**

**CPT и ACF поля:**
- **artist**: first_name, patronymic, birth_date, death_date, работы_художника, фото_художника
- **collection**: artist_id, year_created, current_location, height, width, depth
- **events**: ссылка_для_кнопки, текст_в_кнопке, цвет_блока, дата_начала, дата, цвет_текста_события, content_block
- **vistavki**: описание_мероприятия, ссылка_купить, текст_в_кнопке, Картинка_выставки, content_block

**Таксономии:**
- `art_form`, `period`, `genres`, `styles` (artist + collection)
- `techniques`, `materials` (collection)
- `artist_group`, `education` (artist)
- `event_types` (events)

**Интерактивные шаги:**

Тесты требуют ручного создания EN переводов для проверки работы mu-plugin:

1. Браузер откроется автоматически на странице редактирования RU поста
2. В блоке Languages (справа) нажмите **"+ EN"**
3. В новом окне нажмите **"Опубликовать"** (ACF поля скопируются автоматически)
4. Вернитесь в терминал и нажмите Enter

**Команда:**
```bash
./polylang-test.sh --env=local --only=4

# С сохранением лога
./polylang-test.sh --env=local --only=4 2>&1 | tee phase-4-5.log
```

**Детальная документация:** [phase-4-5/README.md](phase-4-5/README.md)

---

### Фаза 6: SEO оптимизация (45+ тестов)
**Цель:** Проверка SEO настроек и микроразметки

**Что проверяется:**
- ✅ Hreflang теги на главной странице (ru, en)
- ✅ Hreflang теги на EN версии сайта
- ✅ Функция `maslovka_maybe_disable_hreflang()` в теме
- ✅ Canonical URL на главной и EN версии
- ✅ Open Graph теги (og:locale, og:title, og:image)
- ✅ Meta описания на RU и EN
- ✅ Структурированные данные (JSON-LD Schema.org)
- ✅ Robots meta теги
- ✅ XML Sitemap существует и доступен
- ✅ Sitemap содержит URL с языковыми префиксами

**Команда:**
```bash
./polylang-test.sh --env=local --only=6
```

---

## Запуск тестов

### Базовые команды

```bash
# Запустить все фазы
./polylang-test.sh --env=local

# Запустить конкретную фазу
./polylang-test.sh --env=local --only=1

# Запустить несколько фаз
./polylang-test.sh --env=local --only=1,2,3

# Запустить с определённой фазы
./polylang-test.sh --env=local --phase=4

# Принудительно использовать SQL вместо WP-CLI
./polylang-test.sh --env=local --force-sql

# С сохранением лога
./polylang-test.sh --env=local 2>&1 | tee polylang-tests.log
```

### Мульти-окружение

Тесты поддерживают **local**, **dev** и **prod** окружения:

```bash
# Локальное окружение (Docker)
./polylang-test.sh --env=local --only=4

# Dev окружение (SSH)
./polylang-test.sh --env=dev --only=0,1,2,3

# Prod окружение (SSH)
./polylang-test.sh --env=prod --only=0,1,2,3
```

**Ключевые различия:**
- **Local**: использует Docker Compose (`docker compose exec -T php wp ...`)
- **Dev/Prod**: используют SSH (`ssh -p $SSH_PORT user@host "wp ..."`)

**Рекомендации для dev/prod:**
- **Фазы 0-3** — полностью безопасны, только проверки конфигурации
- **Фаза 4-5** — создаёт тестовые данные, но удаляет их в блоке I (рекомендуется бэкап)
- **Фаза 6** — только чтение (проверка SEO тегов)

---

## Архитектура

```
polylang-test.sh              Главный раннер
polylang-tests/
├── common.sh                 Общие функции (test_pass, test_fail, run_wp_cli)
├── phase-0.sh                Предварительные проверки
├── phase-1.sh                Настройка Polylang
├── phase-2.sh                SQL миграции (меню)
├── phase-3.sh                Переводы темы
├── phase-4-5.sh              Оркестратор блоков A-I
├── phase-6.sh                SEO оптимизация
└── phase-4-5/
    ├── common.sh             Блок-специфичные функции
    ├── block-a-preparation.sh
    ├── block-b-terms.sh
    ├── block-c-artist.sh
    ├── block-d-collection.sh
    ├── block-e-events.sh
    ├── block-f-vistavki.sh
    ├── block-g-coverage.sh
    ├── block-h-redirects.sh
    └── block-i-cleanup.sh
```

---

## Требования

### Локальное окружение:
- Docker Compose (для WordPress контейнера)
- WP-CLI в контейнере
- Минимум 3 изображения в медиабиблиотеке (для фазы 4-5)
- Браузер (для интерактивных проверок)

### Dev/Prod окружение:
- SSH доступ (настроен в `config.sh`)
- WP-CLI на удалённом сервере
- Доступ к wp-admin для интерактивных шагов
- Basic Auth (если настроен: `test:test`)

### WordPress плагины:
- **Polylang** (активен)
- **ACF Pro** (для кастомных полей)
- **mu-plugin** `maslovka-polylang-acf.php` (для автокопирования полей)
- **maslovka-custom-fields** (плагин с CPT и ACF группами)
- **maslovka-redirects** (кастомная таблица редиректов)

---

## Интерпретация результатов

### Статистика тестов
```
╔════════════════════════════════════════════╗
║       РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ              ║
╠════════════════════════════════════════════╣
║  ✓ Пройдено:      60 тестов                ║
║  ✗ Провалено:      0 тестов                ║
║  ⊘ Пропущено:      1 тест                  ║
║  ℹ Информация:     8 заметок               ║
╠════════════════════════════════════════════╣
║  Успешность:      98.4%                    ║
╚════════════════════════════════════════════╝
```

### Типы результатов:
- **✓ test_pass** — тест успешно пройден
- **✗ test_fail** — тест провален (требует внимания)
- **⊘ test_skip** — тест пропущен (ожидаемое поведение)
- **ℹ test_info** — информационное сообщение (не ошибка)

### Известные ограничения:
- Select поля (`status`) проверяются только визуально (не автоматически)
- Некоторые ACF поля не копируются автоматически (документированное поведение Polylang)
- Архивные URL могут временно не работать (кэш rewrite rules)
- Галереи дублируются для EN версии (ожидаемое поведение Polylang)

---

## Отладка

### Проверка SSH соединения (dev/prod):
```bash
cd www/deployment-scripts
./test-ssh-connection.sh dev
./test-ssh-connection.sh prod
```

### Проверка Docker контейнеров (local):
```bash
cd www
docker compose ps
docker compose logs php
```

### Проверка WP-CLI:
```bash
# Local
docker compose -f www/docker-compose.yml exec -T php wp --info

# Dev/Prod
ssh -p $SSH_PORT user@host "wp --info"
```

### Проверка базы данных:
```bash
# Языки Polylang
wp term list language --format=table

# Связи переводов
wp db query "SELECT * FROM wp_term_relationships WHERE term_taxonomy_id IN (SELECT term_id FROM wp_terms WHERE slug IN ('ru', 'en'))"

# ACF группы полей
wp acf field-group list
```

---

## Поддержка

- **Основной runner:** `polylang-test.sh`
- **Конфигурация:** `config.sh`
- **Общие функции:** `polylang-tests/common.sh`
- **Детали фазы 4-5:** `polylang-tests/phase-4-5/README.md`

**Версия:** 2.0 (модульная архитектура)  
**Дата:** Декабрь 2025
