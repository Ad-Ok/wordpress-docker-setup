# 🚀 Initial Deploy Guide

## Что это?

`initial-deploy.sh` — скрипт для **первоначального развертывания** WordPress сайта на новом сервере. Используется **ТОЛЬКО ОДИН РАЗ** при первом деплое.

## Когда использовать?

✅ **Используйте когда:**
- Разворачиваете сайт на новом сервере впервые
- Настраиваете новый DEV или PROD сервер
- Начинаете с чистого сервера (пустой директории)

❌ **НЕ используйте когда:**
- Сайт уже работает на сервере (используйте `deploy-prod.sh` или `deploy-dev.sh`)
- Нужно обновить только код (используйте обычный деплой)
- Нужно синхронизировать БД (используйте `database/db-sync.sh`)

## Предварительные требования

### 1. Локальное окружение

✅ Docker запущен и работает:
```bash
docker ps
```

✅ MySQL контейнер запущен:
```bash
docker ps | grep wordpress_mysql
```

✅ Локальная БД актуальна и соответствует текущей ветке Git

✅ WordPress файлы находятся в `/Users/adoknov/work/maslovka/www/wordpress/`

✅ Git репозиторий настроен с remote origin

### 2. Удаленный сервер

✅ SSH доступ настроен (SSH ключи)
```bash
ssh a1178098@141.8.194.203
```

✅ На сервере установлен WP-CLI
```bash
ssh a1178098@141.8.194.203 "wp --version"
```

✅ База данных создана на сервере (пользователь и пароль должны быть в `config.sh`)

### 3. Конфигурация

✅ `config.sh` заполнен корректными данными:
- SSH учетные данные
- Пути к директориям
- Данные БД (локальной и удаленной)
- Git ветки (main для prod, dev для dev)
- URLs сайтов

## Использование

### Деплой на PROD

```bash
cd /Users/adoknov/work/maslovka/www/deployment-scripts
./initial-deploy.sh prod
```

### Деплой на DEV

```bash
cd /Users/adoknov/work/maslovka/www/deployment-scripts
./initial-deploy.sh dev
```

## Что происходит при выполнении?

### Шаг 1: Проверка локального окружения
- Проверяет наличие WordPress директории
- Проверяет обязательные файлы (wp-config.php, index.php и т.д.)

### Шаг 2: Тест SSH соединения
- Проверяет возможность подключения к серверу

### Шаг 3: Проверка состояния сервера
- Проверяет существует ли директория
- **Предупреждает**, если найдена существующая установка WordPress
- Создает backup существующей установки (если есть)

### Шаг 4: Подготовка директорий
- Создает необходимые директории на сервере
- Очищает дефолтные файлы хостинга

### Шаг 5: Клонирование Git репозитория
- Клонирует репозиторий с нужной веткой (main для prod, dev для dev)
- Создает .git директорию на сервере

### 🆕 Шаг 5.5: Загрузка базы данных
**Это новый шаг! База данных теперь загружается автоматически.**

1. **Проверка Docker:**
   - Проверяет что Docker запущен
   - Проверяет что MySQL контейнер работает

2. **Backup удаленной БД:**
   - Если на сервере уже есть БД, создается backup
   - Backup сохраняется в `${BACKUP_DIR}/backup-before-initial-deploy-YYYYMMDD_HHMMSS.sql.gz`

3. **Экспорт локальной БД:**
   - Экспортирует БД из Docker контейнера `wordpress_mysql`
   - Создает временный `.sql.gz` файл

4. **Загрузка на сервер:**
   - Загружает дамп в `/tmp/` на сервере

5. **Импорт и search-replace:**
   ```bash
   # Импорт БД
   wp db import - < dump.sql.gz
   
   # Замена URL
   wp search-replace 'http://localhost' 'http://wordpresstest.ru.xsph.ru' \
     --precise --recurse-objects --all-tables --skip-columns=guid
   
   # Очистка кеша
   wp cache flush
   wp rewrite flush
   ```

### Шаг 6: Загрузка WordPress Core
- Архивирует WordPress файлы (исключая wp-content)
- Загружает на сервер
- Распаковывает

### Шаг 6.5: Загрузка wp-content/uploads
- Проверяет размер uploads директории
- **Предупреждает** если размер > 500MB
- Загружает uploads (с возможностью пропустить)

### Шаг 7: Установка прав доступа
- Устанавливает права 644 для файлов
- Устанавливает права 755 для директорий
- Специальные права для uploads (775)

### Шаг 8: Создание deployment marker
- Создает `.deployment-history/last-deployment.json`
- Записывает информацию о деплое

### Шаг 9: HTTP аутентификация (только DEV)
- Создает `.htpasswd` с пользователем test/test
- Создает `.htaccess` с базовой аутентификацией

### Шаг 10: Проверка установки
- Проверяет наличие критических файлов
- Показывает статистику (количество файлов, размер)

### 🆕 Шаг 11: Проверка подключения к БД
- Проверяет подключение к БД через WP-CLI
- Показывает количество таблиц
- Показывает Site URL и Home URL

## После деплоя

### 1. Проверьте сайт

**PROD:**
```
http://wordpresstest.ru.xsph.ru
```

**DEV:**
```
http://a1178098.xsph.ru
```

Для DEV используйте:
- Username: `test`
- Password: `test`

### 2. Проверьте админку WordPress

```
http://your-site.com/wp-admin
```

### 3. Проверьте базу данных

- Все страницы отображаются?
- Меню работает?
- Изображения загружаются?
- Ссылки корректные?

### 4. Для последующих обновлений

Используйте обычные скрипты деплоя:
```bash
./deploy-prod.sh  # Для продакшена
./deploy-dev.sh   # Для дева
```

## Откат

Если что-то пошло не так:

### 1. Откат БД на сервере

```bash
ssh a1178098@141.8.194.203
cd /home/a1178098/backups
ls -la backup-before-initial-deploy-*

# Восстановить
cd /home/a1178098/domains/wordpresstest.ru/public_html
wp db import ../backups/backup-before-initial-deploy-YYYYMMDD_HHMMSS.sql.gz
```

### 2. Удаление файлов

```bash
ssh a1178098@141.8.194.203
cd /home/a1178098/domains/wordpresstest.ru/public_html
rm -rf *
```

## Troubleshooting

### Docker не запущен

```
✗ Docker is not running
```

**Решение:**
```bash
# Запустить Docker Desktop
open -a Docker

# Подождать ~30 секунд
docker ps
```

### MySQL контейнер не запущен

```
⚠️ MySQL container is not running. Starting...
```

**Решение:**
```bash
docker start wordpress_mysql
docker ps | grep wordpress_mysql
```

### Не удается подключиться к БД

```
✗ Cannot connect to local database
```

**Решение:**
```bash
# Проверить credentials в config.sh
docker exec -it wordpress_mysql mysql -uwordpress -pwordpress wordpress

# Если не работает, пересоздать контейнер
cd /Users/adoknov/work/maslovka/www
docker-compose down
docker-compose up -d
```

### SSH ошибка

```
✗ Cannot connect to server
```

**Решение:**
```bash
# Проверить SSH ключи
ssh a1178098@141.8.194.203

# Добавить ключ если нужно
ssh-copy-id a1178098@141.8.194.203
```

### WP-CLI не найден на сервере

```
wp: command not found
```

**Решение:**
```bash
ssh a1178098@141.8.194.203
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
```

### Существующая установка WordPress

```
⚠️ WARNING: Existing WordPress installation detected!
```

**Решение:**
- Скрипт создаст backup автоматически
- Подтвердите перезапись, введя `yes`
- Или используйте обычный `deploy-prod.sh` вместо initial-deploy

## Best Practices

1. **Всегда проверяйте локальную БД перед деплоем:**
   ```bash
   docker exec -it wordpress_mysql mysql -uwordpress -pwordpress
   USE wordpress;
   SELECT COUNT(*) FROM wp_posts;
   SELECT option_value FROM wp_options WHERE option_name = 'siteurl';
   ```

2. **Делайте snapshot локальной БД:**
   ```bash
   cd /Users/adoknov/work/maslovka/www/deployment-scripts/database
   ./db-snapshot.sh create "before-initial-deploy"
   ```

3. **Проверяйте Git статус:**
   ```bash
   cd /Users/adoknov/work/maslovka/www/wordpress
   git status
   git log --oneline -5
   ```

4. **Убедитесь что на правильной ветке:**
   ```bash
   # Для PROD
   git checkout main
   
   # Для DEV
   git checkout dev
   ```

5. **После деплоя сразу проверьте сайт:**
   - Откройте в браузере
   - Проверьте основные страницы
   - Залогиньтесь в админку
   - Проверьте что всё работает

## Важные примечания

⚠️ **Этот скрипт заменяет всё на сервере!**
- Все файлы будут перезаписаны
- База данных будет заменена полностью
- Предыдущие данные будут утеряны (кроме backup)

⚠️ **Используйте ТОЛЬКО для первого деплоя!**
- Для последующих обновлений используйте `deploy-prod.sh` или `deploy-dev.sh`
- Для синхронизации БД используйте `database/db-sync.sh`

✅ **Скрипт создает автоматические backups:**
- БД сохраняется в `${BACKUP_DIR}/backup-before-initial-deploy-*`
- Существующие файлы сохраняются в `${BACKUP_DIR}/pre-initial-deploy-*`

## Контакты

Если возникли проблемы:
1. Проверьте logs в терминале
2. Проверьте `config.sh` настройки
3. Проверьте SSH доступ
4. Проверьте Docker и MySQL контейнер

---

**Дата создания:** 29 октября 2025  
**Версия:** 2.0 (с автоматической загрузкой БД)
