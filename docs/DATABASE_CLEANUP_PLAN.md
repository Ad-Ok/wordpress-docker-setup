# 📊 План очистки и оптимизации базы данных

**Дата анализа:** 6 ноября 2025  
**База данных:** wordpress_db  
**Текущий размер:** ~25 МБ

---

## 📈 Результаты анализа

### Размеры таблиц

| Таблица | Размер (МБ) | Строки | Приоритет |
|---------|-------------|--------|-----------|
| wp_postmeta | 15.97 | 21,196 | ⚠️ Высокий |
| wp_posts | 6.06 | 3,879 | ⚠️ Высокий |
| wp_options | 2.58 | 501 | ⚠️ Высокий |
| wp_maslovka_redirects | 0.23 | 427 | ✅ OK |
| wp_actionscheduler_actions | 0.16 | 21 | 📌 Средний |
| wp_comments | 0.09 | 8 | 📌 Средний |

### Статистика по типам контента

| Тип контента | Статус | Количество |
|--------------|--------|------------|
| attachment | inherit | 2,488 |
| revision | inherit | 552 |
| artist | publish | 133 |
| collection | publish | 94 |
| collection | draft | 54 |
| acf-field | publish | 58 |
| events | publish | 12 |
| events | trash | 2 |
| events | auto-draft | 1 |
| vistavki | draft | 2 |

---

## 🗑️ **1. Удаление мусорных данных**

### **1.1 Ревизии постов** ⚠️ **ВЫСОКИЙ ПРИОРИТЕТ**
- **Найдено:** 552 ревизии
- **Потенциальная экономия:** ~3-5 МБ
- **Рекомендация:** Удалить старые ревизии, оставить последние 3-5 для каждого поста

**SQL запросы:**
```sql
-- Удалить все ревизии старше 30 дней
DELETE FROM wp_posts 
WHERE post_type = 'revision' 
AND post_date < DATE_SUB(NOW(), INTERVAL 30 DAY);

-- Удалить метаданные от удаленных ревизий
DELETE pm FROM wp_postmeta pm
LEFT JOIN wp_posts p ON pm.post_id = p.ID
WHERE p.ID IS NULL;
```

### **1.2 Спам-комментарии** ⚠️ **ВЫСОКИЙ ПРИОРИТЕТ**
- **Найдено:** 8 комментариев в статусе 'spam'
- **Потенциальная экономия:** ~50-100 КБ + связанные метаданные

**SQL запросы:**
```sql
-- Удалить спам-комментарии
DELETE FROM wp_comments WHERE comment_approved = 'spam';

-- Удалить метаданные спам-комментариев
DELETE FROM wp_commentmeta 
WHERE comment_id NOT IN (SELECT comment_id FROM wp_comments);
```

### **1.3 Корзина** 📌 **СРЕДНИЙ ПРИОРИТЕТ**
- **Найдено:** 2 поста в корзине (events)
- **Потенциальная экономия:** ~100-200 КБ

**SQL запросы:**
```sql
-- Очистить корзину
DELETE FROM wp_posts WHERE post_status = 'trash';

-- Очистить метаданные удаленных постов
DELETE pm FROM wp_postmeta pm
LEFT JOIN wp_posts p ON pm.post_id = p.ID
WHERE p.ID IS NULL;
```

### **1.4 Автосохранения** 📌 **СРЕДНИЙ ПРИОРИТЕТ**
- **Найдено:** 3 авто-черновика
- **Потенциальная экономия:** ~10-50 КБ

**SQL запросы:**
```sql
-- Удалить авто-черновики
DELETE FROM wp_posts WHERE post_status = 'auto-draft';
```

### **1.5 Неиспользуемые термины** 📌 **НИЗКИЙ ПРИОРИТЕТ**
- **Найдено:** 5 терминов без связей с постами
- **Потенциальная экономия:** ~5-10 КБ

**SQL запросы:**
```sql
-- Найти неиспользуемые термины
SELECT t.term_id, t.name, tt.taxonomy
FROM wp_terms t
INNER JOIN wp_term_taxonomy tt ON t.term_id = tt.term_id
LEFT JOIN wp_term_relationships tr ON tt.term_taxonomy_id = tr.term_taxonomy_id
WHERE tr.object_id IS NULL;

-- Удалить неиспользуемые термины (осторожно!)
DELETE t FROM wp_terms t
INNER JOIN wp_term_taxonomy tt ON t.term_id = tt.term_id
LEFT JOIN wp_term_relationships tr ON tt.term_taxonomy_id = tr.term_taxonomy_id
WHERE tr.object_id IS NULL;

DELETE FROM wp_term_taxonomy 
WHERE term_taxonomy_id NOT IN (
  SELECT DISTINCT term_taxonomy_id FROM wp_term_relationships
);
```

### **1.6 Неприкрепленные медиафайлы** ⚠️ **ПРОВЕРИТЬ ВРУЧНУЮ**
- **Найдено:** 75 attachment'ов без родительского поста
- **Потенциальная экономия:** ~500 КБ в БД
- **⚠️ ВНИМАНИЕ:** НЕ УДАЛЯТЬ АВТОМАТИЧЕСКИ! Могут использоваться в контенте через shortcode или прямые ссылки

**SQL для проверки:**
```sql
-- Посмотреть неприкрепленные медиафайлы
SELECT ID, post_title, post_name, post_date, guid
FROM wp_posts
WHERE post_type = 'attachment'
AND post_parent = 0
ORDER BY post_date DESC;

-- Если точно уверены, можно удалить (НЕ РЕКОМЕНДУЕТСЯ БЕЗ ПРОВЕРКИ!)
-- DELETE FROM wp_posts WHERE post_type = 'attachment' AND post_parent = 0;
```

---

## 🧹 **2. Очистка временных данных**

### **2.1 Transients (кеш)** ⚠️ **ВЫСОКИЙ ПРИОРИТЕТ**
- **Найдено:** 53 transient'а (0.74 МБ)
- **Просроченные:** 1
- **Потенциальная экономия:** ~0.3-0.5 МБ

**SQL запросы:**
```sql
-- Удалить просроченные transients
DELETE FROM wp_options 
WHERE option_name LIKE '_transient_timeout_%' 
AND option_value < UNIX_TIMESTAMP();

-- Удалить transients без timeout записи
DELETE FROM wp_options 
WHERE option_name LIKE '_transient_%' 
AND option_name NOT LIKE '_transient_timeout_%'
AND option_name NOT IN (
  SELECT REPLACE(option_name, '_transient_timeout_', '_transient_') 
  FROM wp_options 
  WHERE option_name LIKE '_transient_timeout_%'
);

-- Удалить site transients (для multisite)
DELETE FROM wp_options 
WHERE option_name LIKE '_site_transient_timeout_%' 
AND option_value < UNIX_TIMESTAMP();

DELETE FROM wp_options 
WHERE option_name LIKE '_site_transient_%' 
AND option_name NOT LIKE '_site_transient_timeout_%'
AND option_name NOT IN (
  SELECT REPLACE(option_name, '_site_transient_timeout_', '_site_transient_') 
  FROM wp_options 
  WHERE option_name LIKE '_site_transient_timeout_%'
);
```

### **2.2 oEmbed кеш** 📌 **НИЗКИЙ ПРИОРИТЕТ**
- **Найдено:** 4 записи кеша вставок (YouTube, etc.)
- **Потенциальная экономия:** ~5-10 КБ

**SQL запросы:**
```sql
-- Удалить oembed кеши
DELETE FROM wp_posts WHERE post_type = 'oembed_cache';

-- Удалить oembed метаданные из postmeta
DELETE FROM wp_postmeta WHERE meta_key LIKE '_oembed_%';
```

### **2.3 Action Scheduler** 📌 **СРЕДНИЙ ПРИОРИТЕТ**
- **Найдено:** 12 завершенных + 1 failed задача
- **Потенциальная экономия:** ~50-100 КБ

**SQL запросы:**
```sql
-- Удалить завершенные задачи старше 30 дней
DELETE FROM wp_actionscheduler_actions 
WHERE status = 'complete' 
AND last_attempt_gmt < DATE_SUB(NOW(), INTERVAL 30 DAY);

-- Удалить failed задачи старше 30 дней
DELETE FROM wp_actionscheduler_actions 
WHERE status = 'failed' 
AND last_attempt_gmt < DATE_SUB(NOW(), INTERVAL 30 DAY);

-- Удалить логи старых задач
DELETE FROM wp_actionscheduler_logs 
WHERE action_id NOT IN (SELECT action_id FROM wp_actionscheduler_actions);
```

---

## 🔧 **3. Оптимизация таблиц** ⚠️ **ВЫСОКИЙ ПРИОРИТЕТ**

### **3.1 Дефрагментация таблиц**

**Обнаружена высокая фрагментация:**

| Таблица | Data (МБ) | Index (МБ) | Free (МБ) | Фрагментация (%) |
|---------|-----------|------------|-----------|------------------|
| wp_options | 2.52 | 0.06 | 4.00 | **155%** |
| wp_posts | 5.38 | 0.69 | 4.00 | **66%** |
| wp_postmeta | 12.33 | 3.64 | 4.00 | **25%** |

**Потенциальная экономия:** ~10-12 МБ

**SQL запросы:**
```sql
-- Оптимизировать основные таблицы
OPTIMIZE TABLE wp_options;
OPTIMIZE TABLE wp_posts;
OPTIMIZE TABLE wp_postmeta;
OPTIMIZE TABLE wp_comments;
OPTIMIZE TABLE wp_commentmeta;
OPTIMIZE TABLE wp_term_relationships;
OPTIMIZE TABLE wp_term_taxonomy;
OPTIMIZE TABLE wp_termmeta;
OPTIMIZE TABLE wp_actionscheduler_actions;
OPTIMIZE TABLE wp_actionscheduler_logs;
OPTIMIZE TABLE wp_actionscheduler_groups;
OPTIMIZE TABLE wp_actionscheduler_claims;
OPTIMIZE TABLE wp_usermeta;
OPTIMIZE TABLE wp_users;
```

---

## 📋 **4. Рекомендуемый порядок выполнения**

### Шаг 1: Подготовка
```bash
# Создать бэкап базы данных
cd /Users/adoknov/work/maslovka/www
docker compose exec mysql mysqldump -u wordpress_user -pwordpress_password wordpress_db > backups/db-before-cleanup-$(date +%Y%m%d-%H%M%S).sql
```

### Шаг 2: Удаление мусора (безопасные операции)
1. ✅ Удалить спам-комментарии
2. ✅ Очистить корзину
3. ✅ Удалить автосохранения
4. ✅ Очистить просроченные transients
5. ✅ Удалить oembed кеши
6. ✅ Очистить Action Scheduler

### Шаг 3: Удаление ревизий (осторожно!)
7. ⚠️ Удалить старые ревизии

### Шаг 4: Оптимизация
8. ✅ Оптимизировать все таблицы (OPTIMIZE TABLE)

### Шаг 5: Проверка (вручную)
9. 🔍 Проверить неиспользуемые термины
10. 🔍 Проверить неприкрепленные медиафайлы

### Шаг 6: Финальный бэкап
```bash
# Создать бэкап после очистки
docker compose exec mysql mysqldump -u wordpress_user -pwordpress_password wordpress_db > backups/db-after-cleanup-$(date +%Y%m%d-%H%M%S).sql
```

---

## 💾 **Ожидаемые результаты**

| Категория | Потенциальная экономия |
|-----------|------------------------|
| Ревизии постов | 3-5 МБ |
| Дефрагментация таблиц | 10-12 МБ |
| Transients | 0.3-0.5 МБ |
| Спам и корзина | 0.1-0.3 МБ |
| Action Scheduler | 0.05-0.1 МБ |
| oEmbed кеш | 0.01-0.02 МБ |
| **ИТОГО** | **13-18 МБ (50-70%)** |

**Текущий размер:** ~25 МБ  
**После очистки:** ~7-12 МБ  
**Экономия:** 50-70%

---

## ⚙️ **Дополнительные рекомендации**

### 1. Настроить wp-config.php

Добавить в `/www/wordpress/wp-config.php`:

```php
/**
 * Оптимизация базы данных
 */

// Ограничить количество ревизий
define('WP_POST_REVISIONS', 3);

// Интервал автосохранения (в секундах)
define('AUTOSAVE_INTERVAL', 300); // 5 минут вместо 60 секунд

// Очистка корзины через 7 дней
define('EMPTY_TRASH_DAYS', 7);

// Отключить oembed автообнаружение (если не используется)
// define('WP_OEMBED_DISCOVER', false);
```

### 2. Установить плагин для регулярной очистки

**Рекомендуемые плагины:**
- **WP-Optimize** ⭐ (рекомендую) - автоматическая очистка + оптимизация + кеширование
- **Advanced Database Cleaner** - детальная очистка БД
- **WP-Sweep** - простая очистка одним кликом

### 3. Настроить автоматическую очистку

Добавить в cron или использовать встроенный WordPress cron:

```php
// В functions.php темы или в плагин
add_action('wp_scheduled_delete', 'custom_database_cleanup');
function custom_database_cleanup() {
    global $wpdb;
    
    // Удалить просроченные transients
    $wpdb->query("DELETE FROM {$wpdb->options} WHERE option_name LIKE '_transient_timeout_%' AND option_value < UNIX_TIMESTAMP()");
    
    // Удалить старые Action Scheduler задачи
    $wpdb->query("DELETE FROM {$wpdb->prefix}actionscheduler_actions WHERE status = 'complete' AND last_attempt_gmt < DATE_SUB(NOW(), INTERVAL 30 DAY)");
    
    // Оптимизировать главные таблицы
    $wpdb->query("OPTIMIZE TABLE {$wpdb->options}");
    $wpdb->query("OPTIMIZE TABLE {$wpdb->posts}");
    $wpdb->query("OPTIMIZE TABLE {$wpdb->postmeta}");
}
```

### 4. Мониторинг размера БД

Создать скрипт для регулярной проверки:

```bash
#!/bin/bash
# database/db-check-size.sh

docker compose exec mysql mysql -u wordpress_user -pwordpress_password -e "
SELECT 
    table_schema as 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as 'Size (MB)'
FROM information_schema.TABLES 
WHERE table_schema = 'wordpress_db'
GROUP BY table_schema;
"
```

---

## 🔒 **Меры предосторожности**

1. ✅ **ВСЕГДА делать бэкап перед очисткой**
2. ✅ Тестировать на dev окружении перед продакшеном
3. ⚠️ Не удалять неприкрепленные медиафайлы без проверки
4. ⚠️ Проверять неиспользуемые термины вручную
5. ✅ Запускать оптимизацию в непиковые часы
6. ✅ Мониторить размер БД после очистки

---

## 📝 **Следующие шаги**

- [ ] Создать SQL-скрипт для автоматической очистки
- [ ] Добавить скрипт в deployment-scripts/database/
- [ ] Протестировать на локальном окружении
- [ ] Создать cron job для регулярной очистки
- [ ] Задокументировать процесс в README.md
- [ ] Применить на dev окружении
- [ ] Применить на prod окружении

---

**Последнее обновление:** 6 ноября 2025  
**Статус:** План готов к реализации ✅
