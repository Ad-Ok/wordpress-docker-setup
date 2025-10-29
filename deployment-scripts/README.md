# 🚀 Deployment Scripts для your-domain.com

## 📚 Документация

- **[QUICK_START.md](../docs/QUICK_START.md)** - Шпаргалка по основным командам
- **[INITIAL_DEPLOY_GUIDE.md](../docs/INITIAL_DEPLOY_GUIDE.md)** - Подробная инструкция по первоначальному деплою
- **[DEPLOYMENT_GUIDE.md](../docs/DEPLOYMENT_GUIDE.md)** - Общее руководство по деплою
- **[DEPLOYMENT_CHEATSHEET.md](../docs/DEPLOYMENT_CHEATSHEET.md)** - Читы по деплою

## Структура

```
deployment-scripts/
├── README.md                      # Этот файл
├── config.sh                      # Конфигурация серверов
├── initial-deploy.sh              # 🆕 Первоначальный деплой (включая БД)
├── deploy-dev.sh                  # Деплой на DEV
├── deploy-prod.sh                 # Деплой на PROD
├── rollback.sh                    # Откат к предыдущей версии
├── pre-deployment-checklist.sh    # Проверки перед деплоем
├── smoke-tests.sh                 # Smoke tests после деплоя
├── hotfix.sh                      # Быстрый хотфикс
└── utils/
    ├── backup.sh                  # Бэкап БД и файлов
    ├── maintenance.sh             # Режим обслуживания
    └── notifications.sh           # Уведомления (Telegram/Email)
```

## 🎯 Использование

### 1. Первоначальная настройка

```bash
# Скопировать config.example.sh в config.sh и заполнить данными
cp config.example.sh config.sh
chmod 600 config.sh  # Защитить credentials

# Сделать скрипты исполняемыми
chmod +x *.sh utils/*.sh
```

### 2. Первоначальный деплой (Initial Deploy) 🆕

**Используется ТОЛЬКО для первого развертывания на новом сервере!**

```bash
# Деплой на PROD (первый раз)
./initial-deploy.sh prod

# Деплой на DEV (первый раз)
./initial-deploy.sh dev
```

Что происходит:
1. ✅ Проверка локального окружения (WordPress файлы, Docker)
2. ✅ Проверка SSH соединения
3. ✅ Проверка состояния сервера (предупреждение если уже есть установка)
4. ✅ Подготовка директорий на сервере
5. ✅ Клонирование Git репозитория на сервере (ветка main для prod, dev для dev)
6. **🆕 Загрузка базы данных с локального Docker:**
   - Экспорт БД из MySQL контейнера
   - Загрузка дампа на сервер
   - Импорт в удаленную БД
   - Автоматический search-replace URL (localhost → production/dev URL)
7. ✅ Загрузка WordPress core файлов (исключая wp-content)
8. ✅ Загрузка wp-content/uploads (с проверкой размера)
9. ✅ Установка прав доступа
10. ✅ Создание deployment marker
11. ✅ Настройка HTTP аутентификации (для DEV: test/test)
12. ✅ Проверка установки
13. **🆕 Проверка подключения к базе данных**

**Важно:**
- Локальный Docker с MySQL должен быть запущен
- Локальная БД должна быть актуальной и соответствовать текущей ветке Git
- На сервере будет создан backup существующей БД (если она есть)
- URLs автоматически заменятся с локальных на production/dev

### 3. Деплой на DEV

```bash
./deploy-dev.sh
```

Что происходит:
1. Проверка git статуса
2. Git pull на DEV сервере
3. Проверка миграций
4. Очистка кеша
5. Smoke tests

### 4. Деплой на PROD

```bash
./deploy-prod.sh
```

Что происходит:
1. **Pre-deployment checklist** (проверки перед деплоем)
2. Подтверждение от пользователя (Y/N)
3. Включение режима обслуживания
4. **Бэкап БД и файлов**
5. Git pull на PROD сервере
6. Миграции БД (если есть)
7. Очистка кеша
8. **Smoke tests**
9. Выключение режима обслуживания
10. Уведомление об успехе/ошибке

### 5. Откат (Rollback)

```bash
./rollback.sh
```

Интерактивный выбор версии для отката:
```
Available backups:
1) 2025-10-28_14-30-00 (2 hours ago)
2) 2025-10-27_10-15-00 (1 day ago)
3) 2025-10-26_16-45-00 (2 days ago)

Select backup to restore [1-3]:
```

### 6. Хотфикс

```bash
./hotfix.sh "Fix critical bug in cart.php"
```

Автоматически:
1. Создает ветку `hotfix/fix-critical-bug-in-cart-php`
2. После коммита спрашивает, деплоить ли сразу
3. Merge в main + deploy

---

## 🔐 Безопасность

- `config.sh` **НЕ** добавлен в git (в .gitignore)
- SSH ключи используются вместо паролей
- Бэкапы хранятся локально и на сервере

---

## 📱 Уведомления

Скрипты могут отправлять уведомления в:
- Telegram (через bot API)
- Email
- Slack (опционально)

Настройка в `config.sh`.

---

## ⚙️ Требования

- Bash 4.0+
- Git
- SSH доступ к серверу
- WP-CLI на сервере (для миграций и кеша)
- curl (для smoke tests)
- jq (опционально, для парсинга JSON)

---

## 🧪 Тестирование скриптов

```bash
# Dry run (без реальных изменений)
./deploy-prod.sh --dry-run
```
