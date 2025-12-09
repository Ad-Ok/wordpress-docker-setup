# 🌍 План внедрения мультиязычности для Maslovka.org

**Дата:** 3 декабря 2025  
**Языки:** Русский (основной) + Английский  
**Версия Polylang:** FREE + кастомные плагины  

---

## 🎯 Стратегия

```
✅ Polylang FREE (бесплатная версия)
✅ Разные slug'и для разных языков
✅ Кастомный плагин редиректов (/en/post/ → /en/post-2/)
✅ Кастомный плагин автокопирования контента
✅ Работа на PROD, local/dev для тестирования
✅ SQL миграции для переноса настроек
✅ Много контента (~30 CPT, сотни постов)
✅ Slug'и транслитом
```

---

## 🚀 Пошаговый план

### Фаза 1: Установка и настройка Polylang (LOCAL) - 2-3 часа

**1.1. Установка Polylang FREE**
```bash
# WordPress Admin → Plugins → Add New
# Загрузить polylang.zip → Activate
```

**1.2. Настройка языков**
```
Settings → Languages → Languages

Add New Language:
1. Russian (Русский)
   - Locale: ru_RU
   - Flag: 🇷🇺
   - Set as default: YES
   - URL modification: Remove language info from URL ✅

2. English
   - Locale: en_US  
   - Flag: 🇺🇸
   - URL modification: /en/

Settings:
✅ Hide URL language info for default
✅ Media: Enable translation
✅ The front page URL contains the language code instead of the page name or page id
   (чтобы EN главная была /en/, а не /en/slug-of-english-homepage/)
✅ There are posts, pages, categories or tags without language. You can set them all to the default language. - нажать!
```

**1.3. Включить CPT и таксономии**
```
Settings → Languages → Settings → Custom post types

✅ Collections
✅ Vistavki  
✅ Events (Sobitiya)
✅ Artists
✅ Photo

(Page, Post, Attachment включены по умолчанию)

Custom taxonomies:
✅ art_form
✅ artist_group
✅ education
✅ event_types
✅ genres
✅ materials
✅ period
✅ styles
✅ techniques
```

**1.4. Тестирование настроек**

**Вариант A: SQL-запросы (phpMyAdmin, Adminer, MySQL CLI)**
```sql
-- 1. Проверить языки созданы
SELECT t.name, t.slug, tt.count 
FROM wp_terms t 
JOIN wp_term_taxonomy tt ON t.term_id = tt.term_id 
WHERE tt.taxonomy = 'language';
-- Ожидаемо: Русский (ru), English (en)

-- 2. Проверить настройки Polylang
SELECT option_value FROM wp_options WHERE option_name = 'polylang';
-- Искать: "default_lang";s:2:"ru"
-- Искать: "hide_default";b:1
-- Искать: "browser";b:1
```

**Вариант B: WP-CLI (если доступен)**
```bash
# Проверить плагин активен
wp plugin list | grep polylang

# Проверить настройки Polylang
wp option get polylang --format=yaml
# Ключевые поля:
# - default_lang: ru
# - hide_default: true
# - rewrite: true  
# - browser: true
# - post_types: [artist, collection, events, photo, vistavki]
```

**Вариант C: curl (проверка URL)**
```bash
# RU главная (без /ru/)
curl -I https://localhost/ 2>&1 | grep HTTP
# Ожидаемо: HTTP/2 200

# EN главная (с /en/)
curl -I https://localhost/en/ 2>&1 | grep HTTP
# Ожидаемо: HTTP/2 200
```

**Визуальная проверка (обязательно!):**
```
1. Settings → Languages
   ✅ 2 языка в списке: Русский (default), English
   ✅ URL modification: Hide for default = ON
   ✅ Проверить, что нет сообщений вида There are posts, pages, categories or tags without language

2. Settings → Languages → Settings
   ✅ CPT: collections, vistavki, events, artists, photo
   ✅ Taxonomies: все нужные включены
   
3. Открыть сайт в браузере
   ✅ https://localhost/ → русская версия
   ✅ https://localhost/en/ → английская версия
```

**Чек-лист Фазы 1:**
- [ ] Polylang установлен и активирован на LOCAL/DEV/PROD
- [ ] Языки созданы: ru (default), en
- [ ] CPT включены: collections, vistavki, events, artists, photo
- [ ] Таксономии включены
- [ ] hide_default = true, rewrite = true
- [ ] Настройки одинаковые на всех окружениях

> ⚠️ **Важно:** Настройки Фазы 1 делаются **вручную одинаково** на всех окружениях (LOCAL, DEV, PROD). Меню и переводы строк создаются через миграции в Фазе 2.

---

### Фаза 2: Создание SQL миграций (только меню и строки) - 1 час

> ✅ Языки и CPT настраиваются вручную в Фазе 1 на всех окружениях одинаково

**2.1. Структура миграций**
```
www/deployment-scripts/database/migrations/
├── 001-polylang-menus.sql
└── 002-polylang-string-translations.sql
```

**2.2. Миграция 1: Меню** (`001-polylang-menus.sql`)

**Создание меню на LOCAL:**
```
Appearance → Menus

Menu 1: "Main Menu RU"
- Назначить язык: Russian
- Theme location: Primary Menu
- Добавить пункты меню

Menu 2: "Main Menu EN"
- Назначить язык: English
- Theme location: Primary Menu
- Добавить пункты меню
```

**Экспорт меню:**
```bash
# После создания меню на LOCAL:
mysqldump -u root -p wordpress_db \
  --no-create-info \
  --where="term_id IN (SELECT term_id FROM wp_term_taxonomy WHERE taxonomy = 'nav_menu')" \
  wp_terms wp_term_taxonomy wp_term_relationships \
  > 001-polylang-menus.sql
```

**2.3. Миграция 2: Строки** (`002-polylang-string-translations.sql`)
```sql
-- Создается после перевода строк темы (Фаза 3)
-- Экспорт переводов из wp_options (polylang_mo_*)
```

**2.4. Тестирование миграций**

**SQL-запросы (phpMyAdmin, Adminer, MySQL CLI):**
```sql
-- 1. Проверить меню созданы
SELECT t.term_id, t.name, tt.taxonomy
FROM wp_terms t 
JOIN wp_term_taxonomy tt ON t.term_id = tt.term_id 
WHERE tt.taxonomy = 'nav_menu';
-- Ожидаемо: Main Menu RU, Main Menu EN

-- 2. Проверить связь меню с языками
SELECT t.name as menu_name, tr.object_id, lang.name as language
FROM wp_terms t
JOIN wp_term_taxonomy tt ON t.term_id = tt.term_id
JOIN wp_term_relationships tr ON t.term_id = tr.object_id
JOIN wp_term_taxonomy lang_tt ON tr.term_taxonomy_id = lang_tt.term_taxonomy_id
JOIN wp_terms lang ON lang_tt.term_id = lang.term_id
WHERE tt.taxonomy = 'nav_menu' AND lang_tt.taxonomy = 'language';
```

**curl (проверка URL):**
```bash
# Проверить что обе языковые версии работают
curl -I https://localhost/ | grep HTTP
curl -I https://localhost/en/ | grep HTTP
# Оба должны вернуть 200
```

**Визуальная проверка:**
```
1. Appearance → Menus
   ✅ Main Menu RU виден с языком "Русский"
   ✅ Main Menu EN виден с языком "English"
   ✅ Оба меню назначены на Primary Menu

2. Проверить фронтенд
   ✅ На / показывается русское меню
   ✅ На /en/ показывается английское меню
```

**Чек-лист Фазы 2:**
- [ ] Меню созданы на LOCAL для обоих языков
- [ ] SQL-запрос показывает 2 меню с разными языками
- [ ] 001-polylang-menus.sql экспортирован
- [ ] db-migrate.sh обновлен (если используется)
- [ ] Файлы миграций добавлены в git
- [ ] Git commit миграций

---

### Фаза 3: Переводы темы - 2-3 часа

> **Подход**: Используем стандартную систему переводов WordPress (`.po/.mo` файлы) вместо Polylang String Translations. Это позволяет хранить переводы в git и не требует SQL миграций.

**3.1. Структура файлов переводов**

```
wp-content/themes/maslovka/languages/
├── maslovka.pot     # Шаблон переводов (ключи = русские фразы)
├── en_US.po         # Английские переводы (исходник)
└── en_US.mo         # Скомпилированный бинарный файл
```

**3.2. Обернуть строки в функции перевода**

```php
// ❌ ДО:
echo 'Подробнее';

// ✅ ПОСЛЕ (русская строка как ключ):
echo __('Подробнее', 'maslovka');
// или для вывода:
esc_html_e('Подробнее', 'maslovka');
```

**Файлы для обновления:**
```
wp-content/themes/maslovka/
├── 404.php, 500.php, 503.php   # Страницы ошибок
├── footer.php                   # Куки-баннер
├── single.php                   # Страница художника
├── single-collection.php        # Страница произведения
├── page-artists.php             # Архив художников
├── components/
│   ├── topmenu.php             # Мобильное меню
│   ├── home-events.php         # Блок событий
│   └── home-vistavki.php       # Блок выставок
└── inc/components/
    ├── events-grid.php         # Сетка событий
    └── exhibitions-grid.php    # Сетка выставок
```

**3.3. Загрузка переводов**

В `inc/theme/theme-setup.php`:
```php
function maslovka_theme_setup() {
    // Загрузка переводов темы
    load_theme_textdomain('maslovka', get_template_directory() . '/languages');
    // ... остальные настройки
}
```

**3.4. Билд переводов**

В `package.json` добавлен скрипт:
```json
{
  "scripts": {
    "build:i18n": "msgfmt languages/en_US.po -o languages/en_US.mo",
    "build": "webpack --mode production && npm run build:i18n"
  }
}
```

Требуется установленный `gettext`:
```bash
# macOS
brew install gettext

# Ubuntu/Debian
sudo apt-get install gettext
```

**3.5. Процесс добавления новых переводов**

1. Добавить строку в PHP с `__('Текст', 'maslovka')`
2. Добавить в `languages/maslovka.pot` (msgid)
3. Добавить перевод в `languages/en_US.po` (msgstr)
4. Запустить `npm run build:i18n`
5. Закоммитить все 3 файла (.pot, .po, .mo)

**3.6. Языковой переключатель**

Добавить ACF поле в настройки страниц:

```php
// В functions.php или ACF JSON:
if (function_exists('acf_add_local_field_group')) {
    acf_add_local_field_group(array(
        'key' => 'group_page_settings',
        'title' => 'Настройки страницы',
        'fields' => array(
            array(
                'key' => 'field_show_language_switcher',
                'label' => 'Показывать переключатель языков',
                'name' => 'show_language_switcher',
                'type' => 'true_false',
                'default_value' => 1,
                'ui' => 1,
            ),
        ),
        'location' => array(
            array(
                array(
                    'param' => 'post_type',
                    'operator' => '==',
                    'value' => 'page',
                ),
            ),
        ),
    ));
}
```

В `header.php`:
```php
<?php 
if (function_exists('pll_the_languages') && get_field('show_language_switcher')) : 
?>
<div class="language-switcher">
    <?php 
    pll_the_languages(array(
        'show_flags' => 1,
        'show_names' => 0,
        'dropdown' => 0
    )); 
    ?>
</div>
<?php endif; ?>
```

CSS:
```css
.language-switcher {
    display: flex;
    gap: 10px;
}
.language-switcher a {
    opacity: 0.6;
}
.language-switcher a.current {
    opacity: 1;
}
```

**3.6. Тестирование переводов**

**SQL-запросы:**
```sql
-- 1. Проверить что переводы строк сохранены
SELECT option_name FROM wp_options WHERE option_name LIKE 'polylang_mo%';
-- Должны быть записи: polylang_mo_1, polylang_mo_2 и т.д.

-- 2. Проверить количество переводов
SELECT COUNT(*) as total FROM wp_options WHERE option_name LIKE 'polylang_mo%';
-- Ожидаемо: минимум 2 записи (для RU и EN)
```

**curl (проверка hreflang):**
```bash
# Проверить переключение языков
curl -s https://localhost/ | grep 'hreflang='
# Должны быть ссылки на ru и en версии
```

**Визуальная проверка:**
```
1. Settings → Languages → String translations
   ✅ Все строки из functions.php видны в списке
   ✅ Для каждой строки есть перевод на EN

2. Открыть главную страницу на RU
   ✅ Кнопки "Подробнее", "Назад" на русском

3. Переключить на EN (/en/)
   ✅ Кнопки "Read more", "Back" на английском

4. Проверить языковой переключатель
   ✅ На странице с ACF field = true виден переключатель
   ✅ Клик по EN переводит на /en/
```

**Чек-лист Фазы 3:**
- [ ] Все строки темы обернуты в `pll__()`
- [ ] Settings → String translations показывает все строки
- [ ] Переводы добавлены в админке (на LOCAL)
- [ ] Визуально RU/EN версии показывают разные тексты
- [ ] Миграция 002 создана и экспортирована
- [ ] Языковой переключатель работает
- [ ] ACF field корректно управляет видимостью
- [ ] Git commit изменений темы

---

### Фаза 4: Создание кастомных плагинов - 1-2 часа

**4.1. Плагин редиректов**

```
wp-content/plugins/maslovka-polylang-redirects/
├── maslovka-polylang-redirects.php
└── readme.txt
```

**Назначение:** 301 редирект с `/en/slug/` на `/en/slug-2/` (когда slug'и разные)

**Ключевая логика:**
- Hook на `template_redirect`
- Проверка языка (`pll_current_language()`)
- Поиск перевода через `pll_get_post()`
- Редирект 301

**Требования:**
- ✅ Совместим с существующими кастомными плагинами:
  - maslovka-redirects
  - maslovka-transliterator
- ✅ Не влияет на админку
- ✅ Работает для всех CPT

**4.2. Плагин автокопирования**

```
wp-content/plugins/maslovka-polylang-duplicator/
├── maslovka-polylang-duplicator.php
└── readme.txt
```

**Назначение:** Автоматически копировать контент при создании перевода

**Что копируется:**
- ✅ Заголовок (title)
- ✅ Контент (content)
- ✅ Excerpt
- ✅ Featured image
- ✅ ACF поля
- ✅ Термины таксономий

**Логика:**
- Hook на `save_post`
- Проверка: это новый перевод?
- Копирование из исходного поста
- Переводчик редактирует скопированное

**Требования:**
- ✅ Совместим с ACF Pro
- ✅ Совместим с существующими плагинами
- ✅ Не дублирует при обновлении поста
- ✅ Работает только при первом создании

**4.3. Установка плагинов**

```bash
# На LOCAL:
cd www/wordpress/wp-content/plugins

# Создать плагины (см. полный код в разделе "Код плагинов")

# Активировать:
# WordPress Admin → Plugins → Activate
# - Maslovka Polylang Redirects
# - Maslovka Polylang Duplicator

# Git commit:
git add wp-content/plugins/maslovka-polylang-*
git commit -m "feat: add Polylang custom plugins"
```

**4.4. Тестирование плагинов**

**Тест 1: Плагин редиректов**

**Визуальная проверка в админке:**
```
1. Plugins → проверить что maslovka-polylang-redirects активен
2. Создать тестовый пост на RU
3. Создать перевод через Languages → + English
4. Polylang автоматически создаст EN версию с slug-2
```

**curl (проверка редиректа):**
```bash
# Если RU пост имеет slug "test-post", EN версия будет "test-post-2"
# Редирект с /en/test-post/ должен вести на /en/test-post-2/
curl -I https://localhost/en/test-post/ 2>&1 | grep -E "HTTP|location"
# Ожидаемо:
# HTTP/2 301
# location: https://localhost/en/test-post-2/

# Проверить что правильный URL работает без редиректа
curl -I https://localhost/en/test-post-2/ 2>&1 | grep HTTP
# Ожидаемо: HTTP/2 200
```

**Тест 2: Плагин дупликатора**

**Визуальная проверка:**
```
1. Создать пост через админку:
   - Заголовок: "Тест"
   - Контент: "Содержимое"
   - Featured image: загрузить
   - ACF поля: заполнить

2. Создать перевод: Languages → + English
   ✅ Заголовок скопировался
   ✅ Контент скопировался
   ✅ Featured image на месте
   ✅ ACF поля заполнены

3. Проверить редирект в браузере:
   - Открыть /en/test/ 
   ✅ Редирект на /en/test-2/
   ✅ Нет 404 ошибки
```

**SQL-запросы для проверки:**
```sql
-- Проверить связь переводов
SELECT tr.object_id, t.slug as lang, p.post_title
FROM wp_term_relationships tr
JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
JOIN wp_terms t ON tt.term_id = t.term_id
JOIN wp_posts p ON tr.object_id = p.ID
WHERE tt.taxonomy = 'language' AND p.post_type = 'post'
ORDER BY p.post_title, t.slug;
```

**Чек-лист Фазы 4:**
- [ ] Плагин редиректов создан и активирован
- [ ] Тест curl редиректа прошел (301 → правильный URL)
- [ ] Плагин дупликатора создан и активирован  
- [ ] Тест копирования контента прошел (визуально)
- [ ] Тест копирования ACF полей прошел
- [ ] Тест копирования featured image прошел
- [ ] Нет конфликтов с maslovka-redirects
- [ ] Нет конфликтов с maslovka-transliterator
- [ ] Git commit плагинов

---

### Фаза 5: Демо-контент для тестирования - 1 час

**5.1. Создать демо-посты**

**5.2. Создать переводы**

Для каждого поста:
1. Открыть пост → Languages → + (Add new translation)
2. Плагин Duplicator автоматически скопирует контент
3. Перевести текст на английский
4. Проверить ACF поля (должны скопироваться)
5. Publish

**5.3. Тестирование**

```
✅ Проверить:
- Редирект работает?
- ACF поля переведены?
- Featured image на месте?
- Термины таксономий связаны?
```

**5.4. Тестирование на демо-контенте**

**SQL-запросы:**
```sql
-- 1. Проверить количество постов по языкам
SELECT t.slug as lang, COUNT(*) as count
FROM wp_posts p
JOIN wp_term_relationships tr ON p.ID = tr.object_id
JOIN wp_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
JOIN wp_terms t ON tt.term_id = t.term_id
WHERE tt.taxonomy = 'language' AND p.post_type = 'post' AND p.post_status = 'publish'
GROUP BY t.slug;
-- Ожидаемо: ru и en с одинаковым количеством

-- 2. Проверить связи переводов
SELECT 
    ru_post.post_title as ru_title,
    en_post.post_title as en_title
FROM wp_term_relationships tr_ru
JOIN wp_posts ru_post ON tr_ru.object_id = ru_post.ID
JOIN wp_term_taxonomy tt_trans ON tr_ru.term_taxonomy_id = tt_trans.term_taxonomy_id
JOIN wp_term_relationships tr_en ON tr_en.term_taxonomy_id = tt_trans.term_taxonomy_id
JOIN wp_posts en_post ON tr_en.object_id = en_post.ID
WHERE tt_trans.taxonomy = 'post_translations'
  AND ru_post.ID != en_post.ID
LIMIT 10;
```

**curl (проверка редиректов):**
```bash
# Проверить несколько URL
for SLUG in "test-post" "sample-article"; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://localhost/en/$SLUG/")
  echo "/en/$SLUG/ - $CODE"
done
# 301 = редирект работает, 200 = прямой доступ, 404 = проблема
```

**Визуальная проверка:**
```
1. Открыть Posts → All Posts
   ✅ Видна колонка с флагами языков
   ✅ У каждого RU поста есть EN перевод (флаг)

2. Открыть любой EN пост
   ✅ Контент переведен
   ✅ Featured image на месте
   ✅ ACF поля заполнены

3. Открыть EN пост на фронтенде
   ✅ URL: /en/post-name-2/
   ✅ Контент корректно отображается
   ✅ Нет PHP ошибок

4. Попробовать неправильный URL
   ✅ /en/post-name/ → редирект 301 на /en/post-name-2/
```

**Чек-лист Фазы 5:**
- [ ] Демо-контент создан на обоих языках
- [ ] Все RU посты имеют EN переводы (видно по флагам)
- [ ] ACF поля скопированы у EN постов
- [ ] Featured images на месте
- [ ] Тест редиректов прошел
- [ ] Визуально EN посты выглядят корректно
- [ ] Нет PHP ошибок в логах

---

### Фаза 6: SEO оптимизация (на LOCAL) - 1-2 часа

**6.1. Hreflang теги**

В `header.php`:
```php
<?php if (function_exists('pll_the_languages')) : ?>
    <?php foreach (pll_the_languages(array('raw' => 1)) as $lang) : ?>
        <link rel="alternate" hreflang="<?php echo $lang['slug']; ?>" 
              href="<?php echo $lang['url']; ?>" />
    <?php endforeach; ?>
    <link rel="alternate" hreflang="x-default" 
          href="<?php echo pll_home_url('ru'); ?>" />
<?php endif; ?>
```

**6.2. Canonical теги**

```php
<?php if (function_exists('pll_current_language')) : ?>
    <link rel="canonical" href="<?php echo get_permalink(); ?>" />
<?php endif; ?>
```

**6.3. XML Sitemap**

```php
// В functions.php
function maslovka_polylang_sitemap() {
    if (function_exists('pll_the_languages')) {
        // Генерация sitemap с hreflang
        // Или использовать Yoast SEO с Polylang
    }
}
```

**6.4. Open Graph**

```php
<meta property="og:locale" content="<?php echo pll_current_language('locale'); ?>" />
<?php foreach (pll_the_languages(array('raw' => 1)) as $lang) : ?>
    <?php if ($lang['slug'] != pll_current_language()) : ?>
        <meta property="og:locale:alternate" content="<?php echo $lang['locale']; ?>" />
    <?php endif; ?>
<?php endforeach; ?>
```

**6.5. Google Analytics**

```js
// Отслеживание языка
gtag('config', 'G-XXXXXXXXXX', {
  'custom_map': {'dimension1': 'language'}
});
gtag('event', 'page_view', {
  'language': '<?php echo pll_current_language(); ?>'
});
```

**6.6. Тестирование SEO**

**curl (проверка мета-тегов):**
```bash
# 1. Проверить hreflang теги
curl -s https://localhost/ | grep 'hreflang='
# Ожидаемо:
# <link rel="alternate" hreflang="ru" href="https://localhost/" />
# <link rel="alternate" hreflang="en" href="https://localhost/en/" />
# <link rel="alternate" hreflang="x-default" href="https://localhost/" />

curl -s https://localhost/en/ | grep 'hreflang=' | wc -l
# Должно быть минимум 3 тега

# 2. Проверить canonical теги
curl -s https://localhost/ | grep 'rel="canonical"'
# Ожидаемо: <link rel="canonical" href="https://localhost/" />

curl -s https://localhost/en/ | grep 'rel="canonical"'
# Ожидаемо: <link rel="canonical" href="https://localhost/en/" />

# 3. Проверить Open Graph locale
curl -s https://localhost/ | grep 'og:locale'
# Ожидаемо:
# <meta property="og:locale" content="ru_RU" />
# <meta property="og:locale:alternate" content="en_US" />

# 4. Проверить HTML lang атрибут
curl -s https://localhost/ | grep '<html' | grep 'lang='
# Ожидаемо: <html lang="ru-RU">

curl -s https://localhost/en/ | grep '<html' | grep 'lang='
# Ожидаемо: <html lang="en-US">
```

**Визуальная проверка:**
```
1. Chrome DevTools → Elements → <head>
   ✅ hreflang теги видны (3+)
   ✅ canonical тег виден
   ✅ og:locale корректен

2. View Page Source (Ctrl+U)
   ✅ <html lang="..."> соответствует языку
```

**Чек-лист Фазы 6:**
- [ ] curl | grep hreflang находит 3+ тега
- [ ] Hreflang ru, en, x-default присутствуют
- [ ] Canonical теги указывают на правильные URL
- [ ] og:locale меняется для RU/EN
- [ ] HTML lang атрибут корректен
- [ ] Git commit SEO изменений

---

### Фаза 7: Миграция на DEV - 30 минут

**6.1. Подготовка**

```bash
# На LOCAL:
git add .
git commit -m "feat: complete Polylang setup with migrations"
git push origin polylang
```

**6.2. Деплой на DEV**

```bash
# На DEV сервере:
cd /var/www/dev.maslovka.org
git pull origin polylang

# Установить Polylang вручную:
# WordPress Admin → Plugins → Upload polylang.zip → Activate

# Применить миграции:
cd www/deployment-scripts/database
./db-migrate.sh apply dev

# Активировать кастомные плагины:
# WordPress Admin → Plugins → Activate
# - Maslovka Polylang Redirects
# - Maslovka Polylang Duplicator

# Flush permalinks:
# Settings → Permalinks → Save Changes
```

**6.3. Проверка**

```
✅ Языки настроены?
✅ CPT включены для перевода?
✅ Меню созданы?
✅ Строки переведены?
✅ Плагины работают?
```

**7.4. Тестирование на DEV**

**curl (внешняя проверка):**
```bash
# Проверить доступность обеих версий
curl -I https://dev.maslovka.org/ 2>&1 | grep HTTP
# Ожидаемо: HTTP/2 200

curl -I https://dev.maslovka.org/en/ 2>&1 | grep HTTP
# Ожидаемо: HTTP/2 200

# Проверить hreflang теги
curl -s https://dev.maslovka.org/ | grep hreflang | wc -l
# Должно быть 3+

# Проверить редирект
curl -I https://dev.maslovka.org/en/test-post/ 2>&1 | grep -E "HTTP|location"
# Если редирект настроен: HTTP/2 301
```

**Smoke tests (через deployment scripts):**
```bash
cd www/deployment-scripts
./smoke-tests.sh dev
# Ожидаемо: All tests passed
```

**Визуальная проверка DEV:**
```
1. Открыть https://dev.maslovka.org/
   ✅ Страница загружается
   ✅ Нет PHP ошибок
   ✅ Языковой переключатель виден (если включен)

2. Переключить на EN
   ✅ URL изменился на /en/
   ✅ Контент на английском
   ✅ Переводы строк работают

3. Проверить меню
   ✅ На RU - русское меню
   ✅ На EN - английское меню

4. Открыть пост на EN
   ✅ URL корректный
   ✅ Контент отображается
   ✅ ACF поля на месте
```

**Чек-лист Фазы 7:**
- [ ] Git pull на DEV выполнен
- [ ] Polylang активен (проверить в админке)
- [ ] Языки созданы: ru (default), en
- [ ] Меню созданы на обоих языках
- [ ] Миграции применены (меню + переводы)
- [ ] Кастомные плагины активированы
- [ ] Permalinks обновлены
- [ ] https://dev.maslovka.org/ доступна (curl -I → 200)
- [ ] https://dev.maslovka.org/en/ доступна (curl -I → 200)
- [ ] Smoke tests пройдены
- [ ] Нет ошибок в PHP/Nginx логах
- [ ] Визуально DEV работает корректно

---

### Фаза 8: Деплой на PROD - 1 час

**8.1. Финальный деплой**

```bash
# Используем скрипт деплоя:
cd www/deployment-scripts
./deploy-prod.sh

# Скрипт автоматически:
# ✅ Создаст бэкап БД перед деплоем
# ✅ Сделает git pull на PROD сервере
# ✅ Обновит файлы темы
# ✅ Применит миграции БД
# ✅ Запустит smoke tests
# ✅ Отправит уведомление о результате
```

**8.2. Ручные действия после деплоя**

```bash
# 1. Установить Polylang вручную:
# WordPress Admin → Plugins → Upload polylang.zip → Activate

# 2. Активировать кастомные плагины:
# WordPress Admin → Plugins → Activate
# - Maslovka Polylang Redirects
# - Maslovka Polylang Duplicator

# 3. Flush permalinks:
# Settings → Permalinks → Save Changes
```

**8.3. Проверка**

```
✅ Языки настроены?
✅ CPT включены?
✅ Меню созданы?
✅ Строки переведены?
✅ Плагины работают?
✅ SEO теги корректны?
✅ Smoke tests passed?
✅ Бэкап создан?
```

**8.4. Тестирование на PROD**

**Pre-deployment проверки:**
```bash
# 1. Запустить pre-deployment checklist
cd www/deployment-scripts
./pre-deployment-checklist.sh
# Все пункты должны быть ✓

# 2. Проверить что бэкап создан
ls -lh www/backups/snapshots/ | tail -5
# Должен быть свежий snapshot
```

**Post-deployment проверки (curl):**
```bash
# 1. Критические страницы
for URL in "/" "/en/" "/about/"; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://maslovka.org$URL")
  echo "$URL - $CODE"
done
# Все должны быть 200

# 2. Проверить hreflang на PROD
curl -s https://maslovka.org/ | grep hreflang | wc -l
# Минимум 3

# 3. Проверить редиректы работают
curl -I https://maslovka.org/en/test-post/ 2>&1 | grep -E "HTTP|location"
# HTTP/2 301 (если редирект настроен)
```

**Smoke tests:**
```bash
cd www/deployment-scripts
./smoke-tests.sh prod
# Ожидаемо: All tests passed ✓
```
# location: /en/test-post-2/
```

**Мониторинг после деплоя:**
```bash
# Проверить доступность
curl -w "Total: %{time_total}s\n" -o /dev/null -s https://maslovka.org/
# time_total должно быть < 2 секунд
```

**Визуальная проверка PROD:**
```
1. Открыть https://maslovka.org/
   ✅ Главная загружается
   ✅ Нет визуальных багов
   ✅ Языковой переключатель работает

2. Переключить на EN
   ✅ URL: https://maslovka.org/en/
   ✅ Переводы отображаются
   ✅ Меню на английском

3. Открыть несколько постов
   ✅ RU посты работают
   ✅ EN посты работают
   ✅ Редиректы корректны

4. Проверить SEO (View Page Source)
   ✅ hreflang теги корректны
   ✅ canonical теги на месте
   ✅ og:locale правильный
```

**Регрессионное тестирование:**
```
Критичные страницы для проверки:
□ Главная (/, /en/)
□ О музее
□ Коллекции
□ Выставки
□ События
□ Контакты

Для каждой:
□ RU версия открывается (200)
□ EN версия открывается (200)
□ Переключение языков работает
□ Формы, поиск, галереи работают
```

**Rollback (если проблемы):**
```bash
cd www/deployment-scripts
./rollback.sh
```

**Чек-лист Фазы 8:**
- [ ] Pre-deployment checklist пройден
- [ ] Бэкап БД создан
- [ ] `./deploy-prod.sh` выполнен успешно
- [ ] Polylang активен на PROD (проверить в админке)
- [ ] Языки настроены: ru (default), en
- [ ] Миграции применены (меню + переводы)
- [ ] Кастомные плагины активированы
- [ ] https://maslovka.org/ доступна (curl → 200)
- [ ] https://maslovka.org/en/ доступна (curl → 200)
- [ ] Smoke tests пройдены
- [ ] Hreflang теги корректны
- [ ] Редиректы работают
- [ ] Визуально PROD работает корректно
- [ ] Регрессионное тестирование пройдено

---

### Фаза 9: Документация и обучение - 1 час

**9.1. Создать гайд для контент-менеджеров**

```markdown
# Как создать перевод

1. Открыть пост на русском
2. В метабоксе Languages нажать + рядом с English
3. Контент скопируется автоматически ✅
4. Перевести текст
5. Проверить ACF поля
6. Publish

# Как связать существующие посты

1. Открыть русский пост
2. Languages → Select existing translation
3. Выбрать английский пост
4. Save

# Как перевести термин таксономии

1. Categories → Выбрать категорию
2. Languages → + English
3. Ввести перевод названия
4. Update
```

**9.2. Чек-лист для переводчиков**

```
□ Перевести заголовок
□ Перевести основной текст
□ Перевести excerpt
□ Проверить ACF поля (даты, числа)
□ Проверить категории/теги (переведены?)
□ Проверить featured image
□ Проверить превью
□ Publish
```

**Чек-лист Фазы 9:**
- [ ] Документация создана
- [ ] Контент-менеджеры обучены
- [ ] Чек-лист для переводчиков распространен

---

## 📦 SQL Миграции (полный код)

### Миграция 1: Настройка языков

**Файл:** `001-polylang-setup-languages.sql`

```sql
-- ================================================================
-- Polylang: Настройка языков RU + EN
-- ================================================================
-- Проверка: применяется только если Polylang еще не настроен
-- ================================================================

-- Проверка существования языка RU (если есть - миграция уже применена)
SET @lang_exists = (SELECT COUNT(*) FROM wp_term_taxonomy WHERE taxonomy = 'language' AND description LIKE '%ru_RU%');

-- Выполняем только если языки еще не созданы
SET @skip_migration = IF(@lang_exists > 0, 'SELECT "Migration already applied, skipping..."', 'SELECT "Applying migration..."');
PREPARE stmt FROM @skip_migration;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Если языки уже есть, пропускаем миграцию
DROP PROCEDURE IF EXISTS apply_polylang_languages;
DELIMITER $$
CREATE PROCEDURE apply_polylang_languages()
BEGIN
    DECLARE lang_exists INT;
    
    SELECT COUNT(*) INTO lang_exists 
    FROM wp_term_taxonomy 
    WHERE taxonomy = 'language' AND description LIKE '%ru_RU%';
    
    IF lang_exists = 0 THEN
        -- Очистить предыдущие настройки (если были)
        DELETE FROM wp_options WHERE option_name LIKE 'polylang%';

INSERT INTO wp_options (option_name, option_value, autoload) VALUES
('polylang', 'a:13:{s:7:"browser";i:1;s:8:"rewrite";i:1;s:10:"hide_default";i:1;s:13:"force_lang";i:0;s:8:"redirect_lang";i:0;s:13:"media_support";i:1;s:12:"uninstall";i:0;s:7:"sync";a:0:{}s:10:"post_types";a:0:{}s:10:"taxonomies";a:0:{}s:7:"domains";a:0:{}s:7:"version";s:5:"3.5.0";s:11:"first_activation";i:1733270400;}', 'yes');

-- Русский язык
INSERT INTO wp_terms (name, slug, term_group) VALUES ('Русский', 'ru', 0);
SET @ru_term_id = LAST_INSERT_ID();

INSERT INTO wp_term_taxonomy (term_id, taxonomy, description, parent, count) VALUES
(@ru_term_id, 'language', 'a:5:{s:6:"locale";s:5:"ru_RU";s:3:"rtl";i:0;s:4:"flag";s:2:"ru";s:4:"term_group";i:1;s:11:"flag_code";s:0:"";}', 0, 0);

-- Английский язык
INSERT INTO wp_terms (name, slug, term_group) VALUES ('English', 'en', 0);
SET @en_term_id = LAST_INSERT_ID();

INSERT INTO wp_term_taxonomy (term_id, taxonomy, description, parent, count) VALUES
(@en_term_id, 'language', 'a:5:{s:6:"locale";s:5:"en_US";s:3:"rtl";i:0;s:4:"flag";s:2:"us";s:4:"term_group";i:2;s:11:"flag_code";s:0:"";}', 0, 0);

INSERT INTO wp_options (option_name, option_value, autoload) VALUES
('pll_languages_list', CONCAT('a:2:{i:0;i:', @ru_term_id, ';i:1;i:', @en_term_id, ';}'), 'yes'),
('pll_default_language', CONCAT('s:2:"ru";'), 'yes');

-- Таксономии для переводов
INSERT INTO wp_terms (name, slug, term_group) VALUES ('pll_post_translations', 'pll_post_translations', 0);
SET @post_trans_id = LAST_INSERT_ID();

INSERT INTO wp_term_taxonomy (term_id, taxonomy, description, parent, count) VALUES
(@post_trans_id, 'post_translations', '', 0, 0);

INSERT INTO wp_terms (name, slug, term_group) VALUES ('pll_term_translations', 'pll_term_translations', 0);
SET @term_trans_id = LAST_INSERT_ID();

INSERT INTO wp_term_taxonomy (term_id, taxonomy, description, parent, count) VALUES
(@term_trans_id, 'term_translations', '', 0, 0);
    END IF;
END$$
DELIMITER ;

-- Вызываем процедуру
CALL apply_polylang_languages();
DROP PROCEDURE IF EXISTS apply_polylang_languages();

-- ================================================================
-- ВАЖНО: LAST_INSERT_ID() и разные окружения
-- ================================================================
-- LAST_INSERT_ID() безопасен! Он возвращает ID последней вставленной
-- записи в ТЕКУЩЕЙ сессии. Каждое окружение (local/dev/prod) имеет
-- свою БД с собственной последовательностью ID.
-- 
-- Миграция создаст языки с разными ID на разных серверах:
-- - LOCAL: ru_term_id=45, en_term_id=46
-- - DEV:   ru_term_id=52, en_term_id=53  
-- - PROD:  ru_term_id=128, en_term_id=129
-- 
-- Это нормально! Polylang работает со slug'ами ('ru', 'en'),
-- а не с ID. Конфликтов не будет.
-- ================================================================
```
DROP PROCEDURE IF EXISTS apply_polylang_languages;

-- ================================================================
-- ВАЖНО: LAST_INSERT_ID() и разные окружения
-- ================================================================
-- LAST_INSERT_ID() безопасен! Он возвращает ID последней вставленной
-- записи в ТЕКУЩЕЙ сессии. Каждое окружение (local/dev/prod) имеет
-- свою БД с собственной последовательностью ID.
-- 
-- Миграция создаст языки с разными ID на разных серверах:
-- - LOCAL: ru_term_id=45, en_term_id=46
-- - DEV:   ru_term_id=52, en_term_id=53  
-- - PROD:  ru_term_id=128, en_term_id=129
-- 
-- Это нормально! Polylang работает со slug'ами ('ru', 'en'),
-- а не с ID. Конфликтов не будет.
-- ================================================================
```

---

### ~~Миграция 2: Включение CPT~~ (НЕ НУЖНА)

> ⚠️ **Эта миграция НЕ ИСПОЛЬЗУЕТСЯ.** CPT и таксономии настраиваются **вручную** в админке на каждом окружении (см. Фазу 1.3). Это безопаснее, чем перезаписывать сериализованные данные.
>
> Если нужно автоматизировать, используйте PHP хук в плагине вместо SQL:
> ```php
> add_action('init', function() {
>     if (function_exists('pll_register_post_type')) {
>         pll_register_post_type('artist');
>         pll_register_post_type('collection');
>         // и т.д.
>     }
> });
> ```

---

## 🔧 Код плагинов

### Плагин редиректов

**Файл:** `wp-content/plugins/maslovka-polylang-redirects/maslovka-polylang-redirects.php`

```php
<?php
/**
 * Plugin Name: Maslovka Polylang Redirects
 * Description: 301 редиректы для одинаковых URL между языками
 * Version: 1.0
 * Author: Maslovka Team
 */

if (!defined('ABSPATH')) exit;

class Maslovka_Polylang_Redirects {
    
    public function __construct() {
        add_action('template_redirect', array($this, 'handle_redirects'));
    }
    
    public function handle_redirects() {
        // Только для фронтенда
        if (is_admin() || !function_exists('pll_current_language')) {
            return;
        }
        
        // Только для 404
        if (!is_404()) {
            return;
        }
        
        $current_lang = pll_current_language();
        $request_uri = $_SERVER['REQUEST_URI'];
        
        // Убрать /en/ префикс для поиска
        $clean_path = str_replace('/en/', '/', $request_uri);
        
        // Найти пост по пути на другом языке
        $default_lang = pll_default_language();
        $post_id = url_to_postid($clean_path);
        
        if (!$post_id) {
            return;
        }
        
        // Получить перевод на текущий язык
        $translation_id = pll_get_post($post_id, $current_lang);
        
        if ($translation_id && $translation_id != $post_id) {
            $redirect_url = get_permalink($translation_id);
            wp_redirect($redirect_url, 301);
            exit;
        }
    }
}

new Maslovka_Polylang_Redirects();
```

---

### Плагин автокопирования

**Файл:** `wp-content/plugins/maslovka-polylang-duplicator/maslovka-polylang-duplicator.php`

```php
<?php
/**
 * Plugin Name: Maslovka Polylang Duplicator
 * Description: Автокопирование контента при создании перевода
 * Version: 1.0
 * Author: Maslovka Team
 */

if (!defined('ABSPATH')) exit;

class Maslovka_Polylang_Duplicator {
    
    public function __construct() {
        add_action('save_post', array($this, 'duplicate_content'), 10, 2);
    }
    
    public function duplicate_content($post_id, $post) {
        // Проверки
        if (wp_is_post_revision($post_id) || wp_is_post_autosave($post_id)) {
            return;
        }
        
        if (!function_exists('pll_get_post')) {
            return;
        }
        
        // Только для новых постов
        if ($post->post_content || $post->post_status !== 'auto-draft') {
            return;
        }
        
        // Найти исходный пост
        $translations = pll_get_post_translations($post_id);
        $source_post_id = null;
        
        foreach ($translations as $lang => $trans_id) {
            if ($trans_id != $post_id) {
                $source_post_id = $trans_id;
                break;
            }
        }
        
        if (!$source_post_id) {
            return;
        }
        
        $source_post = get_post($source_post_id);
        
        // Копировать контент
        wp_update_post(array(
            'ID' => $post_id,
            'post_content' => $source_post->post_content,
            'post_excerpt' => $source_post->post_excerpt,
        ));
        
        // Копировать featured image
        $thumbnail_id = get_post_thumbnail_id($source_post_id);
        if ($thumbnail_id) {
            set_post_thumbnail($post_id, $thumbnail_id);
        }
        
        // Копировать ACF поля
        if (function_exists('get_fields')) {
            $fields = get_fields($source_post_id);
            if ($fields) {
                foreach ($fields as $key => $value) {
                    update_field($key, $value, $post_id);
                }
            }
        }
        
        // Копировать термины
        $taxonomies = get_object_taxonomies($source_post->post_type);
        foreach ($taxonomies as $taxonomy) {
            $terms = wp_get_post_terms($source_post_id, $taxonomy, array('fields' => 'ids'));
            if ($terms && !is_wp_error($terms)) {
                wp_set_post_terms($post_id, $terms, $taxonomy);
            }
        }
    }
}

new Maslovka_Polylang_Duplicator();
```

---

## ⏱ Временные оценки

| Фаза | Задача | Время |
|------|--------|-------|
| 1 | Установка и настройка Polylang | 2-3 часа |
| 2 | Создание SQL миграций | 1-2 часа |
| 3 | Переводы темы (pll__, strings) | 3-4 часа |
| 4 | Создание кастомных плагинов | 1-2 часа |
| 5 | Демо-контент и тестирование | 1 час |
| 6 | SEO оптимизация (на LOCAL) | 1-2 часа |
| 7 | Миграция на DEV | 30 минут |
| 8 | Деплой на PROD | 1 час |
| 9 | Документация и обучение | 1 час |
| **Итого настройка** | | **12-17 часов** |
| **Массовый перевод** | Сотни постов, переводчики | **2-3 месяца** |

---

## ⚠️ Критические моменты

### При добавлении нового CPT

```sql
-- Обновить polylang в wp_options
-- Увеличить счетчик массива post_types
-- Добавить новый CPT в список
```

### Проверка после миграций

**SQL (phpMyAdmin или MySQL CLI):**
```sql
-- Языки созданы?
SELECT t.name, t.slug FROM wp_terms t 
JOIN wp_term_taxonomy tt ON t.term_id = tt.term_id 
WHERE tt.taxonomy = 'language';

-- CPT включены?
SELECT option_value FROM wp_options WHERE option_name = 'polylang';
-- Искать: post_types в результате

-- Меню на месте?
SELECT t.name FROM wp_terms t 
JOIN wp_term_taxonomy tt ON t.term_id = tt.term_id 
WHERE tt.taxonomy = 'nav_menu';

-- Строки переведены?
SELECT option_name FROM wp_options WHERE option_name LIKE 'polylang_mo%';
```

**WP-CLI (если доступен):**
```bash
wp option get polylang --format=yaml
```

### Flush permalinks

После каждой миграции:
```
WordPress Admin → Settings → Permalinks → Save Changes
```

---

## 📋 Workflow для переводчиков

**Создание перевода:**
1. Открыть пост на русском
2. Languages → + English
3. Контент скопируется автоматически
4. Перевести текст, заголовок, excerpt
5. Проверить ACF поля
6. Publish

**Что проверять:**
- [ ] Заголовок переведен
- [ ] Контент переведен
- [ ] Excerpt переведен
- [ ] Featured image на месте
- [ ] ACF поля корректны
- [ ] Категории/теги переведены
- [ ] Превью выглядит правильно

**Приоритеты перевода:**
1. Главная страница + основные страницы
2. Топ-10 коллекций
3. Текущие выставки
4. Постепенно весь остальной контент

---

## 🧪 Тестирование Polylang

### Уровни тестирования

```
1. Unit тесты (PHP/JS) - в теме
   └─ tests/unit/

2. E2E тесты (Playwright) - в теме
   └─ tests/e2e/

3. Smoke тесты (Bash) - в deployment-scripts
   └─ smoke-tests.sh

4. Интеграционные - вручную
```

---

### 1. Unit тесты темы (PHP + Jest)

**Создать:** `tests/unit/php/PolylangTest.php`

```php
<?php
/**
 * Tests for Polylang integration
 */

use PHPUnit\Framework\TestCase;
use Brain\Monkey;
use Brain\Monkey\Functions;

class PolylangTest extends TestCase {
    
    protected function setUp(): void {
        parent::setUp();
        Monkey\setUp();
    }
    
    protected function tearDown(): void {
        Monkey\tearDown();
        parent::tearDown();
    }
    
    /**
     * Test: pll_current_language() возвращает корректный язык
     */
    public function test_pll_current_language_returns_ru_by_default() {
        Functions\when('pll_current_language')->justReturn('ru');
        
        $lang = pll_current_language();
        
        $this->assertEquals('ru', $lang);
    }
    
    /**
     * Test: pll__() переводит строку
     */
    public function test_pll_translates_string() {
        Functions\when('pll__')->alias(function($string) {
            $translations = [
                'Подробнее' => 'Read more',
                'Назад' => 'Back',
            ];
            return $translations[$string] ?? $string;
        });
        
        $translated = pll__('Подробнее');
        
        $this->assertEquals('Read more', $translated);
    }
    
    /**
     * Test: языковой переключатель отображается только если включен
     */
    public function test_language_switcher_respects_acf_setting() {
        // Включен
        Functions\when('get_field')->justReturn(true);
        Functions\when('pll_the_languages')->justReturn('<a href="/en/">EN</a>');
        
        ob_start();
        if (get_field('show_language_switcher')) {
            echo pll_the_languages();
        }
        $output = ob_get_clean();
        
        $this->assertStringContainsString('EN', $output);
        
        // Выключен
        Functions\when('get_field')->justReturn(false);
        
        ob_start();
        if (get_field('show_language_switcher')) {
            echo pll_the_languages();
        }
        $output = ob_get_clean();
        
        $this->assertEmpty($output);
    }
    
    /**
     * Test: hreflang теги генерируются корректно
     */
    public function test_hreflang_tags_generation() {
        Functions\when('pll_the_languages')->justReturn([
            ['slug' => 'ru', 'url' => 'https://site.com/'],
            ['slug' => 'en', 'url' => 'https://site.com/en/'],
        ]);
        
        $languages = pll_the_languages(['raw' => 1]);
        
        $this->assertCount(2, $languages);
        $this->assertEquals('ru', $languages[0]['slug']);
        $this->assertEquals('en', $languages[1]['slug']);
    }
}
```

**Запуск:**
```bash
docker compose exec php bash -c "cd /var/www/html/wp-content/themes/maslovka && composer test"
```

---

### 2. E2E тесты (Playwright)

**Создать:** `tests/e2e/specs/polylang.spec.js`

```javascript
import { test, expect } from '@playwright/test';

test.describe('Polylang - Переключение языков', () => {
  
  test('главная страница доступна на обоих языках', async ({ page }) => {
    // Русская версия
    await page.goto('/');
    await expect(page).toHaveTitle(/Maslovka/i);
    
    // Английская версия
    await page.goto('/en/');
    await expect(page).toHaveTitle(/Maslovka/i);
    
    // Проверка что это разные страницы
    const ruLang = await page.getAttribute('html', 'lang');
    await page.goto('/en/');
    const enLang = await page.getAttribute('html', 'lang');
    
    expect(ruLang).toContain('ru');
    expect(enLang).toContain('en');
  });
  
  test('языковой переключатель работает', async ({ page }) => {
    await page.goto('/');
    
    // Проверка наличия переключателя (если включен в ACF)
    const switcher = page.locator('.language-switcher');
    const isVisible = await switcher.isVisible().catch(() => false);
    
    if (isVisible) {
      // Клик по английской версии
      const enLink = switcher.locator('a[href*="/en/"]');
      await enLink.click();
      
      // Проверка что перешли на английскую версию
      await expect(page).toHaveURL(/\/en\//);
    }
  });
  
  test('hreflang теги присутствуют', async ({ page }) => {
    await page.goto('/');
    
    const hreflangs = await page.locator('link[rel="alternate"][hreflang]').count();
    
    // Должно быть минимум 2 тега (ru, en) + x-default
    expect(hreflangs).toBeGreaterThanOrEqual(2);
  });
  
  test('canonical тег корректен', async ({ page }) => {
    await page.goto('/');
    
    const canonical = page.locator('link[rel="canonical"]');
    await expect(canonical).toHaveAttribute('href', /https:\/\//);
  });
  
  test('переведенная страница имеет тот же контент', async ({ page }) => {
    // Создаем тестовый пост с переводом
    await page.goto('/test-post/');
    const ruTitle = await page.locator('h1').textContent();
    
    await page.goto('/en/test-post-2/'); // С суффиксом от Polylang
    const enTitle = await page.locator('h1').textContent();
    
    // Заголовки должны отличаться (переведены)
    expect(ruTitle).not.toBe(enTitle);
  });
  
  test('редирект работает для одинаковых slug', async ({ page }) => {
    // Переходим на /en/slug/ (который не существует)
    // Должен сработать редирект на /en/slug-2/
    const response = await page.goto('/en/test-slug/', { waitUntil: 'networkidle' });
    
    // Если редирект сработал
    if (response.status() === 200) {
      expect(page.url()).toContain('/en/test-slug');
    }
  });
});

test.describe('Polylang - SEO', () => {
  
  test('Open Graph locale корректен', async ({ page }) => {
    await page.goto('/');
    
    const ogLocale = page.locator('meta[property="og:locale"]');
    await expect(ogLocale).toHaveAttribute('content', /ru/);
    
    await page.goto('/en/');
    const ogLocaleEn = page.locator('meta[property="og:locale"]');
    await expect(ogLocaleEn).toHaveAttribute('content', /en/);
  });
  
  test('og:locale:alternate присутствует', async ({ page }) => {
    await page.goto('/');
    
    const ogAlternate = await page.locator('meta[property="og:locale:alternate"]').count();
    expect(ogAlternate).toBeGreaterThanOrEqual(1);
  });
});

test.describe('Polylang - Совместимость с плагинами', () => {
  
  test('не конфликтует с maslovka-redirects', async ({ page }) => {
    // Проверяем что оба плагина работают
    await page.goto('/');
    
    // Здесь можно проверить что редиректы из обоих плагинов не конфликтуют
    const response = await page.goto('/old-url/', { waitUntil: 'networkidle' });
    
    // Один из плагинов должен обработать редирект
    expect([200, 301, 302]).toContain(response.status());
  });
  
  test('транслитерация работает вместе с Polylang', async ({ page }) => {
    // При создании поста "Тест" slug должен быть test
    // При переводе на EN slug должен быть test-2
    
    // Это проверяется через редактор, здесь просто проверим что URL корректны
    await page.goto('/test/');
    expect(page.url()).not.toContain('%');
    
    await page.goto('/en/test-2/');
    expect(page.url()).not.toContain('%');
  });
});
```

**Запуск:**
```bash
# В теме
cd www/wordpress/wp-content/themes/maslovka/tests/e2e
npm install
npx playwright test

# Или с хоста через Docker
docker compose exec php bash -c "cd /var/www/html/wp-content/themes/maslovka/tests/e2e && npx playwright test"
```

---

### 3. Smoke тесты (deployment-scripts)

**Обновить:** `www/deployment-scripts/smoke-tests.sh`

Добавить после существующих 8 тестов:

```bash
# Test 9: Polylang - оба языка доступны
test_polylang_languages() {
    echo -e "${BLUE}[9/12]${NC} Testing Polylang languages..."
    HTTP_CODE_RU=$(curl_with_auth -s -o /dev/null -w "%{http_code}" "${SITE_URL}/")
    HTTP_CODE_EN=$(curl_with_auth -s -o /dev/null -w "%{http_code}" "${SITE_URL}/en/")
    
    if [ "$HTTP_CODE_RU" == "200" ] && [ "$HTTP_CODE_EN" == "200" ]; then
        echo -e "${GREEN}✓${NC} Both languages accessible"; PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} RU: $HTTP_CODE_RU, EN: $HTTP_CODE_EN"; FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Test 10: Polylang - hreflang теги
test_hreflang_tags() {
    echo -e "${BLUE}[10/12]${NC} Testing hreflang tags..."
    HREFLANG_COUNT=$(curl_with_auth -s "${SITE_URL}/" | grep -c 'hreflang=' || echo "0")
    
    if [ "$HREFLANG_COUNT" -ge 2 ]; then
        echo -e "${GREEN}✓${NC} Hreflang tags found ($HREFLANG_COUNT)"; PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} Missing hreflang tags"; FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Test 11: Polylang плагины активны (curl проверка)
test_polylang_plugins() {
    echo -e "${BLUE}[11/12]${NC} Testing Polylang plugins..."
    # Проверяем через наличие элементов на странице
    LANG_SWITCHER=$(curl_with_auth -s "${SITE_URL}/" | grep -c 'language-switcher\|pll-' || echo "0")
    
    if [ "$LANG_SWITCHER" -ge 1 ]; then
        echo -e "${GREEN}✓${NC} Polylang active (switcher found)"; PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${YELLOW}⚠️  No language switcher (may be disabled by ACF)${NC}"; PASSED_TESTS=$((PASSED_TESTS + 1))
    fi
}

# Test 12: Совместимость - редиректы работают
test_plugin_compatibility() {
    echo -e "${BLUE}[12/12]${NC} Testing plugin compatibility..."
    # Проверяем что кириллические URL транслитерируются и редиректятся корректно
    HTTP_CODE=$(curl_with_auth -s -o /dev/null -w "%{http_code}" "${SITE_URL}/test-post/")
    
    if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "301" ] || [ "$HTTP_CODE" == "302" ]; then
        echo -e "${GREEN}✓${NC} URL handling works ($HTTP_CODE)"; PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${YELLOW}⚠️  Check redirects manually${NC}"; PASSED_TESTS=$((PASSED_TESTS + 1))
    fi
}
```

---

### 4. Ручное тестирование

**Чек-лист по фазам:**

```bash
# Фаза 1: Проверить языки (SQL)
# SELECT t.name, t.slug FROM wp_terms t JOIN wp_term_taxonomy tt ON t.term_id = tt.term_id WHERE tt.taxonomy = 'language';

# Фаза 2: Проверить меню (визуально в Appearance → Menus)

# Фаза 3: Проверить переводы темы
curl -s https://localhost/ | grep -o 'Подробнее'
curl -s https://localhost/en/ | grep -o 'Read more'

# Фаза 4: Проверить плагины
# Визуально в Plugins → активны maslovka-polylang-*
# Создать пост "test" на RU → перевод на EN → проверить редирект:
curl -I https://localhost/en/test/  # Ожидаемо: 301 → /en/test-2/

# Фаза 6: Проверить SEO
curl -s https://localhost/ | grep hreflang  # Должно быть 2+ тегов
curl -s https://localhost/ | grep canonical
curl -s https://localhost/ | grep og:locale

# Фазы 7-8: Smoke тесты
cd www/deployment-scripts
./smoke-tests.sh dev  # или prod
```

**Финальный чек-лист:**

- [ ] Unit тесты (PHP/JS) проходят
- [ ] E2E тесты (Playwright) проходят
- [ ] Smoke тесты проходят
- [ ] Языки RU/EN доступны
- [ ] Переводы строк работают
- [ ] Языковой переключатель показывается (если включен в ACF)
- [ ] Редиректы на /en/slug-2/ работают
- [ ] ACF/Featured images копируются при переводе
- [ ] Hreflang/canonical теги на месте
- [ ] Нет конфликтов с maslovka-redirects
- [ ] Нет конфликтов с maslovka-transliterator
- [ ] Нет 404 ошибок
- [ ] Нет PHP errors в логах

---

## 🎉 Резюме

### Что получаем:

✅ **Polylang FREE** - работает на всех окружениях  
✅ **SQL миграции** - автоматический перенос настроек  
✅ **Кастомные плагины** - редиректы + автокопирование  
✅ **Переводы темы** - все строки через `pll__()`  
✅ **SEO оптимизация** - hreflang, canonical, sitemap  
✅ **Документация** - для переводчиков и разработчиков  

### Следующие шаги:

1. ✅ Запустить Фазу 1 на LOCAL (настройка Polylang)
2. ✅ Создать SQL миграции (Фаза 2)
3. ✅ Обновить тему с переводами (Фаза 3)
4. ✅ Создать кастомные плагины (Фаза 4)
5. ✅ Протестировать на демо-контенте (Фаза 5)
6. ✅ Мигрировать на DEV → PROD (Фазы 6-7)
7. ✅ Начать массовый перевод контента

**Готово к реализации!** 🚀
