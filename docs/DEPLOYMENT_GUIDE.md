# 🚀 Deployment Guide для your-domain.com

## 📋 Оглавление

1. [Типы деплоя](#типы-деплоя)
2. [Initial Deployment (Первый деплой)](#initial-deployment)
3. [Regular Deployment (Обычный деплой)](#regular-deployment)
4. [Первоначальная настройка](#первоначальная-настройка)
5. [Git Hooks (автоматический билд)](#git-hooks)
6. [Pre-deployment Checklist](#pre-deployment-checklist)
7. [Smoke Tests](#smoke-tests)
8. [Rollback](#rollback)
9. [Hotfix](#hotfix)

---

## 🎯 Типы деплоя

### 📊 Сравнение типов деплоя

| Характеристика | Initial Deploy | Regular Deploy |
|----------------|----------------|----------------|
| **Когда использовать** | Первый раз на сервере | Все последующие обновления |
| **Что загружается** | Полный WordPress | Только изменения |
| **Метод загрузки** | rsync (полная копия) | git pull (инкрементально) |
| **Скорость** | Медленно (5-10 мин) | Быстро (10-30 сек) |
| **Размер передачи** | 100-500 MB | 1-10 MB |
| **Git на сервере** | Инициализирует | Использует существующий |
| **Команда** | `./initial-deploy.sh` | `./deploy-prod.sh` |

### 🆕 Initial Deployment (Первый деплой)

**Когда использовать:**
- ✅ Первое развертывание на новом сервере
- ✅ Переезд на новый хостинг
- ✅ Полное восстановление после сбоя
- ✅ На сервере нет WordPress или Git

**Что делает:**
1. Загружает **ПОЛНЫЙ** WordPress через rsync
2. Инициализирует Git репозиторий на сервере
3. Настраивает права доступа
4. Подключает к remote origin
5. Проверяет целостность установки

**Что загружается:**
- Ядро WordPress (wp-admin, wp-includes)
- Все wp-content (темы, плагины, uploads)
- Конфигурационные файлы (wp-config.php, .htaccess)

**Что НЕ загружается** (см. `.deployignore`):
- node_modules/
- .git/ (локальный)
- deployment-scripts/
- docker-compose.yml
- logs/

**Команды:**
```bash
# PROD
./deployment-scripts/initial-deploy.sh prod

# DEV
./deployment-scripts/initial-deploy.sh dev
```

📘 **Подробнее:** [INITIAL_DEPLOYMENT.md](INITIAL_DEPLOYMENT.md)

---

### 🔄 Regular Deployment (Обычный деплой)

**Когда использовать:**
- ✅ Все обновления после initial deploy
- ✅ Обновление кода/тем/плагинов
- ✅ Регулярные релизы
- ✅ Git уже настроен на сервере

**Что делает:**
1. Проверяет pre-deployment checklist
2. Создает бэкап
3. Включает maintenance mode
4. Делает `git pull` для обновления
5. Запускает миграции БД
6. Очищает кеш
7. Запускает smoke tests
8. Выключает maintenance mode

**Что обновляется:**
- Только измененные файлы (через Git)
- Быстро и эффективно
- Автоматический rollback при ошибках

**Команды:**
```bash
# PROD (с полными проверками)
./deployment-scripts/deploy-prod.sh

# DEV (быстрый деплой)
./deployment-scripts/deploy-dev.sh

# Dry-run (без реальных изменений)
./deployment-scripts/deploy-prod.sh --dry-run
```

---

## 🚀 Рабочий процесс деплоя

### Первый запуск (Once)

```bash
# 1. Настройка конфигурации
cd deployment-scripts
cp config.example.sh config.sh
nano config.sh  # Заполнить credentials
chmod 600 config.sh

# 2. Initial Deploy на DEV
./initial-deploy.sh dev

# 3. Проверка DEV
curl https://dev.your-domain.com

# 4. Initial Deploy на PROD (когда готовы)
./initial-deploy.sh prod
```

### Ежедневная работа (Daily)

```bash
# 1. Разработка и коммит (автоматический билд ассетов)
git add .
git commit -m "feat: new feature"
git push origin dev

# 2. Деплой на DEV
./deployment-scripts/deploy-dev.sh

# 3. Тестирование на DEV
# ...проверяем что всё работает...

# 4. Мерж в main
git checkout main
git merge dev
git push origin main

# 5. Деплой на PROD
./deployment-scripts/deploy-prod.sh
```

---

## 🆕 1️⃣ Initial Deployment

### DEV окружение

```bash
./deployment-scripts/initial-deploy.sh dev
```

**Процесс:**
1. ✓ Проверка локального окружения
2. ✓ Тест SSH соединения
3. ✓ Проверка состояния сервера
4. ✓ Подготовка директорий
5. ✓ Загрузка WordPress (rsync)
6. ✓ Инициализация Git
7. ✓ Настройка прав
8. ✓ Верификация

### PROD окружение

```bash
./deployment-scripts/initial-deploy.sh prod
```

**Дополнительные проверки для PROD:**
- Подтверждение от пользователя
- Бэкап существующей установки (если есть)
- Уведомления о статусе
- Детальная верификация

**После initial deploy:**
1. Проверьте wp-config.php на сервере
2. Импортируйте базу данных
3. Обновите URL (search-replace)
4. Проверьте сайт в браузере

---

## 🔄 2️⃣ Regular Deployment на DEV

**Когда использовать:** Ежедневная разработка, пуш в ветку `dev`

**Что деплоится:**
- ✅ Только изменённые файлы (git pull)
- ✅ Собранные ассеты (CSS/JS) — уже в git!
- ✅ Миграции БД (если есть)
- ❌ Не трогаем uploads, node_modules

**Как выполнить:**

```bash
# Локально: коммит с автоматическим билдом
cd /path/to/your/project
git add .
git commit -m "feat: add new feature"  # pre-commit hook билдит ассеты
git push origin dev

# На сервере или автоматически через скрипт
./deployment-scripts/deploy-dev.sh
```

**Что происходит:**
1. Git pull на DEV сервере
2. Миграции БД (если есть)
3. Очистка кеша
4. Готово! ✅

---

### 3️⃣ Первый деплой на PROD (Production Launch)

**Когда использовать:** Первый запуск production

**Что деплоится:**
- ✅ Все файлы (git clone из `main`)
- ✅ Production конфигурация
- ✅ Импорт/миграция БД
- ✅ SSL, права доступа
- ✅ Search-replace для домена

**Как выполнить:**

```bash
# На сервере PROD
ssh your_ssh_user@your_server_ip

# Клонировать репозиторий
cd /home/your_ssh_user
git clone -b main https://github.com/Ad-Ok/wordpress-docker-setup.git your-domain.com

# Создать папки
mkdir -p backups logs

# Настроить права
chmod 755 your-domain.com
chmod 644 your-domain.com/wp-config.php
chown -R www-data:www-data your-domain.com/wp-content/uploads

# Импортировать базу
cd your-domain.com
wp db import path/to/prod-backup.sql

# Обновить URL
wp search-replace 'https://dev.your-domain.com' 'https://your-domain.com'

# Flush permalinks
wp rewrite flush
```

---

### 4️⃣ Релизный деплой на PROD (Release Deployment)

**Когда использовать:** Выкатка новой версии из `dev` → `prod`

**Что деплоится:**
- ✅ Только изменённые файлы (git pull)
- ✅ Собранные ассеты (уже в git)
- ✅ Миграции БД
- ❌ Не трогаем uploads, конфигурацию

**Как выполнить:**

```bash
# Локально: убедиться, что dev -> main
cd /path/to/your/project

# Создать PR или merge напрямую
git checkout main
git pull origin main
git merge dev
git push origin main

# Запустить деплой скрипт
./deployment-scripts/deploy-prod.sh
```

**Что происходит:**
1. **Pre-deployment checklist** (10 проверок)
2. Подтверждение от пользователя
3. **Бэкап БД + файлов**
4. Maintenance mode ON
5. Git pull на PROD
6. Миграции БД
7. Очистка кеша
8. Maintenance mode OFF
9. **Smoke tests** (8 тестов)
10. Уведомление об успехе

---

### 5️⃣ Hotfix (Срочное исправление)

**Когда использовать:** Критическая ошибка на проде

**Как выполнить:**

```bash
./deployment-scripts/hotfix.sh "Fix critical cart bug"
```

**Что происходит:**
1. Создаёт ветку `hotfix/fix-critical-cart-bug`
2. Коммитит изменения
3. Push в remote
4. Спрашивает: merge в `main` сейчас?
5. Спрашивает: deploy на PROD сейчас?
6. Автоматически удаляет hotfix ветку

---

### 6️⃣ Rollback (Откат)

**Когда использовать:** После неудачного деплоя

**Как выполнить:**

```bash
./deployment-scripts/rollback.sh prod
```

**Что происходит:**
1. Показывает список бэкапов
2. Выбираешь нужный
3. Подтверждение
4. Восстановление БД + файлов
5. Очистка кеша
6. Готово!

---

## ⚙️ Первоначальная настройка

### 1. Настроить конфигурацию

```bash
cd deployment-scripts
cp config.example.sh config.sh
nano config.sh  # Заполнить данными из creds.txt
chmod 600 config.sh  # Защитить файл
```

### 2. Настроить SSH ключи (опционально, для безопасности)

```bash
# Локально
ssh-keygen -t ed25519 -C "deploy@your-domain.com"

# Скопировать на сервер
ssh-copy-id your_ssh_user@your_server_ip

# Проверить
ssh your_ssh_user@your_server_ip "echo 'SSH works!'"
```

### 3. Установить Git Hooks

```bash
# Хук уже создан в .git/hooks/pre-commit
# Проверить
ls -la .git/hooks/pre-commit

# Если нужно переустановить
cp deployment-scripts/git-hooks/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit
```

### 4. Проверить package.json в теме

```bash
cd www/wordpress/wp-content/themes/your-theme

# Убедиться, что есть скрипты
npm run build:css    # Должен собрать SCSS -> CSS
npm run build:js     # Должен собрать JS -> min.js
npm run build        # Должен собрать всё
```

---

## 🔨 Git Hooks (Автоматический билд)

### Как работает

При каждом `git commit`:

1. **Проверяет**, изменились ли SCSS или JS исходники
2. Если да — **билдит** ассеты автоматически
3. **Добавляет** собранные файлы в коммит
4. Если билд упал — **отменяет** коммит

### Преимущества

✅ Не нужно помнить про `npm run build`  
✅ Всегда свежие ассеты в git  
✅ Нет конфликтов между разработчиками  
✅ Быстрый деплой на сервере (просто `git pull`)

### Что билдится

```bash
# SCSS -> CSS
assets/scss/main.scss       → assets/css/main.css
assets/scss/admin.scss      → assets/css/admin.css

# JS -> Minified JS
assets/js/src/main.js       → assets/js/main.min.js
assets/js/src/admin.js      → assets/js/admin.min.js
```

### Отключить автобилд (если нужно)

```bash
git commit --no-verify -m "commit message"
```

---

## ✅ Pre-deployment Checklist

Запускается автоматически перед PROD деплоем.

### 10 проверок:

1. **Git статус** — нет незакоммиченных изменений
2. **Собранные ассеты** — CSS/JS файлы свежие
3. **Зависимости** — package-lock.json актуален
4. **PHP синтаксис** — нет ошибок в PHP
5. **Версия темы** — обновлена в style.css
6. **Миграции** — есть новые миграции
7. **.gitignore** — собранные файлы НЕ игнорируются
8. **Сервер** — PROD доступен по SSH
9. **Диск** — достаточно места на сервере
10. **Бэкап** — есть недавний бэкап

### Ручной запуск

```bash
./deployment-scripts/pre-deployment-checklist.sh
```

---

## 🧪 Smoke Tests

Запускаются автоматически после PROD деплоя.

### 8 тестов:

1. **Homepage** — возвращает HTTP 200
2. **REST API** — `/wp-json/` работает
3. **Admin Ajax** — admin-ajax.php доступен
4. **CSS** — стили загружаются
5. **JS** — скрипты загружаются
6. **PHP ошибки** — нет fatal errors в логах
7. **Скорость** — response time < 5 сек
8. **Критичные страницы** — о галерее, афиша, контакты

### Ручной запуск

```bash
# Для PROD
./deployment-scripts/smoke-tests.sh prod

# Для DEV
./deployment-scripts/smoke-tests.sh dev
```

---

## 🔙 Rollback

### Когда использовать

- ❌ Деплой сломал сайт
- ❌ Smoke tests failed
- ❌ Баг обнаружен после деплоя

### Как работает

1. Показывает список бэкапов с временными метками
2. Выбираешь нужный
3. Подтверждение (type "yes")
4. Maintenance mode ON
5. Восстанавливает БД
6. Восстанавливает файлы темы
7. Очищает кеш
8. Maintenance mode OFF

### Пример

```bash
./deployment-scripts/rollback.sh prod

# Вывод:
# Available backups:
# [1] backup-20251028-143000.sql.gz (2 hours ago)
# [2] backup-20251027-101500.sql.gz (1 day ago)
# [3] backup-20251026-164500.sql.gz (2 days ago)
#
# Select backup to restore [1-3]: 1
```

---

## ⚡ Hotfix

### Когда использовать

- 🔥 Критический баг на проде
- 🔥 Срочное исправление
- 🔥 Нужно задеплоить минуя обычный процесс

### Workflow

```bash
# 1. Исправить баг локально
vim www/wordpress/wp-content/themes/your-theme/template.php

# 2. Запустить hotfix скрипт
./deployment-scripts/hotfix.sh "Fix cart calculation bug"

# 3. Скрипт автоматически:
#    - создаст ветку hotfix/fix-cart-calculation-bug
#    - закоммитит изменения
#    - запушит в remote
#    - предложит merge в main
#    - предложит задеплоить сразу

# 4. Готово! 🎉
```

### Плюсы

✅ Быстрый workflow  
✅ Не затрагивает dev ветку  
✅ Автоматический merge в main  
✅ Опциональный instant deploy  
✅ Автоматическая очистка hotfix ветки

---

## 📊 Сравнительная таблица

| Вариант | Частота | Команда | Бэкап | Тесты | Maintenance |
|---------|---------|---------|-------|-------|-------------|
| 1. First DEV | 1 раз | SSH + git clone | ❌ | ❌ | ❌ |
| 2. Regular DEV | ежедневно | `deploy-dev.sh` | ❌ | ❌ | ❌ |
| 3. First PROD | 1 раз | SSH + git clone | ✅ | ✅ | ✅ |
| 4. Release PROD | еженедельно | `deploy-prod.sh` | ✅ | ✅ | ✅ |
| 5. Hotfix | по необходимости | `hotfix.sh` | ✅ | ✅ | ✅ |
| 6. Rollback | при ошибке | `rollback.sh` | ✅ | ❌ | ✅ |

---

## 🎯 Типичные сценарии

### Сценарий 1: Обычная разработка

```bash
# 1. Работаем в dev ветке
git checkout dev

# 2. Делаем изменения
vim www/wordpress/wp-content/themes/your-theme/functions.php

# 3. Коммитим (автобилд ассетов)
git add .
git commit -m "feat: add new feature"
git push origin dev

# 4. Деплоим на DEV
./deployment-scripts/deploy-dev.sh

# 5. Проверяем на dev.your-domain.com
# 6. Если ОК, делаем PR: dev -> main
# 7. После merge, деплоим на PROD
./deployment-scripts/deploy-prod.sh
```

### Сценарий 2: Срочный hotfix

```bash
# 1. Обнаружили баг на проде
# 2. Исправляем локально
vim www/wordpress/wp-content/themes/your-theme/cart.php

# 3. Запускаем hotfix
./deployment-scripts/hotfix.sh "Fix cart bug"

# 4. Следуем инструкциям скрипта
# 5. Готово! Hotfix на проде через 2 минуты
```

### Сценарий 3: Откат после неудачного деплоя

```bash
# 1. Деплой прошёл, но сайт сломан
# 2. Запускаем rollback
./deployment-scripts/rollback.sh prod

# 3. Выбираем бэкап до проблемного деплоя
# 4. Подтверждаем
# 5. Сайт восстановлен!
```

---

## 🛠️ Troubleshooting

### Проблема: Git hook не работает

```bash
# Проверить права
ls -la .git/hooks/pre-commit

# Переустановить
chmod +x .git/hooks/pre-commit

# Проверить, работает ли npm
cd www/wordpress/wp-content/themes/your-theme
npm run build
```

### Проблема: SSH не подключается

```bash
# Проверить credentials в config.sh
cat deployment-scripts/config.sh | grep PROD_SSH

# Проверить подключение вручную
ssh your_ssh_user@your_server_ip

# Проверить SSH ключи
ssh-add -l
```

### Проблема: Smoke tests не проходят

```bash
# Запустить вручную для диагностики
./deployment-scripts/smoke-tests.sh prod

# Проверить логи на сервере
ssh your_ssh_user@your_server_ip
tail -50 /home/your_ssh_user/logs/error.log
```

### Проблема: Миграции не применяются

```bash
# Проверить на сервере
ssh your_ssh_user@your_server_ip
cd /home/your_ssh_user/your-domain.com
wp your-project migrate:status
wp your-project migrate --debug
```

---

## 📚 Дополнительные ресурсы

- [CI_CD_DEPLOYMENT_PLAN.md](../CI_CD_DEPLOYMENT_PLAN.md) — полный план CI/CD
- [GIT_HOOKS_SETUP.md](../GIT_HOOKS_SETUP.md) — детали про git hooks
- [creds.txt](../creds.txt) — credentials серверов (НЕ коммитить!)

---

## ✨ Best Practices

1. **Всегда билдить локально** (через git hook)
2. **Тестировать на DEV** перед PROD
3. **Делать бэкапы** перед каждым PROD деплоем
4. **Запускать smoke tests** после деплоя
5. **Иметь план rollback** на случай проблем
6. **Использовать hotfix** только для критичных багов
7. **Коммитить часто**, деплоить реже
8. **Не пушить в main** напрямую, только через PR или hotfix

---

## 🎉 Готово!

Теперь у вас есть полноценная система деплоя с:

- ✅ Автоматическим билдом ассетов
- ✅ Pre-deployment checklist
- ✅ Smoke tests
- ✅ Rollback механизмом
- ✅ Hotfix workflow
- ✅ Уведомлениями
- ✅ Бэкапами

**Начните с:**

1. Настроить `deployment-scripts/config.sh`
2. Протестировать `./deployment-scripts/deploy-dev.sh`
3. Сделать первый PROD деплой `./deployment-scripts/deploy-prod.sh`

Удачи! 🚀
