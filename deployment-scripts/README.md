# 🚀 Deployment Scripts для your-domain.com

## Структура

```
deployment-scripts/
├── README.md                      # Этот файл
├── config.sh                      # Конфигурация серверов
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

### 2. Деплой на DEV

```bash
./deploy-dev.sh
```

Что происходит:
1. Проверка git статуса
2. Git pull на DEV сервере
3. Проверка миграций
4. Очистка кеша
5. Smoke tests

### 3. Деплой на PROD

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

### 4. Откат (Rollback)

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

### 5. Хотфикс

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
