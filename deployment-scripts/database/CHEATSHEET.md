# 🗄️ Database Management - Quick Reference

---

## 🔄 Синхронизация БД

### Загрузить с удаленного сервера на локальную

```bash
# С продакшена
./db-sync.sh pull prod

# С дева
./db-sync.sh pull dev
```

### ⭐ Синхронизировать между серверами

```bash
# Обновить DEV из PROD (частый сценарий)
./db-sync.sh sync prod dev

# Обновить PROD из DEV (осторожно!)
./db-sync.sh sync dev prod
```

### Отправить на продакшен (Initial Deploy)

```bash
./db-sync.sh push prod
```

---

## 📊 Database Analysis - Quick Reference

## Запуск анализа

```bash
# Локальная БД
./db-analyze.sh local

# DEV
./db-analyze.sh dev

# PROD  
./db-analyze.sh prod
```

## Интерпретация метрик

### ✅ Хорошо
- Database size соответствует контенту
- Fragmentation < 5 MB
- Autoload size < 1 MB
- Transients < 100
- Revisions < 100
- Нет orphaned данных
- Нет спама

### ⚠️ Требует внимания
- Fragmentation 5-20 MB
- Autoload size 1-3 MB
- Transients 100-500
- Revisions 100-1000

### 🚨 Критично
- Fragmentation > 20 MB (>10% от размера БД)
- Autoload size > 3 MB
- Transients > 500
- Revisions > 1000
- Много orphaned данных

## Быстрые исправления

### Дефрагментация таблиц
```sql
-- Одна таблица
OPTIMIZE TABLE wp_posts;

-- Несколько таблиц
OPTIMIZE TABLE wp_posts, wp_postmeta, wp_options;

-- Все основные таблицы
OPTIMIZE TABLE wp_options, wp_postmeta, wp_posts, 
               wp_comments, wp_termmeta, wp_terms;
```

### Очистить transient
```sql
DELETE FROM wp_options 
WHERE option_name LIKE '_transient_%';
```

### Удалить старые ревизии
```sql
DELETE FROM wp_posts 
WHERE post_type = 'revision' 
  AND post_modified < DATE_SUB(NOW(), INTERVAL 30 DAY);
```

### Удалить спам
```sql
DELETE FROM wp_comments WHERE comment_approved = 'spam';
```

### Оптимизировать таблицы
```sql
OPTIMIZE TABLE wp_options, wp_postmeta, wp_posts;
```

## Отчеты

Сохраняются в:
```
wordpress/database/reports/
├── db-analysis-local-YYYYMMDD_HHMMSS.txt
└── db-analysis-local-YYYYMMDD_HHMMSS.json
```
