# 🔒 Настройка HTTPS для localhost

**Дата:** 18 ноября 2025  
**Сложность:** ⭐⭐ Средняя (30-45 минут)  
**Статус:** План готов к выполнению

---

## 🎯 Цель

Настроить HTTPS на локальном Docker окружении для:
- ✅ Тестирования Radario (требует HTTPS)
- ✅ Отладки Mixed Content проблем
- ✅ Соответствия продакшн окружению
- ✅ Тестирования Service Workers и других HTTPS-only API

---

## 📋 План действий

### Этап 1: Генерация самоподписанного SSL сертификата (5 минут)

**Опция A: Использовать mkcert (рекомендуется, проще)**

```bash
# Установка mkcert (macOS)
brew install mkcert
brew install nss  # Для Firefox

# Инициализация локального CA
mkcert -install

# Создание сертификата для localhost
cd /Users/adoknov/work/maslovka/www
mkdir -p nginx/ssl
cd nginx/ssl

# Генерация сертификата
mkcert localhost 127.0.0.1 ::1
# Создаст: localhost+2.pem и localhost+2-key.pem

# Переименовать для удобства
mv localhost+2.pem localhost.crt
mv localhost+2-key.pem localhost.key
```

**Опция B: Использовать OpenSSL (классический способ)**

```bash
cd /Users/adoknov/work/maslovka/www
mkdir -p nginx/ssl
cd nginx/ssl

# Генерация приватного ключа
openssl genrsa -out localhost.key 2048

# Генерация сертификата (действителен 365 дней)
openssl req -new -x509 -key localhost.key -out localhost.crt -days 365 \
  -subj "/C=RU/ST=Moscow/L=Moscow/O=Maslovka Dev/CN=localhost"

# Установка сертификата в систему (macOS)
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain localhost.crt
```

---

### Этап 2: Обновление конфигурации Nginx (10 минут)

**Файл:** `/Users/adoknov/work/maslovka/www/nginx/default.conf`

```nginx
# HTTP сервер - редирект на HTTPS
server {
    listen 80;
    server_name localhost;
    
    # Редирект всех запросов на HTTPS
    return 301 https://$server_name$request_uri;
}

# HTTPS сервер
server {
    listen 443 ssl http2;
    server_name localhost;
    
    root /var/www/html;
    index index.php index.html;
    
    # SSL сертификаты
    ssl_certificate /etc/nginx/ssl/localhost.crt;
    ssl_certificate_key /etc/nginx/ssl/localhost.key;
    
    # SSL настройки (безопасность)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Отключаем сессии SSL для dev окружения
    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout 5m;
    
    # Логи
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    # PHP обработка
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
```

---

### Этап 3: Обновление docker-compose.yml (5 минут)

**Добавить volume для SSL сертификатов:**

```yaml
services:
  nginx:
    image: nginx:1.26.3
    container_name: wordpress_nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
      - ./nginx/ssl:/etc/nginx/ssl              # ← НОВОЕ
      - ./wordpress:/var/www/html
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - php
    networks:
      - wordpress_network
    restart: unless-stopped
```

---

### Этап 4: Обновление WordPress настроек (5 минут)

**1. Обновить `wp-config.php`:**

```php
// Добавить в начало файла (после <?php)
if (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') {
    $_SERVER['HTTPS'] = 'on';
    define('FORCE_SSL_ADMIN', true);
}

// Обновить URL
define('WP_HOME', 'https://localhost');
define('WP_SITEURL', 'https://localhost');
```

**2. Или обновить через WP-CLI в базе:**

```bash
docker exec wordpress_php wp option update home 'https://localhost' --path=/var/www/html --allow-root
docker exec wordpress_php wp option update siteurl 'https://localhost' --path=/var/www/html --allow-root
docker exec wordpress_php wp cache flush --path=/var/www/html --allow-root
```

---

### Этап 5: Перезапуск Docker контейнеров (2 минуты)

```bash
cd /Users/adoknov/work/maslovka/www

# Остановка контейнеров
docker-compose down

# Запуск с новой конфигурацией
docker-compose up -d

# Проверка логов
docker-compose logs -f nginx
```

---

### Этап 6: Проверка работы (5 минут)

**1. Открыть в браузере:**
```
https://localhost
```

**2. Проверить сертификат:**
- В Safari: замочек в адресной строке → "localhost" ✅
- В Chrome: замочек → "Соединение защищено" ✅

**3. Проверить Radario:**
```
https://localhost/events
```

**DevTools → Console:**
- ✅ Нет ошибки Mixed Content
- ✅ `radario.ru` загружается успешно

**DevTools → Network:**
- ✅ `GET https://radario.ru/.../openapi.js` (статус 200)

---

## 🔧 Альтернативный вариант: Использовать Traefik

Если хотите более профессиональное решение с автоматическим SSL:

```yaml
# docker-compose.yml
services:
  traefik:
    image: traefik:v3.0
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Traefik dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./traefik/certs:/certs
  
  nginx:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress.rule=Host(`localhost`)"
      - "traefik.http.routers.wordpress.entrypoints=websecure"
      - "traefik.http.routers.wordpress.tls=true"
```

---

## 📊 Сравнение вариантов

| Вариант | Сложность | Время | Плюсы | Минусы |
|---------|-----------|-------|-------|--------|
| **mkcert** | ⭐⭐ | 30 мин | Легко, доверенный сертификат | Нужна установка утилиты |
| **OpenSSL** | ⭐⭐ | 35 мин | Встроен в macOS | Браузер показывает предупреждение |
| **Traefik** | ⭐⭐⭐ | 60 мин | Автоматизация, production-ready | Сложнее настройка |

**Рекомендация:** Использовать **mkcert** для локальной разработки.

---

## ⚠️ Важные моменты

### 1. Добавить SSL папку в .gitignore

```bash
# .gitignore
nginx/ssl/*.key
nginx/ssl/*.crt
nginx/ssl/*.pem
```

**Сертификаты НЕ должны попадать в git!**

### 2. Кеш браузера

После настройки HTTPS очистить кеш:
- Safari: Cmd+Option+E
- Chrome: Cmd+Shift+Delete

### 3. Обновить переменную в enqueue-assets.php

Убрать проверку `!$is_local` или изменить на:

```php
// Теперь localhost использует HTTPS, можно загружать Radario
$is_local_http = (
    strpos(home_url(), 'http://localhost') !== false ||
    strpos(home_url(), 'http://127.0.0.1') !== false
);

if ($needs_radario && !$is_local_http) {
    // Загружаем Radario (будет работать на https://localhost)
}
```

---

## 🎯 Ожидаемый результат

После настройки:

| URL | Работает | Radario | SSL |
|-----|----------|---------|-----|
| `http://localhost` | ✅ Редирект на HTTPS | - | - |
| `https://localhost` | ✅ Работает | ✅ Загружается | 🔒 Защищено |
| `https://dev.maslovka.org` | ✅ Работает | ✅ Загружается | 🔒 Защищено |
| `http://maslovka.org` | ✅ Работает | ✅ Загружается | - |

---

## 📝 Чек-лист выполнения

- [ ] Установлен mkcert (или OpenSSL готов)
- [ ] Сгенерированы SSL сертификаты
- [ ] Создана папка `nginx/ssl/`
- [ ] Обновлен `nginx/default.conf`
- [ ] Обновлен `docker-compose.yml`
- [ ] Добавлен volume для SSL
- [ ] Обновлен `wp-config.php` или база данных
- [ ] Перезапущен Docker
- [ ] Проверен доступ к `https://localhost`
- [ ] Проверен Radario на странице событий
- [ ] Добавлено в `.gitignore`: `nginx/ssl/`

---

## 🚀 Быстрый старт (для ленивых)

```bash
# Полный скрипт установки
cd /Users/adoknov/work/maslovka/www

# 1. Установка mkcert
brew install mkcert nss
mkcert -install

# 2. Создание сертификатов
mkdir -p nginx/ssl
cd nginx/ssl
mkcert localhost 127.0.0.1 ::1
mv localhost+2.pem localhost.crt
mv localhost+2-key.pem localhost.key
cd ../..

# 3. Обновление docker-compose.yml (вручную)
# Добавить: - ./nginx/ssl:/etc/nginx/ssl

# 4. Обновление nginx/default.conf (вручную)
# Скопировать конфиг из плана выше

# 5. Обновление WordPress
docker-compose up -d
docker exec wordpress_php wp option update home 'https://localhost' --path=/var/www/html --allow-root
docker exec wordpress_php wp option update siteurl 'https://localhost' --path=/var/www/html --allow-root
docker exec wordpress_php wp cache flush --path=/var/www/html --allow-root

# 6. Перезапуск
docker-compose restart

# 7. Открыть
open https://localhost
```

---

## 📚 Полезные ссылки

- [mkcert - GitHub](https://github.com/FiloSottile/mkcert)
- [SSL в Docker - Best Practices](https://docs.docker.com/engine/security/https/)
- [Nginx SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)

---

**Вопрос:** Хотите, чтобы я начал выполнять этот план? Начнем с генерации сертификатов через mkcert?
