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
├── nginx/
│   ├── nginx.conf             # Основная конфигурация Nginx
│   └── default.conf           # Конфигурация виртуального хоста
├── php/
│   ├── Dockerfile             # Кастомный образ PHP с расширениями
│   └── php.ini               # Конфигурация PHP
├── mysql/
│   └── my.cnf                # Конфигурация MySQL
├── wordpress/                 # Файлы WordPress
├── logs/                      # Логи всех сервисов
│   ├── nginx/
│   ├── php/
│   └── mysql/
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

## Установка и запуск

1. **Убедитесь, что Docker версии 27.4.0 и Docker Compose версии 2.31.0 установлены**

2. **Перейдите в директорию проекта:**
   ```bash
   cd /Users/adoknov/work/maslovka/www
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