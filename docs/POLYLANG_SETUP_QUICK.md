# 🚀 Быстрая установка Polylang PRO

**Дата:** 6 ноября 2025  
**Версия:** Для проекта Maslovka  
**Особенность:** Одинаковые slug'и для всех языков

---

## ⏱️ Время установки: 30-40 минут

---

## 📦 Шаг 1: Покупка и установка (5 минут)

### 1.1 Покупка
```
1. Перейти на: https://polylang.pro/
2. Выбрать: Single Site License (€99/год)
3. Оплатить и скачать .zip файл
```

### 1.2 Установка
```
WordPress Admin:
├─ Plugins → Add New → Upload Plugin
├─ Выбрать скачанный polylang-pro-x.x.x.zip
├─ Install Now
└─ Activate Plugin
```

---

## 🌍 Шаг 2: Настройка языков (10 минут)

### 2.1 Добавить языки
```
Settings → Languages

1. Add New Language:
   ├─ Full name: Русский
   ├─ Locale: ru_RU
   ├─ Language code: ru
   ├─ Flag: Russia
   └─ Save

2. Add New Language:
   ├─ Full name: English
   ├─ Locale: en_US
   ├─ Language code: en
   ├─ Flag: United Kingdom (или USA)
   └─ Save
```

### 2.2 Настроить URL структуру
```
Settings → Languages → URL modifications

1. URL modifications:
   └─ "The language is set from the directory name in pretty permalinks"
      (Язык определяется из папки в красивых ссылках)

2. Default language: Russian (Русский)

3. Hide URL language information for default language:
   └─ ✅ YES (убрать /ru/ для русского)

4. ⚠️ ВАЖНО! Share slugs across languages:
   └─ ✅ YES (одинаковые slug'и для всех языков)
      
5. Detect browser language:
   └─ ✅ YES (автоопределение языка браузера)

6. Save changes
```

**Результат:**
```
✅ Русский (по умолчанию): maslovka.org/artists/bogorodskiy-dmitriy/
✅ English:                 maslovka.org/en/artists/bogorodskiy-dmitriy/
```

---

## 📝 Шаг 3: Включить переводы для контента (5 минут)

### 3.1 Custom Post Types и Taxonomies
```
Settings → Languages → Custom post types and Taxonomies

✅ Post Types:
├─ [✓] Post (встроенный)
├─ [✓] Page (встроенный)
├─ [✓] artists (если есть)
├─ [✓] collection
├─ [✓] vistavki
└─ [✓] events (если это CPT)

✅ Taxonomies:
├─ [✓] Category (встроенная)
├─ [✓] Post Tags (встроенная)
└─ [✓] events (кастомная таксономия)

Save changes
```

### 3.2 Media (Медиафайлы)
```
Settings → Languages → Media

└─ [✓] Enable translation of media
   
   Опции:
   ├─ [ ] Duplicate media (создавать копии)
   └─ [✓] Translate media independently (переводить независимо)
   
Save changes
```

---

## 🎨 Шаг 4: Интеграция с ACF (2 минуты)

```
Settings → Languages → Advanced Custom Fields

✅ Synchronize field groups:
   └─ [✓] Enable (включить)
   
✅ Translate field values:
   └─ [✓] Enable (включить)

Save changes
```

**Что это дает:**
- Все ACF поля автоматически становятся переводимыми
- В редакторе поста появятся табы [Russian] [English]
- Можно заполнять разные значения для каждого языка

---

## 🔧 Шаг 5: Настройка в коде темы (10 минут)

### 5.1 Добавить в functions.php

```php
/**
 * Polylang: Регистрация строк для перевода
 */
add_action('init', 'maslovka_register_polylang_strings');
function maslovka_register_polylang_strings() {
    if (!function_exists('pll_register_string')) {
        return;
    }
    
    // Общие
    pll_register_string('read_more', 'Читать далее', 'Theme');
    pll_register_string('view_all', 'Смотреть все', 'Theme');
    pll_register_string('back', 'Назад', 'Theme');
    pll_register_string('search', 'Поиск', 'Theme');
    
    // Коллекции
    pll_register_string('collections', 'Коллекции', 'Theme');
    pll_register_string('collection_archive', 'Все коллекции', 'Theme');
    
    // Выставки
    pll_register_string('exhibitions', 'Выставки', 'Theme');
    pll_register_string('current_exhibitions', 'Текущие выставки', 'Theme');
    pll_register_string('past_exhibitions', 'Прошедшие выставки', 'Theme');
    
    // События
    pll_register_string('events', 'События', 'Theme');
    pll_register_string('upcoming_events', 'Предстоящие события', 'Theme');
    
    // Художники
    pll_register_string('artists', 'Художники', 'Theme');
    pll_register_string('all_artists', 'Все художники', 'Theme');
    
    // Формы
    pll_register_string('name', 'Имя', 'Theme');
    pll_register_string('email', 'Email', 'Theme');
    pll_register_string('message', 'Сообщение', 'Theme');
    pll_register_string('send', 'Отправить', 'Theme');
    
    // Навигация
    pll_register_string('home', 'Главная', 'Theme');
    pll_register_string('about', 'О музее', 'Theme');
    pll_register_string('contacts', 'Контакты', 'Theme');
}

/**
 * Хелпер для вывода переведенной строки
 */
function __t($string) {
    if (function_exists('pll__')) {
        return pll__($string);
    }
    return $string;
}

/**
 * Языковой переключатель
 */
function maslovka_language_switcher() {
    if (!function_exists('pll_the_languages')) {
        return;
    }
    
    $args = array(
        'dropdown'           => 0,      // 0 = список, 1 = dropdown
        'show_names'         => 1,      // Показывать названия
        'display_names_as'   => 'slug', // 'slug' (RU/EN) или 'name' (Русский/English)
        'show_flags'         => 1,      // Показывать флаги
        'hide_if_empty'      => 0,      // Не скрывать если нет перевода
        'hide_current'       => 0,      // Показывать текущий язык
    );
    
    echo '<div class="language-switcher">';
    pll_the_languages($args);
    echo '</div>';
}
```

### 5.2 Добавить переключатель в header.php

```php
<!-- В header.php, обычно в <header> или <nav> -->

<nav class="main-navigation">
    <!-- Ваше меню -->
    <?php wp_nav_menu(array('theme_location' => 'primary')); ?>
    
    <!-- Языковой переключатель -->
    <?php maslovka_language_switcher(); ?>
</nav>
```

### 5.3 Использовать переводы в шаблонах

```php
<!-- БЫЛО (хардкод): -->
<h2>Выставки</h2>
<a href="#">Смотреть все</a>

<!-- СТАЛО (с переводами): -->
<h2><?php echo __t('Выставки'); ?></h2>
<a href="#"><?php echo __t('Смотреть все'); ?></a>
```

---

## 🎨 Шаг 6: Стили для переключателя (5 минут)

### Добавить в style.css темы:

```css
/* === Языковой переключатель === */
.language-switcher {
    display: flex;
    align-items: center;
}

.language-switcher ul {
    list-style: none;
    display: flex;
    gap: 8px;
    margin: 0;
    padding: 0;
}

.language-switcher .lang-item {
    margin: 0;
}

.language-switcher .lang-item a {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    text-decoration: none;
    color: #333;
    font-size: 14px;
    font-weight: 500;
    border: 1px solid #ddd;
    border-radius: 4px;
    transition: all 0.3s ease;
}

.language-switcher .lang-item a:hover {
    background: #f5f5f5;
    border-color: #999;
}

.language-switcher .lang-item.current-lang a {
    background: #333;
    color: #fff;
    border-color: #333;
}

.language-switcher img {
    width: 20px;
    height: auto;
    display: block;
}

/* Responsive */
@media (max-width: 768px) {
    .language-switcher .lang-item a {
        padding: 4px 8px;
        font-size: 12px;
    }
    
    .language-switcher img {
        width: 16px;
    }
}
```

---

## 📋 Шаг 7: Создать меню для языков (5 минут)

### 7.1 Создать меню на русском
```
Appearance → Menus

1. Create new menu: "Main Menu RU"
2. Add menu items:
   ├─ Главная
   ├─ Коллекции
   ├─ Выставки
   ├─ События
   └─ Контакты
3. Menu Settings:
   └─ Language: Russian
4. Save Menu
```

### 7.2 Создать меню на английском
```
1. Create new menu: "Main Menu EN"
2. Add menu items:
   ├─ Home
   ├─ Collections
   ├─ Exhibitions
   ├─ Events
   └─ Contacts
3. Menu Settings:
   └─ Language: English
4. Save Menu
```

### 7.3 Назначить меню в локации
```
Appearance → Menus → Manage Locations

Primary Menu:
├─ Russian: Main Menu RU
└─ English: Main Menu EN

Save Changes
```

---

## ✅ Шаг 8: Проверка работоспособности (5 минут)

### Чек-лист:

```
□ Открыть: maslovka.org/
  └─ Должна открыться русская версия (без /ru/)

□ Кликнуть на переключатель EN
  └─ Должен открыться: maslovka.org/en/

□ Зайти в админку: Posts → Add New
  └─ Справа должна быть панель Languages с выбором языка

□ Создать тестовый пост на русском
  └─ Опубликовать

□ В списке постов кликнуть на [+ Add translation EN]
  └─ Должен открыться редактор английской версии

□ В редакторе английской версии проверить ACF поля
  └─ Должны быть табы [Russian] [English]

□ Проверить URL поста:
  ├─ RU: maslovka.org/название-поста/
  └─ EN: maslovka.org/en/название-поста/
      👆 slug должен быть одинаковый!

□ Зайти в Settings → Permalinks
  └─ Нажать Save Changes (сбросить rewrite rules)

□ Открыть фронтенд и проверить переключатель языков
  └─ Должен переключать между RU и EN версиями
```

---

## 🎯 Итоговая структура URL

```
✅ Правильно (как настроено):

Главная:
├─ RU: maslovka.org/
└─ EN: maslovka.org/en/

Архивы CPT:
├─ RU: maslovka.org/collection/
└─ EN: maslovka.org/en/collection/

Посты (slug одинаковый!):
├─ RU: maslovka.org/artists/bogorodskiy-dmitriy/
└─ EN: maslovka.org/en/artists/bogorodskiy-dmitriy/

Таксономии (slug одинаковый!):
├─ RU: maslovka.org/events/ekskursii/
└─ EN: maslovka.org/en/events/ekskursii/
```

---

## 🚨 Возможные проблемы и решения

### Проблема 1: 404 на английских страницах
```
Решение:
Settings → Permalinks → Save Changes
(это сбросит rewrite rules)
```

### Проблема 2: Slug'и разные для языков
```
Проверить:
Settings → Languages → URL modifications
└─ [✓] Share slugs across languages

Если галочки нет - это значит не PRO версия!
```

### Проблема 3: ACF поля не переводятся
```
Проверить:
Settings → Languages → Advanced Custom Fields
├─ [✓] Synchronize field groups
└─ [✓] Translate field values

Если не помогло:
1. Деактивировать Polylang
2. Активировать снова
3. Сохранить ACF группы полей заново
```

### Проблема 4: Меню показывается не на том языке
```
Appearance → Menus → Manage Locations
Проверить что для каждого языка назначено правильное меню
```

### Проблема 5: Флаги не показываются
```
Проверить:
1. Settings → Languages → Language switcher
   └─ Display language names or flags: Show both
   
2. Убедиться что в коде есть:
   'show_flags' => 1
```

---

## 📚 Следующие шаги после установки

### 1. Перевести строки в админке
```
Settings → Languages → Strings translations

Найти все зарегистрированные строки и добавить переводы:
├─ "Читать далее" → "Read more"
├─ "Смотреть все" → "View all"
├─ "Выставки" → "Exhibitions"
└─ и т.д.
```

### 2. Создать базовые страницы
```
Pages → Add New

1. О музее (RU) → About (EN)
2. Контакты (RU) → Contacts (EN)
3. Главная (RU) → Home (EN)
```

### 3. Перевести термины таксономий
```
Events (таксономия) → Terms

1. Экскурсии (RU) → Tours (EN)
2. Мастер-классы (RU) → Master Classes (EN)
3. Лекции (RU) → Lectures (EN)
```

### 4. Начать наполнять контент
```
Для каждого поста:
1. Создать на русском
2. Опубликовать
3. [+ Add translation EN]
4. Заполнить английскую версию
5. Опубликовать
```

---

## 📝 Памятка по работе с переводами

### Создание нового контента:

```
1. Зайти в админку: Collections → Add New

2. Выбрать язык: Russian (справа в панели Languages)

3. Заполнить контент:
   ├─ Заголовок
   ├─ Описание
   ├─ ACF поля (на табе [Russian])
   └─ Featured Image

4. Опубликовать

5. В списке Collections найти пост

6. Кликнуть: [+ Add translation EN]

7. Заполнить английскую версию:
   ├─ Заголовок (английский)
   ├─ Описание (английское)
   ├─ ACF поля (переключиться на таб [English])
   └─ Featured Image (тот же или другой)

8. Slug автоматически будет тот же!

9. Опубликовать
```

### Редактирование переводов:

```
В списке постов видно флаги: 🇷🇺 🇬🇧

Кликнуть на нужный флаг чтобы редактировать эту версию
```

---

## ✅ Готово!

После выполнения всех шагов у вас будет:

- ✅ Два языка: русский (по умолчанию) и английский
- ✅ URL структура: `maslovka.org/` и `maslovka.org/en/`
- ✅ Одинаковые slug'и для всех языков
- ✅ Переключатель языков на сайте
- ✅ Переводимые ACF поля
- ✅ Отдельные меню для каждого языка
- ✅ Правильные hreflang теги для SEO

**Время потрачено:** ~40 минут  
**Экономия в будущем:** Недели работы! 🎉

---

**Вопросы?** Смотрите полную документацию: [MULTILINGUAL_STRATEGY.md](./MULTILINGUAL_STRATEGY.md)
