# WordPress Docker Setup

Классическая Docker-структура для WordPress с указанными компонентами:
- **Nginx**: 1.26.3
- **PHP**: 8.2.28-fpm
- **MySQL**: 5.7
- **WordPress**: 6.6.2 (актуальная стабильная версия)
- **Docker**: 27.4.0
- **Docker Compose**: 2.31.0

## Структура проекта

```
www/
├── docker-compose.yml          # Основная конфигурация Docker
├── .env                        # Переменные окружения
├── .cursorrules               # Инструкции для Copilot (Docker v27.4.0, Compose v2.31.0)
├── .gitignore                 # Исключаемые файлы из git
├── deployment-scripts/         # 🚀 Скрипты деплоя (запускаются с хоста!)
│   ├── deploy-dev.sh          # Деплой на DEV
│   ├── deploy-prod.sh         # Деплой на PROD
│   ├── rollback.sh            # Откат
│   ├── hotfix.sh              # Срочный hotfix
│   ├── pre-deployment-checklist.sh
│   ├── smoke-tests.sh
│   └── utils/
├── docs/                       # 📚 Документация
│   ├── DEPLOYMENT_GUIDE.md    # Полный гайд по деплою
│   ├── CI_CD_DEPLOYMENT_PLAN.md
│   └── GIT_HOOKS_SETUP.md
├── nginx/
│   ├── nginx.conf             # Основная конфигурация Nginx
│   └── default.conf           # Конфигурация виртуального хоста
├── php/
│   ├── Dockerfile             # Кастомный образ PHP с расширениями
│   └── php.ini               # Конфигурация PHP
├── mysql/
│   └── my.cnf                # Конфигурация MySQL
├── wordpress/                 # Файлы WordPress
└── logs/                      # Логи всех сервисов
    ├── nginx/
    ├── php/
    └── mysql/
```

**Важно:** В проекте используется Docker версии 27.4.0 и Docker Compose версии 2.31.0. Все команды должны выполняться с `docker compose` (с пробелом), а не `docker-compose`.

## О файле .cursorrules

Файл `.cursorrules` содержит инструкции для Copilot и других AI-ассистентов по работе с проектом. Он определяет:
- Версии Docker (27.4.0) и Docker Compose (2.31.0)
- Правильный синтаксис команд (`docker compose` вместо `docker-compose`)
- Структура проекта и компоненты
- Рекомендации по рабочему процессу

**Всегда следуйте инструкциям из `.cursorrules` при работе с проектом.**

## О файле .gitignore

Файл `.gitignore` определяет файлы и папки, которые не должны попадать в систему контроля версий:
- `.env` файлы с паролями
- Архивы WordPress
- Логи и временные файлы
- Системные файлы ОС

## 🔐 Безопасность и файлы окружения

### Файлы с паролями (НЕ в git)

- ❌ `.env` — реальные пароли для Docker
- ❌ `deployment-scripts/config.sh` — credentials для деплоя
- ❌ Все файлы защищены через `.gitignore`

### Шаблоны (В git)

- ✅ `.env.example` — шаблон для локальной разработки
- ✅ `deployment-scripts/config.example.sh` — шаблон для деплоя

### Первоначальная настройка

```bash
# 1. Создать .env для Docker
cp .env.example .env
nano .env  # Изменить пароли

# 2. Создать config.sh для деплоя (если нужен)
cd deployment-scripts
cp config.example.sh config.sh
nano config.sh  # Вставить credentials
chmod 600 config.sh
```

**📚 Подробнее:** См. [docs/ENVIRONMENT_FILES.md](docs/ENVIRONMENT_FILES.md)

## Установка и запуск

1. **Убедитесь, что Docker и Docker Compose  установлены**

2. **Перейдите в директорию проекта:**
   ```bash
   cd www
   ```

3. **Запустите контейнеры:**
   ```bash
   docker compose up -d --build
   ```

4. **Проверьте статус контейнеров:**
   ```bash
   docker compose ps
   ```

5. **Откройте браузер и перейдите по адресу:**
   ```
   http://localhost
   ```

## Управление

### Просмотр логов
```bash
# Все логи
docker compose logs

# Логи определенного сервиса
docker compose logs nginx
docker compose logs php
docker compose logs mysql
```

### Остановка и перезапуск
```bash
# Остановить контейнеры
docker compose stop

# Запустить контейнеры
docker compose start

# Перезапустить контейнеры
docker compose restart

# Полностью остановить и удалить контейнеры
docker compose down
```

### Подключение к базе данных

**Параметры подключения:**
- **Хост:** localhost
- **Порт:** 3306
- **База данных:** wordpress_db
- **Пользователь:** wordpress_user
- **Пароль:** wordpress_password
- **Root пароль:** root_password_123

### Доступ к phpMyAdmin

Для удобного управления базой данных через веб-интерфейс доступен phpMyAdmin.

**URL:** `http://pma.localhost:8080`

**Логин:** `wordpress_user` (или `root` для полного доступа)  
**Пароль:** `wordpress_password` (или `root_password_123` для root)


### Полезные команды

```bash
# Войти в контейнер PHP
docker exec -it wordpress_php bash

# Войти в контейнер MySQL
docker exec -it wordpress_mysql mysql -u root -p

# Обновить права на файлы WordPress
docker exec wordpress_php chown -R phpuser:phpuser /var/www/html

# Просмотр использования ресурсов
docker stats
```

## Настройка WordPress

После запуска контейнеров WordPress будет доступен по адресу `http://localhost`. 

Первоначальная настройка включает:
1. Выбор языка
2. Создание администратора
3. Настройку сайта

Все настройки базы данных уже предварительно сконфигурированы в `wp-config.php`.

## Безопасность

В продакшн-среде рекомендуется:
1. Изменить все пароли в `.env` файле
2. Использовать SSL сертификаты
3. Настроить файрвол
4. Регулярно обновлять компоненты

## 🚀 Деплой на сервер

### Типы деплоя

У нас есть **два** типа деплоя:

#### 1. 🆕 Initial Deploy (Первый деплой)
Полная загрузка WordPress на чистый сервер:
- Всё ядро WordPress
- Все файлы wp-content (темы, плагины, uploads)
- Конфигурационные файлы
- Инициализация Git на сервере

```bash
# Первый деплой на PROD
./deployment-scripts/initial-deploy.sh prod

# Первый деплой на DEV
./deployment-scripts/initial-deploy.sh dev
```

**Когда использовать:**
- ✅ Первое развертывание на новом сервере
- ✅ После переезда на новый хостинг
- ✅ Полное восстановление сайта

#### 2. 🔄 Regular Deploy (Обычный деплой)
Инкрементальное обновление через Git:
- Только измененные файлы
- Быстро (git pull)
- Автоматический откат при ошибках

```bash
# Обычный деплой на PROD
./deployment-scripts/deploy-prod.sh

# Обычный деплой на DEV
./deployment-scripts/deploy-dev.sh
```

**Когда использовать:**
- ✅ Все последующие обновления после initial deploy
- ✅ Обновление кода, тем, плагинов
- ✅ Регулярные релизы

### Быстрый старт

```bash
# 1. Настроить конфигурацию деплоя
cd deployment-scripts
cp config.example.sh config.sh
nano config.sh  # Заполнить credentials
chmod 600 config.sh

# 2. ПЕРВЫЙ деплой (только один раз!)
./initial-deploy.sh prod

# 3. Все последующие деплои
./deploy-prod.sh
```

### Автоматическое определение типа деплоя

Скрипты **автоматически определяют**, нужен ли initial deploy:

```bash
# Если запустить deploy-prod.sh на чистом сервере:
./deploy-prod.sh

# Вы увидите:
# ⚠️  First deployment detected!
# You should use the initial-deploy.sh script instead.
```

### Важно!

- **Деплой запускается С ХОСТА** (вашего MacBook), НЕ из Docker контейнера
- Docker используется только для локальной разработки
- Initial deploy использует `rsync` для полной загрузки
- Regular deploy использует `git pull` для инкрементальных обновлений

### Что входит в Initial Deploy

✅ **Загружается:**
- Ядро WordPress (wp-admin, wp-includes)
- wp-content полностью (темы, плагины, uploads)
- wp-config.php
- .htaccess
- index.php

❌ **НЕ загружается** (см. `.deployignore`):
- node_modules/
- .git/ (локальный)
- docker-compose.yml
- deployment-scripts/
- logs/
- .env файлы

### 📚 Документация по деплою

- 📋 [DEPLOYMENT_CHEATSHEET.md](docs/DEPLOYMENT_CHEATSHEET.md) — **быстрая справка**
- 📘 [INITIAL_DEPLOYMENT.md](docs/INITIAL_DEPLOYMENT.md) — детальный гайд по первому деплою
- 📖 [DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md) — полный гайд по всем типам деплоя
- ⚙️ [CI_CD_DEPLOYMENT_PLAN.md](docs/CI_CD_DEPLOYMENT_PLAN.md) — автоматизация через GitHub Actions
- 📦 [.deployignore](../.deployignore) — список исключаемых файлов

### Git Hook (автобилд ассетов)

При каждом `git commit` автоматически билдятся CSS/JS файлы:
- Проверяется, изменились ли SCSS/JS исходники
- Запускается `npm run build`
- Собранные файлы добавляются в коммит
- При ошибке билда — коммит отменяется

**Преимущества:**
- ✅ Не нужен Node.js на сервере
- ✅ Быстрый деплой (только `git pull`)
- ✅ Всегда свежие ассеты в git

---

## 📚 Дополнительная документация

- [DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md) — полный гайд по деплою
- [CI_CD_DEPLOYMENT_PLAN.md](docs/CI_CD_DEPLOYMENT_PLAN.md) — CI/CD стратегия
- [GIT_HOOKS_SETUP.md](docs/GIT_HOOKS_SETUP.md) — настройка git hooks
2. Обновить соли безопасности в `wp-config.php`
3. Настроить SSL сертификаты
4. Ограничить доступ к административным файлам

## Бэкап

```bash
# Создать дамп базы данных
docker exec wordpress_mysql mysqldump -u root -p wordpress_db > backup.sql

# Архивировать файлы WordPress
tar -czf wordpress_files_backup.tar.gz wordpress/
```