# 🌍 Polylang + ACF: Переводы полей и работа в теме

**Дата:** 6 ноября 2025  
**Полный гайд по работе с ACF полями в многоязычной теме**

---

## 📋 Содержание

1. [Как работают ACF поля с Polylang](#1-как-работают-acf-поля-с-polylang)
2. [Типы полей и их перевод](#2-типы-полей-и-их-перевод)
3. [Настройка синхронизации полей](#3-настройка-синхронизации-полей)
4. [Использование в файлах темы](#4-использование-в-файлах-темы)
5. [Строки темы (меню, кнопки, labels)](#5-строки-темы-меню-кнопки-labels)
6. [Практические примеры](#6-практические-примеры)
7. [Хелперы для темы](#7-хелперы-для-темы)

---

## 1️⃣ Как работают ACF поля с Polylang

### Архитектура хранения

WordPress хранит ACF поля в `wp_postmeta`:

```sql
-- Русская версия поста (ID: 123)
post_id | meta_key           | meta_value
--------|-------------------|------------
123     | описание          | Текст на русском
123     | birth_date        | 1950
123     | фото_выставки     | [ID изображений]

-- Английская версия поста (ID: 456)
post_id | meta_key           | meta_value
--------|-------------------|------------
456     | описание          | Text in English
456     | birth_date        | 1950  ← ОДИНАКОВОЕ (синхронизировано)
456     | фото_выставки     | [ID изображений]  ← ОДИНАКОВОЕ
```

### Polylang определяет 3 типа полей:

#### A) **Переводимые поля** (Translatable)
Разные значения для каждого языка:
```
RU: описание = "Художник родился в Москве"
EN: описание = "Artist was born in Moscow"
```

#### B) **Синхронизируемые поля** (Synchronized)
Одинаковое значение для всех языков:
```
RU: birth_date = "1950"
EN: birth_date = "1950"  ← автоматически копируется
```

#### C) **Игнорируемые поля** (Not translatable)
Используются только в языке по умолчанию:
```
RU: artist_letter = "Б"  ← есть
EN: artist_letter = ""   ← пусто
```

---

## 2️⃣ Типы полей и их перевод

### 📝 Текстовые поля (Text, Textarea, WYSIWYG)

**Как работает:**
- По умолчанию: **Переводимые**
- Каждый язык имеет свое значение

**В админке:**
```php
// Настройки ACF группы полей
Polylang → Переводить: ✅ Да

Поля:
- описание_мероприятия → Translatable
- титул_блока → Translatable
- текст_в_кнопке → Translatable
```

**В теме:**
```php
<?php
// Автоматически берет значение текущего языка
the_field('описание_мероприятия'); 

// RU: "Выставка проходит в Москве"
// EN: "Exhibition is held in Moscow"
?>
```

---

### 📅 Даты и числа (Date, Number)

**Как работает:**
- По умолчанию: **Синхронизируемые**
- Одинаковые для всех языков

**В админке:**
```php
Polylang → Синхронизировать: ✅ Да

Поля:
- birth_date → Synchronized
- death_date → Synchronized
- дата_проведения_начало → Synchronized
```

**В теме:**
```php
<?php
$birth_date = get_field('birth_date');  // 1950 (одинаково для всех языков)

// Но ФОРМАТ даты зависит от языка!
if (pll_current_language() === 'en') {
    echo date('F j, Y', strtotime($birth_date));  // "January 15, 1950"
} else {
    echo date('j F Y', strtotime($birth_date));   // "15 января 1950"
}
?>
```

---

### 🖼️ Медиа (Image, Gallery, File)

**Как работает:**
- Можно настроить: **Синхронизируемые** или **Переводимые**
- Обычно синхронизируются (одни фото для всех языков)

**В админке:**
```php
Polylang → Синхронизировать: ✅ Да

Поля:
- фото_выставки → Synchronized
- Картинка_выставки → Synchronized
```

**НО!** У изображений есть метаданные (alt, caption, description):

```php
// ID изображения одинаковый для всех языков
$image_id = get_field('Картинка_выставки');  // 789

// Но метаданные можно перевести через Media Translation
$alt = get_post_meta($image_id, '_wp_attachment_image_alt', true);
// RU: "Выставка импрессионистов"
// EN: "Exhibition of Impressionists"
```

**Лучшая практика:**
```php
<?php
$image = get_field('Картинка_выставки');  // Массив с данными

if ($image) {
    // Polylang автоматически подставит переведенный alt
    echo '<img src="' . esc_url($image['url']) . '" 
               alt="' . esc_attr($image['alt']) . '">';
}
?>
```

---

### 🔗 Связи (Relationship, Post Object)

**Как работает:**
- По умолчанию: **Переводимые**
- Можно связывать с переводами автоматически

**В админке:**
```php
Polylang → Переводить: ✅ Да
Polylang → Связывать с переводами: ✅ Да  ← ВАЖНО!

Поля:
- related_artists → Translatable + Link to translations
```

**Пример:**
```
Русский пост:
- Связанные художники: [Богородский (ID: 123)]

Английский пост:
- Related artists: [Bogorodsky (ID: 456)]  ← автоматически!
                   ↑ перевод поста 123
```

**В теме:**
```php
<?php
$related = get_field('related_artists');

if ($related) {
    foreach ($related as $post) {
        setup_postdata($post);
        // Polylang автоматически берет правильную языковую версию!
        echo '<a href="' . get_permalink() . '">' . get_the_title() . '</a>';
    }
    wp_reset_postdata();
}
?>
```

---

### 🔁 Повторители (Repeater)

**Как работает:**
- Весь повторитель: **Переводимый**
- Структура может быть разной для каждого языка

**В админке:**
```php
Polylang → Переводить: ✅ Да

Поля:
- content_block → Translatable
  ↳ титул_блока → Translatable (внутри)
  ↳ описание → Translatable (внутри)
```

**В теме (пример из вашего кода):**
```php
<?php
if (have_rows('content_block')) {
    while (have_rows('content_block')) {
        the_row();
        
        // Автоматически берет значения текущего языка
        $title = get_sub_field('титул_блока');
        $content = get_sub_field('описание');
        ?>
        <div class="informer">
            <h3><?php echo esc_html($title); ?></h3>
            <div><?php echo $content; ?></div>
        </div>
        <?php
    }
}
?>
```

**Важно:**
```
RU может иметь 3 блока content_block
EN может иметь 2 блока content_block
↑ Это ОК! Количество строк может отличаться.
```

---

### ✅ True/False, Select, Checkbox

**Как работает:**
- Обычно: **Синхронизируемые**
- Или переводимые, если выбор зависит от языка

**В админке:**
```php
// Синхронизируемые (обычно)
Polylang → Синхронизировать: ✅ Да

Поля:
- show_in_slider → Synchronized (вкл/выкл одинаково)
- status → Synchronized (статус одинаковый)

// Переводимые (редко)
Polylang → Переводить: ✅ Да

Поля:
- category_select → Translatable (если категории переводятся)
```

---

## 3️⃣ Настройка синхронизации полей

### Через админку Polylang

```
1. Settings → Languages → Settings
2. Вкладка: "Custom post types and Taxonomies"
3. Найти ACF Field Groups
4. Для каждой группы полей настроить:

✅ Translatable: Группа переводится полностью
⚠️ Do not translate: Не переводить (только для языка по умолчанию)
```

### Через код в functions.php

```php
/**
 * Настройка синхронизации ACF полей для Polylang
 */
add_filter('pll_copy_post_metas', 'sync_acf_fields', 10, 2);
function sync_acf_fields($metas, $sync) {
    // Поля которые ВСЕГДА синхронизируются (одинаковые для всех языков)
    $always_sync = [
        'birth_date',           // Дата рождения
        'death_date',           // Дата смерти
        'artist_letter',        // Первая буква (служебное)
        'дата_проведения_начало', // Дата начала
        'дата_окончание',       // Дата окончания
        'фото_выставки',        // Галерея (ID одинаковые)
        'Картинка_выставки',    // Главное фото
        'ссылка_купить',        // Ссылка на билеты (обычно одинаковая)
    ];
    
    // Добавляем их в список синхронизируемых
    foreach ($always_sync as $key) {
        if (!in_array($key, $metas)) {
            $metas[] = $key;
        }
    }
    
    return $metas;
}

/**
 * Поля которые НЕ копируются (переводятся вручную)
 */
add_filter('pll_translate_post_meta', 'acf_translatable_fields', 10, 3);
function acf_translatable_fields($value, $key, $lang) {
    // Список переводимых полей (НЕ копировать!)
    $translatable = [
        'описание_мероприятия',  // Описание
        'титул_блока',           // Заголовки
        'описание',              // Текстовые блоки
        'текст_в_кнопке',        // Тексты кнопок
        'content_block',         // Весь повторитель
        'сноска_под_заголовком', // Сноски
        'текст_в_сноске',
        'автор_сноски',
    ];
    
    // Если поле переводимое - НЕ копируем значение
    if (in_array($key, $translatable)) {
        return null;  // Останется пустым, нужно заполнить вручную
    }
    
    return $value;  // Остальные поля копируются
}
```

---

## 4️⃣ Использование в файлах темы

### Базовые функции

```php
<?php
// ==========================================
// ПОЛУЧЕНИЕ ЗНАЧЕНИЯ ПОЛЯ
// ==========================================

// Автоматически для текущего языка
$description = get_field('описание_мероприятия');

// Для конкретного языка
$description_en = get_field('описание_мероприятия', $post_id, false);  // false = не форматировать
pll_set_language('en');  // Переключить контекст
$description_en = get_field('описание_мероприятия', $post_id);
pll_restore_language();  // Вернуть назад

// Вывод напрямую
the_field('описание_мероприятия');  // Выводит HTML

// ==========================================
// ПРОВЕРКА СУЩЕСТВОВАНИЯ
// ==========================================

if (get_field('фото_выставки')) {
    // Поле существует и не пустое
}

// ==========================================
// ПОВТОРИТЕЛИ
// ==========================================

if (have_rows('content_block')) {
    while (have_rows('content_block')) {
        the_row();
        $title = get_sub_field('титул_блока');
        $content = get_sub_field('описание');
    }
}

// ==========================================
// ИЗОБРАЖЕНИЯ
// ==========================================

// Получить массив
$image = get_field('Картинка_выставки');
// ['id' => 123, 'url' => '...', 'alt' => '...', 'title' => '...']

// Только URL
$image_url = get_field('Картинка_выставки', false, false);

// Только ID
$image_id = get_field('Картинка_выставки');
if (is_numeric($image_id)) {
    $image_url = wp_get_attachment_url($image_id);
}
?>
```

---

### Работа с текущим языком

```php
<?php
// ==========================================
// ОПРЕДЕЛЕНИЕ ТЕКУЩЕГО ЯЗЫКА
// ==========================================

$current_lang = pll_current_language();  // 'ru' или 'en'
$current_lang_name = pll_current_language('name');  // 'Русский' или 'English'

// ==========================================
// ПРОВЕРКА ЯЗЫКА
// ==========================================

if (pll_current_language() === 'en') {
    // Английская версия
    echo 'Read more';
} else {
    // Русская версия
    echo 'Читать далее';
}

// ==========================================
// ПОЛУЧЕНИЕ ПЕРЕВОДА ПОСТА
// ==========================================

$translations = pll_get_post_translations($post_id);
// ['ru' => 123, 'en' => 456]

$english_version_id = pll_get_post($post_id, 'en');
if ($english_version_id) {
    $english_url = get_permalink($english_version_id);
}

// ==========================================
// ЯЗЫК ПО УМОЛЧАНИЮ
// ==========================================

$default_lang = pll_default_language();  // 'ru'

if (pll_current_language() === pll_default_language()) {
    // Мы на языке по умолчанию
}
?>
```

---

### Форматирование дат по языкам

```php
<?php
/**
 * Форматировать дату в зависимости от языка
 */
function format_date_localized($date_string) {
    if (empty($date_string)) {
        return '';
    }
    
    $timestamp = strtotime($date_string);
    
    if (pll_current_language() === 'en') {
        // English: "January 15, 1950"
        return date_i18n('F j, Y', $timestamp);
    } else {
        // Русский: "15 января 1950"
        return date_i18n('j F Y', $timestamp);
    }
}

// Использование:
$start = get_field('дата_проведения_начало');
echo format_date_localized($start);
?>
```

---

### Обновленная функция дат художника (с переводами)

```php
<?php
/**
 * Форматирование дат жизни художника с поддержкой языков
 */
function get_formatted_artist_lifespan($post_id = null) {
    if (!$post_id) {
        $post_id = get_the_ID();
    }
    
    $birth_date = get_field('birth_date', $post_id);
    $death_date = get_field('death_date', $post_id);
    
    if (empty($birth_date) && empty($death_date)) {
        return '';
    }
    
    $en_dash = '&nbsp;–&nbsp;';
    
    // Обе даты
    if (!empty($birth_date) && !empty($death_date)) {
        return esc_html($birth_date) . $en_dash . esc_html($death_date);
    }
    
    // Нет даты рождения
    if (empty($birth_date) && !empty($death_date)) {
        return '?' . $en_dash . esc_html($death_date);
    }
    
    // Нет даты смерти (ныне живущий)
    if (!empty($birth_date) && empty($death_date)) {
        // Перевод "род."
        if (pll_current_language() === 'en') {
            return 'b.&nbsp;' . esc_html($birth_date);  // born
        } else {
            return 'род.&nbsp;' . esc_html($birth_date);  // родился
        }
    }
    
    return '';
}
?>
```

---

## 5️⃣ Строки темы (меню, кнопки, labels)

### Проблема:

Hardcoded строки в теме **не переводятся автоматически**:

```php
<!-- ❌ НЕПРАВИЛЬНО: -->
<a href="/exhibitions-active/">Все выставки</a>
<h3>Фотографии</h3>
<button>Читать далее</button>
```

### Решение 1: Polylang String Translations

**Регистрация строк:**

```php
<?php
// В functions.php

add_action('init', 'register_theme_strings');
function register_theme_strings() {
    if (function_exists('pll_register_string')) {
        // Регистрируем переводимые строки
        pll_register_string('all_exhibitions', 'Все выставки', 'maslovka-theme');
        pll_register_string('past_exhibitions', 'Прошедшие выставки', 'maslovka-theme');
        pll_register_string('photos', 'Фотографии', 'maslovka-theme');
        pll_register_string('read_more', 'Читать далее', 'maslovka-theme');
        pll_register_string('birth_abbr', 'род.', 'maslovka-theme');
        pll_register_string('related_artists', 'Связанные художники', 'maslovka-theme');
        pll_register_string('biography', 'Биография', 'maslovka-theme');
        pll_register_string('artworks', 'Произведения', 'maslovka-theme');
        pll_register_string('exhibitions', 'Выставки', 'maslovka-theme');
    }
}
?>
```

**Использование в теме:**

```php
<!-- ✅ ПРАВИЛЬНО: -->
<a href="<?php echo pll_home_url(); ?>exhibitions-active/">
    <?php echo pll__('Все выставки'); ?>
</a>

<h3><?php echo pll__('Фотографии'); ?></h3>

<button><?php echo pll__('Читать далее'); ?></button>
```

**В админке:**

```
Settings → Languages → String translations
↓
Найти "maslovka-theme"
↓
Перевести каждую строку:
- Все выставки → All Exhibitions
- Фотографии → Photos
- Читать далее → Read More
```

---

### Решение 2: Массив переводов в коде

```php
<?php
// В functions.php

function __t($key) {
    $translations = [
        'all_exhibitions' => [
            'ru' => 'Все выставки',
            'en' => 'All Exhibitions',
        ],
        'past_exhibitions' => [
            'ru' => 'Прошедшие выставки',
            'en' => 'Past Exhibitions',
        ],
        'photos' => [
            'ru' => 'Фотографии',
            'en' => 'Photos',
        ],
        'read_more' => [
            'ru' => 'Читать далее',
            'en' => 'Read More',
        ],
        'birth_abbr' => [
            'ru' => 'род.',
            'en' => 'b.',
        ],
        'related_artists' => [
            'ru' => 'Связанные художники',
            'en' => 'Related Artists',
        ],
        'biography' => [
            'ru' => 'Биография',
            'en' => 'Biography',
        ],
        'artworks' => [
            'ru' => 'Произведения',
            'en' => 'Artworks',
        ],
    ];
    
    $lang = pll_current_language();
    
    if (isset($translations[$key][$lang])) {
        return $translations[$key][$lang];
    }
    
    // Fallback на русский
    return $translations[$key]['ru'] ?? $key;
}

// Использование в теме:
<h3><?php echo __t('photos'); ?></h3>
?>
```

---

### Решение 3: WordPress .po/.mo файлы (классика)

```php
<?php
// В functions.php
load_theme_textdomain('maslovka-theme', get_template_directory() . '/languages');

// В теме:
<h3><?php _e('Фотографии', 'maslovka-theme'); ?></h3>
<button><?php echo __('Читать далее', 'maslovka-theme'); ?></button>

// Создать файлы:
// languages/ru_RU.po
// languages/en_US.po
// Перевести через Poedit
?>
```

**Рекомендация:** Используйте **Решение 1** (Polylang String Translations) - самое простое!

---

## 6️⃣ Практические примеры

### Пример 1: Обновленный single-artists.php

```php
<?php get_header(); ?>

<header id="header">
    <div class="wrapper">
        <div class="page_logo">
            <a href="<?php echo pll_home_url(); ?>">
                <img src="<?php echo get_template_directory_uri(); ?>/assets/img/logo_black.png" alt="">
            </a>
        </div>
        <?php get_template_part('components/topmenu'); ?>
        
        <div class="header_container">
            <div class="header_bread">
                <a href="<?php echo pll_home_url(); ?>exhibitions-active/">
                    <svg>...</svg>
                    <?php echo pll__('Все выставки'); ?>
                </a>
                <a href="<?php echo pll_home_url(); ?>exhibitions-past/">
                    <?php echo pll__('Прошедшие выставки'); ?>
                    <svg>...</svg>
                </a>
            </div>

            <h1 class="page_title">
                <?php the_title(); ?>
            </h1>
        </div>
    </div>
</header>

<main id="page">
    <div class="wrapper">
        <div class="page_maininfo page_minblocks">
            <?php the_content(); ?>
            
            <!-- Повторитель (автоматически на текущем языке) -->
            <?php if (have_rows('content_block')): ?>
                <?php while (have_rows('content_block')): the_row(); 
                    $title = get_sub_field('титул_блока');
                    $content = get_sub_field('описание');
                ?>
                <div class="informer">
                    <div class="informer_aside">
                        <h3 class="informer_title"><?php echo esc_html($title); ?></h3>
                        <?php if (have_rows('сноска_под_заголовком')): ?>
                            <?php while (have_rows('сноска_под_заголовком')): the_row(); ?>
                                <div class="informer_label">
                                    <?php 
                                    $note_text = get_sub_field('текст_в_сноске');
                                    $note_author = get_sub_field('автор_сноски');
                                    ?>
                                    <?php if ($note_text): ?>
                                        <p><?php echo esc_html($note_text); ?></p>
                                    <?php endif; ?>
                                    <?php if ($note_author): ?>
                                        <span><?php echo esc_html($note_author); ?></span>
                                    <?php endif; ?>
                                </div>
                            <?php endwhile; ?>
                        <?php endif; ?>
                    </div>
                    <div class="informer_content">
                        <?php if ($content): ?>
                            <?php echo $content; ?>
                        <?php endif; ?>
                    </div>
                </div>
                <?php endwhile; ?>
            <?php endif; ?>
            
            <!-- Галерея (фото синхронизированы, но alt переведены) -->
            <?php $images = get_field('фото_выставки'); ?>
            <?php if ($images): ?>
            <div class="informer gallery">
                <div class="informer_aside">
                    <h3 class="informer_title"><?php echo pll__('Фотографии'); ?></h3>
                </div>
                <div class="informer_gallery">
                    <?php foreach ($images as $image): ?>
                        <a href="<?php echo esc_url($image['url']); ?>" target="_blank">
                            <img src="<?php echo esc_url($image['url']); ?>" 
                                 alt="<?php echo esc_attr($image['alt']); ?>">
                        </a>
                    <?php endforeach; ?>
                </div>
            </div>
            <?php endif; ?>
        </div>
    </div>
</main>

<?php get_footer(); ?>
```

---

### Пример 2: Обновленный single-vistavki.php (с датами)

```php
<?php
$start = get_field('дата_проведения_начало');
$end = get_field('дата_окончание');

if ($start && $end) {
    $start_formatted = format_date_localized($start);
    $end_formatted = format_date_localized($end);
    ?>
    <div class="event_dates">
        <?php 
        if (pll_current_language() === 'en') {
            echo $start_formatted . ' – ' . $end_formatted;
        } else {
            echo $start_formatted . ' – ' . $end_formatted;
        }
        ?>
    </div>
    <?php
}
?>

<!-- Описание (переводится) -->
<p><?php the_field('описание_мероприятия'); ?></p>

<!-- Кнопка билетов -->
<?php if (get_field('ссылка_купить')): ?>
    <div class="news_buttons_main" data-btn-text="<?php echo esc_attr(get_field('текст_в_кнопке')); ?>">
        <?php echo get_field('ссылка_купить'); ?>
    </div>
<?php endif; ?>
```

---

## 7️⃣ Хелперы для темы

### Полный набор helper-функций

```php
<?php
/**
 * ============================================
 * ПОЛНЫЙ НАБОР ХЕЛПЕРОВ ДЛЯ МНОГОЯЗЫЧНОЙ ТЕМЫ
 * Добавить в functions.php
 * ============================================
 */

/**
 * Получить домашний URL для текущего языка
 */
function get_home_url_lang() {
    return pll_home_url();
}

/**
 * Получить URL страницы на текущем языке
 */
function get_page_url_lang($page_slug) {
    $page_id = get_page_by_path($page_slug);
    if (!$page_id) {
        return pll_home_url() . $page_slug . '/';
    }
    
    $translated_page_id = pll_get_post($page_id->ID);
    if ($translated_page_id) {
        return get_permalink($translated_page_id);
    }
    
    return get_permalink($page_id);
}

/**
 * Форматировать дату с учетом языка
 */
function format_date_localized($date_string, $format = null) {
    if (empty($date_string)) {
        return '';
    }
    
    $timestamp = strtotime($date_string);
    
    // Автоматический формат по языку
    if (!$format) {
        if (pll_current_language() === 'en') {
            $format = 'F j, Y';  // January 15, 1950
        } else {
            $format = 'j F Y';   // 15 января 1950
        }
    }
    
    return date_i18n($format, $timestamp);
}

/**
 * Получить название месяца на текущем языке
 */
function get_month_name($month_number) {
    $months_ru = [
        1 => 'января', 2 => 'февраля', 3 => 'марта',
        4 => 'апреля', 5 => 'мая', 6 => 'июня',
        7 => 'июля', 8 => 'августа', 9 => 'сентября',
        10 => 'октября', 11 => 'ноября', 12 => 'декабря'
    ];
    
    $months_en = [
        1 => 'January', 2 => 'February', 3 => 'March',
        4 => 'April', 5 => 'May', 6 => 'June',
        7 => 'July', 8 => 'August', 9 => 'September',
        10 => 'October', 11 => 'November', 12 => 'December'
    ];
    
    if (pll_current_language() === 'en') {
        return $months_en[$month_number] ?? '';
    }
    
    return $months_ru[$month_number] ?? '';
}

/**
 * Форматировать дату как "15 января 2025" или "January 15, 2025"
 */
function format_event_date($date_string) {
    if (empty($date_string)) {
        return '';
    }
    
    $timestamp = strtotime($date_string);
    $day = date('j', $timestamp);
    $month_number = (int)date('n', $timestamp);
    $year = date('Y', $timestamp);
    
    if (pll_current_language() === 'en') {
        return get_month_name($month_number) . ' ' . $day . ', ' . $year;
    } else {
        return $day . ' ' . get_month_name($month_number) . ' ' . $year;
    }
}

/**
 * Проверка: текущий язык = английский?
 */
function is_english() {
    return pll_current_language() === 'en';
}

/**
 * Проверка: текущий язык = русский?
 */
function is_russian() {
    return pll_current_language() === 'ru';
}

/**
 * Получить перевод post/page на другой язык
 */
function get_translation_url($post_id = null, $target_lang = 'en') {
    if (!$post_id) {
        $post_id = get_the_ID();
    }
    
    $translation_id = pll_get_post($post_id, $target_lang);
    
    if ($translation_id) {
        return get_permalink($translation_id);
    }
    
    // Fallback на главную
    return pll_home_url($target_lang);
}

/**
 * Язык-свитчер (для футера/хедера)
 */
function display_language_switcher($class = 'lang-switcher') {
    if (!function_exists('pll_the_languages')) {
        return;
    }
    
    $args = [
        'show_flags' => 0,
        'show_names' => 1,
        'hide_if_empty' => 0,
        'dropdown' => 0,
        'echo' => 0,
    ];
    
    $switcher = pll_the_languages($args);
    
    if ($switcher) {
        echo '<div class="' . esc_attr($class) . '">' . $switcher . '</div>';
    }
}

/**
 * Получить ACF поле с fallback на язык по умолчанию
 * Если поле пустое на текущем языке - берет с русского
 */
function get_field_with_fallback($field_name, $post_id = null) {
    $value = get_field($field_name, $post_id);
    
    // Если есть значение - вернуть
    if (!empty($value)) {
        return $value;
    }
    
    // Если текущий язык = русский, больше нечего пробовать
    if (pll_current_language() === pll_default_language()) {
        return $value;
    }
    
    // Получить русскую версию поста
    if (!$post_id) {
        $post_id = get_the_ID();
    }
    
    $ru_post_id = pll_get_post($post_id, pll_default_language());
    
    if ($ru_post_id) {
        return get_field($field_name, $ru_post_id);
    }
    
    return $value;
}
?>
```

---

## 📊 Чеклист для темы

### ✅ Что нужно перевести:

- [ ] Все hardcoded строки через `pll_register_string()` и `pll__()`
- [ ] Названия месяцев и форматы дат
- [ ] Тексты кнопок ("Читать далее", "Купить билет")
- [ ] Хлебные крошки и навигация
- [ ] Заголовки секций ("Фотографии", "Биография")
- [ ] Placeholder'ы в формах
- [ ] Alt текст для всех изображений
- [ ] Meta описания и title
- [ ] Меню (через Polylang interface)
- [ ] Виджеты в сайдбарах

### ✅ ACF поля настроить:

- [ ] Текстовые поля → Translatable
- [ ] Даты и числа → Synchronized
- [ ] Изображения → Synchronized (но alt переводятся)
- [ ] Галереи → Synchronized
- [ ] Повторители → Translatable
- [ ] Связи (Relationship) → Translatable + Link to translations
- [ ] True/False → Synchronized (обычно)

### ✅ В коде проверить:

- [ ] `get_field()` везде работает автоматически
- [ ] URL строятся через `pll_home_url()`
- [ ] Ссылки на страницы через `get_page_url_lang()`
- [ ] Даты форматируются через `format_date_localized()`
- [ ] Нет hardcoded URL типа `/artists/`
- [ ] Language switcher в header/footer
- [ ] hreflang теги в `<head>` (Polylang добавляет автоматически)

---

## 🎯 Готово к внедрению?

**Следующие шаги:**

1. ✅ Добавить хелперы в `functions.php`
2. ✅ Зарегистрировать строки темы для перевода
3. ✅ Обновить файлы темы (заменить hardcoded текст)
4. ✅ Настроить ACF поля в админке Polylang
5. ✅ Протестировать переключение языков

Хотите, чтобы я обновил конкретные файлы темы? 🚀
