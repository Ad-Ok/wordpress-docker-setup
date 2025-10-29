<!-- Database Management Scripts -->

# 🗄️ Система управления базой данных

Полнофункциональная система для управления базой данных WordPress с поддержкой:
- ✅ Полная синхронизация между окружениями
- ✅ Система миграций с отслеживанием
- ✅ Snapshots БД для разных веток
- ✅ Автоматическая замена доменов
- ✅ Git hooks для изоляции БД по веткам

---

## 📁 Структура

```
deployment-scripts/database/
├── db-snapshot.sh           # Управление snapshots
├── db-sync.sh              # Полная синхронизация
├── db-migrate.sh           # Система миграций
├── db-create-migration.sh  # Генератор миграций
├── install-hooks.sh        # Установка Git hooks
├── git-hooks/
│   └── post-checkout       # Автопереключение БД при checkout
├── migrations/
│   ├── 001_example.sql     # Файлы миграций
│   └── .applied.json       # Отслеживание примененных миграций
└── utils/
    └── search-replace.sh   # Замена доменов
```

---

## 🚀 Быстрый старт

### 1. Установка Git Hooks (рекомендуется)

```bash
cd www/deployment-scripts/database
./install-hooks.sh
```

Это включит автоматическое переключение БД при смене веток.

### 2. Первоначальная настройка

```bash
# Создать snapshot текущей БД
./db-snapshot.sh create "initial"

# Или загрузить БД с продакшена
./db-sync.sh pull prod
```

---

## 📋 Команды

### 🔄 Полная синхронизация (`db-sync.sh`)

#### Загрузить БД с удаленного сервера

```bash
# С продакшена
./db-sync.sh pull prod

# С дева
./db-sync.sh pull dev
```

**Что делает:**
1. Создает snapshot текущей локальной БД (на всякий случай)
2. Экспортирует БД с удаленного сервера
3. Импортирует в локальную БД
4. Автоматически заменяет домены
5. Очищает кэш WordPress

#### Отправить БД на продакшен (Initial Deploy)

```bash
./db-sync.sh push prod
```

⚠️ **ВНИМАНИЕ**: Это заменит БД на продакшене! Используйте только для initial deploy.

---

### 📸 Snapshots (`db-snapshot.sh`)

#### Создать snapshot

```bash
# С описанием
./db-snapshot.sh create "before big changes"

# Без описания
./db-snapshot.sh create
```

#### Посмотреть все snapshots

```bash
./db-snapshot.sh list
```

Вывод:
```
📋 Список snapshots:

■ main (текущая)
  ├─ main_20251029_153022 (12M) - initial
  ├─ main_20251029_154511 (12M)

■ feature-blog
  ├─ feature-blog_20251029_160133 (11M) - before migration
```

#### Восстановить snapshot

```bash
# Конкретный snapshot
./db-snapshot.sh restore main_20251029_153022

# Последний для текущей ветки
./db-snapshot.sh restore latest
```

#### Очистить старые snapshots

```bash
./db-snapshot.sh cleanup
```

---

### 🗄️ Миграции (`db-migrate.sh`)

#### Создать новую миграцию

```bash
./db-create-migration.sh "add products table"
```

Создаст файл: `migrations/001_add_products_table.sql`

#### Редактировать миграцию

Откройте созданный файл и добавьте SQL:

```sql
-- migrations/001_add_products_table.sql

CREATE TABLE IF NOT EXISTS wp_products (
    id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
    name varchar(255) NOT NULL,
    price decimal(10,2) NOT NULL,
    created_at datetime DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### Применить миграции

```bash
# На локальной БД
./db-migrate.sh apply local

# На DEV
./db-migrate.sh apply dev

# На PROD
./db-migrate.sh apply prod
```

#### Проверить статус миграций

```bash
# Для конкретного окружения
./db-migrate.sh status local
./db-migrate.sh status dev
./db-migrate.sh status prod

# Список всех миграций
./db-migrate.sh list
```

Вывод:
```
001 add products table
   ├─ Local: [✓]  Dev: [✓]  Prod: [ ]
   └─ Файл: 001_add_products_table.sql

002 add category column
   ├─ Local: [✓]  Dev: [ ]  Prod: [ ]
   └─ Файл: 002_add_category_column.sql
```

---

### 🔍 Замена доменов (`utils/search-replace.sh`)

```bash
# Заменить домен локально
./utils/search-replace.sh \
    "http://wordpresstest.ru.xsph.ru" \
    "http://localhost" \
    local

# Заменить на удаленном сервере
./utils/search-replace.sh \
    "http://localhost" \
    "http://wordpresstest.ru.xsph.ru" \
    prod
```

---

## 🔀 Работа с ветками

### С установленными Git Hooks (автоматически)

```bash
# Вы на ветке main
git checkout feature/blog
# → Автоматически: сохраняется БД main, восстанавливается БД feature/blog

# Работаете над фичей...

git checkout main
# → Автоматически: сохраняется БД feature/blog, восстанавливается БД main
```

### Без Git Hooks (вручную)

```bash
# Создать snapshot перед переключением
./db-snapshot.sh create "before switching to feature"

# Переключиться
git checkout feature/blog

# Восстановить snapshot для новой ветки
./db-snapshot.sh restore latest
# или загрузить свежую БД с продакшена
./db-sync.sh pull prod
```

---

## 📖 Типичные сценарии

### Сценарий 1: Новая фича с изменениями БД

```bash
# 1. Создать ветку
git checkout -b feature/new-products

# 2. Создать миграцию
./db-create-migration.sh "add products table"

# 3. Редактировать migrations/001_add_products_table.sql

# 4. Применить локально
./db-migrate.sh apply local

# 5. Протестировать

# 6. Закоммитить
git add migrations/001_add_products_table.sql
git commit -m "Add products table migration"

# 7. Применить на DEV
./db-migrate.sh apply dev

# 8. После тестов - на PROD
./db-migrate.sh apply prod
```

### Сценарий 2: Получить свежие данные от менеджеров

```bash
# Загрузить БД с продакшена
./db-sync.sh pull prod
```

### Сценарий 3: Сломали базу, нужно откатиться

```bash
# Посмотреть доступные snapshots
./db-snapshot.sh list

# Восстановить последний
./db-snapshot.sh restore latest

# Или конкретный
./db-snapshot.sh restore main_20251029_153022
```

### Сценарий 4: Initial Deploy

```bash
# 1. Убедитесь, что локальная БД готова
./db-snapshot.sh list

# 2. Отправьте на продакшен
./db-sync.sh push prod
# ⚠️ Потребуется ввести: REPLACE DATABASE

# 3. Проверьте сайт
```

### Сценарий 5: Переключение между фичами

```bash
# Работаете над feature/blog
# ... делаете изменения в БД ...

# Нужно срочно переключиться на feature/shop
git checkout feature/shop
# → Автоматически переключается БД (если установлен hook)

# Работаете над shop
# ... делаете изменения ...

# Возвращаетесь к blog
git checkout feature/blog
# → БД восстанавливается к состоянию feature/blog
```

---

## ⚙️ Конфигурация

Все настройки в `deployment-scripts/config.sh`:

```bash
# Локальная БД (Docker)
LOCAL_DB_NAME="wordpress"
LOCAL_DB_USER="wordpress"
LOCAL_DB_PASS="wordpress"
LOCAL_DB_HOST="localhost"
LOCAL_DB_PORT="3306"
LOCAL_DB_CONTAINER="wordpress_mysql"
LOCAL_SITE_URL="http://localhost"

# Snapshots
LOCAL_SNAPSHOT_DIR="${LOCAL_BACKUP_DIR}/snapshots"
SNAPSHOT_KEEP_COUNT="3"  # Сколько хранить для каждой ветки
SNAPSHOT_AUTO_SWITCH="true"  # Автопереключение при git checkout
```

---

## 🔧 Требования

- **Docker** с запущенным MySQL контейнером
- **WP-CLI** установлен в Docker контейнере
- **jq** для работы с JSON (обычно уже установлен в macOS)
- **SSH доступ** к удаленным серверам
- **Git** для версионирования миграций

---

## 💡 Советы и рекомендации

### Миграции

✅ **DO:**
- Используйте `IF NOT EXISTS` для идемпотентности
- Коммитьте миграции в Git
- Применяйте миграции последовательно: local → dev → prod
- Добавляйте комментарии в сложных миграциях

❌ **DON'T:**
- Не изменяйте примененные миграции (создавайте новые)
- Не пропускайте тестирование на DEV
- Не применяйте миграции напрямую через MySQL

### Snapshots

✅ **DO:**
- Создавайте snapshot перед большими изменениями
- Используйте описательные имена
- Регулярно чистите старые snapshots

❌ **DON'T:**
- Не храните слишком много snapshots (занимают место)
- Не полагайтесь только на snapshots (делайте полные backup)

### Синхронизация

✅ **DO:**
- Используйте `pull` для получения данных от менеджеров
- Проверяйте домены после синхронизации

❌ **DON'T:**
- Не используйте `push prod` после initial deploy
- Используйте миграции для изменений структуры

---

## 🐛 Troubleshooting

### Docker контейнер не запускается

```bash
# Проверить статус
docker ps -a

# Запустить вручную
docker start wordpress_mysql

# Посмотреть логи
docker logs wordpress_mysql
```

### WP-CLI не найден

```bash
# Проверить WP-CLI в контейнере
docker exec wordpress_mysql wp --info

# Если нет - установить в Dockerfile
```

### Миграция не применяется

```bash
# Проверить синтаксис SQL
cat migrations/001_example.sql

# Применить вручную для отладки
docker exec -i wordpress_mysql \
    mysql -u wordpress -pwordpress wordpress \
    < migrations/001_example.sql
```

### Snapshot не восстанавливается

```bash
# Проверить файл
ls -lh /Users/adoknov/work/maslovka/backups/snapshots/

# Восстановить вручную
gunzip -c snapshot.sql.gz | docker exec -i wordpress_mysql \
    mysql -u wordpress -pwordpress wordpress
```

---

## 📚 Дополнительная информация

### Где хранятся данные

- **Snapshots**: `/Users/adoknov/work/maslovka/www/backups/snapshots/`
- **Миграции**: `www/deployment-scripts/database/migrations/`
- **Логи применения**: `www/deployment-scripts/database/migrations/.applied.json`

### Безопасность

- ⚠️ `config.sh` в `.gitignore` - содержит пароли
- ⚠️ Snapshots только локально - не коммитятся
- ✅ Миграции в Git - без чувствительных данных

---

## 🆘 Получить помощь

```bash
# Помощь по командам
./db-snapshot.sh help
./db-sync.sh help
./db-migrate.sh help
./db-create-migration.sh help
```

---

## 📄 Лицензия

Часть проекта wordpress-docker-setup

