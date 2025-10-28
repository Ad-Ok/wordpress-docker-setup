# 🔐 Управление файлами окружения

## 📋 Структура файлов окружения

### Где хранятся credentials

```
www/
├── .env                                # Локальная разработка (Docker)
├── .env.example                        # Шаблон (в git)
│
├── deployment-scripts/
│   ├── config.sh                       # Credentials для деплоя (НЕ в git!)
│   └── config.example.sh               # Шаблон (в git)
│
└── wordpress/
    └── wp-config.php                   # WordPress конфиг (в git, без паролей)
```

### На серверах

```
DEV SERVER (your_server_ip)
/home/your_ssh_user/dev.your-domain.com/
└── wp-config.php                       # С реальными паролями БД

PROD SERVER (your_server_ip)
/home/your_ssh_user/your-domain.com/
└── wp-config.php                       # С реальными паролями БД
```

---

## ✅ Что защищено от попадания в git

### В .gitignore уже добавлено:

```gitignore
# Credentials & Secrets
.env
.env.local
.env.production
deployment-scripts/config.sh
creds.txt
```

### Проверка (выполнена):

```bash
✅ .env — НЕ отслеживается git
✅ deployment-scripts/config.sh — НЕ существует (нужно создать из example)
✅ creds.txt — НЕ отслеживается git (в корне maslovka/)
✅ Никакие пароли не попали в git
```

---

## 🔧 Файлы окружения

### 1. Локальная разработка (Docker)

**Файл:** `www/.env`

**Содержимое (текущее):**
```env
# MySQL Configuration
MYSQL_ROOT_PASSWORD=root_password_123
MYSQL_DATABASE=wordpress_db
MYSQL_USER=wordpress_user
MYSQL_PASSWORD=wordpress_password

# WordPress Configuration
WP_DEBUG=false
WP_MEMORY_LIMIT=256M

# Docker Configuration
COMPOSE_PROJECT_NAME=wordpress
```

**Статус:** ✅ НЕ в git (игнорируется)

---

### 2. Шаблон для разработки

**Нужно создать:** `www/.env.example`

**Содержимое:**
```env
# MySQL Configuration
MYSQL_ROOT_PASSWORD=your_root_password_here
MYSQL_DATABASE=wordpress_db
MYSQL_USER=wordpress_user
MYSQL_PASSWORD=your_password_here

# WordPress Configuration
WP_DEBUG=false
WP_MEMORY_LIMIT=256M

# Docker Configuration
COMPOSE_PROJECT_NAME=wordpress
```

**Статус:** ✅ Будет в git (без реальных паролей)

---

### 3. Деплой credentials

**Файл:** `www/deployment-scripts/config.sh`

**Текущее состояние:** ❌ НЕ создан (есть только config.example.sh)

**Нужно создать из шаблона:**
```bash
cd www/deployment-scripts
cp config.example.sh config.sh
nano config.sh  # Заполнить реальными данными
chmod 600 config.sh
```

**Содержимое (из creds.txt):**
```bash
# PROD SERVER
PROD_SSH_USER="your_ssh_user"
PROD_SSH_HOST="your_server_ip"
PROD_WEBROOT="/home/your_ssh_user/your-domain.com"
PROD_DB_NAME="your_db_name"
PROD_DB_USER="your_db_name"
PROD_DB_PASS="your_prod_db_password"

# DEV SERVER
DEV_SSH_USER="your_ssh_user"
DEV_SSH_HOST="your_server_ip"
DEV_WEBROOT="/home/your_ssh_user/dev.your-domain.com"
DEV_DB_NAME="your_db_name-dev"
DEV_DB_USER="your_db_name-dev"
DEV_DB_PASS="your_dev_db_password"
```

**Статус:** ✅ НЕ будет в git (игнорируется)

---

### 4. WordPress конфигурация

**Локально:** `www/wordpress/wp-config.php`

**На сервере:**
- DEV: `/home/your_ssh_user/dev.your-domain.com/wp-config.php`
- PROD: `/home/your_ssh_user/your-domain.com/wp-config.php`

**Содержимое (для сервера):**
```php
<?php
// ** MySQL settings ** //
define('DB_NAME', 'your_db_name');
define('DB_USER', 'your_db_name');
define('DB_PASSWORD', 'your_prod_db_password');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

// Для DEV:
// define('DB_NAME', 'your_db_name-dev');
// define('DB_USER', 'your_db_name-dev');
// define('DB_PASSWORD', 'your_dev_db_password');

// Authentication Unique Keys and Salts
define('AUTH_KEY',         'генерируется на https://api.wordpress.org/secret-key/1.1/salt/');
define('SECURE_AUTH_KEY',  'генерируется');
define('LOGGED_IN_KEY',    'генерируется');
define('NONCE_KEY',        'генерируется');
define('AUTH_SALT',        'генерируется');
define('SECURE_AUTH_SALT', 'генерируется');
define('LOGGED_IN_SALT',   'генерируется');
define('NONCE_SALT',       'генерируется');

$table_prefix = 'wp_';

define('WP_DEBUG', false);

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
```

---

## 🚀 Setup Instructions

### Для нового разработчика

```bash
# 1. Клонировать репозиторий
git clone https://github.com/Ad-Ok/wordpress-docker-setup.git
cd wordpress-docker-setup/www

# 2. Создать .env для локального Docker
cp .env.example .env
nano .env  # Изменить пароли для локальной разработки

# 3. Создать config.sh для деплоя (если нужен доступ к серверу)
cd deployment-scripts
cp config.example.sh config.sh
nano config.sh  # Вставить реальные credentials
chmod 600 config.sh

# 4. Запустить Docker
cd ..
docker compose up -d

# 5. Готово!
```

---

## 🔐 Безопасность

### ✅ Что в git

- ✅ `.env.example` — шаблон без паролей
- ✅ `deployment-scripts/config.example.sh` — шаблон без паролей
- ✅ Код, конфигурации, документация
- ✅ Собранные ассеты (CSS/JS)

### ❌ Что НЕ в git

- ❌ `.env` — реальные пароли Docker
- ❌ `deployment-scripts/config.sh` — реальные credentials серверов
- ❌ `creds.txt` — файл с паролями
- ❌ Логи, бэкапы, uploads
- ❌ `node_modules`, vendor

### 🔒 Дополнительная защита

```bash
# Права доступа к файлам с паролями
chmod 600 www/.env
chmod 600 www/deployment-scripts/config.sh
chmod 600 creds.txt

# Проверка, что ничего не утекло в git
git status
git ls-files | grep -E "\.env|config\.sh|creds"  # Должно быть пусто
```

---

## 📊 Сравнительная таблица

| Файл | Расположение | В Git? | Для чего |
|------|--------------|--------|----------|
| `.env` | `www/.env` | ❌ НЕТ | Локальный Docker |
| `.env.example` | `www/.env.example` | ✅ ДА | Шаблон для разработчиков |
| `config.sh` | `www/deployment-scripts/config.sh` | ❌ НЕТ | Credentials для деплоя |
| `config.example.sh` | `www/deployment-scripts/config.example.sh` | ✅ ДА | Шаблон для деплоя |
| `creds.txt` | `project-root/creds.txt` | ❌ НЕТ | Исходные пароли |
| `wp-config.php` (локально) | `www/wordpress/wp-config.php` | ⚠️ ДА* | WordPress конфиг |
| `wp-config.php` (на сервере) | `/home/.../wp-config.php` | ❌ НЕТ | WordPress с паролями БД |

*На сервере wp-config.php создается с реальными паролями БД при первичной настройке

---

## 🛠️ Создание недостающих файлов

Сейчас создам `.env.example` для шаблона.
