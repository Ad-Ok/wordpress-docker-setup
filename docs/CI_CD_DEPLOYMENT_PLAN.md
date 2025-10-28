# 🚀 CI/CD и Deployment Plan для your-domain.com

## 📋 Содержание
1. [Архитектура деплоя](#архитектура-деплоя)
2. [Миграции базы данных](#миграции-базы-данных)
3. [CI/CD Pipeline](#cicd-pipeline)
4. [Требования к хостингу](#требования-к-хостингу)
5. [Стратегия деплоя](#стратегия-деплоя)
6. [Rollback план](#rollback-план)

---

## 🏗️ Архитектура деплоя

### Окружения

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   LOCAL     │────▶│     DEV     │────▶│  PRODUCTION │
│  (Docker)   │     │  (сервер)   │     │   (сервер)  │
└─────────────┘     └─────────────┘     └─────────────┘
```

**LOCAL:**
- Разработка в Docker
- Полная изоляция окружения
- База данных: MySQL 8.0 в контейнере

**DEV:**
- Тестирование перед продакшеном
- Автодеплой из ветки `dev`
- База: копия продакшена (1 раз в неделю)
- Домен: `dev.your-domain.com` или `your-domain.com/dev/`

**PRODUCTION:**
- Основной сайт
- Деплой из ветки `main` после ревью
- База: Production MySQL
- Домен: `your-domain.com`

---

## 🗄️ Миграции базы данных

### Проблема
WordPress не имеет встроенного механизма миграций БД, как Laravel или Django.

### Решение: Custom Migration System

#### 1. Структура миграций

```
wp-content/
  migrations/
    001_clean_old_plugins.sql
    002_fix_category_slugs.sql
    003_rename_cpt_sobitiya_to_events.sql
    004_rename_cpt_vistavki_to_exhibitions.sql
    005_migrate_pods_to_acf.sql
    006_add_artist_fields.sql
    007_create_photo_cpt.sql
    migration_runner.php
    .applied_migrations
```

#### 2. Формат миграции

```sql
-- Migration: 002_fix_category_slugs.sql
-- Description: Fix URL-encoded category slugs
-- Author: Dev Team
-- Date: 2025-10-24

-- === UP ===
UPDATE wp_terms SET slug = 'zhivopis' WHERE term_id = 19 AND slug = '%D0%B6%D0%B8%D0%B2%D0%BE%D0%BF%D0%B8%D1%81%D1%8C';
UPDATE wp_terms SET slug = 'soyuz-khudozhnikov' WHERE term_id = 22 AND slug = '%D1%81%D0%BE%D1%8E%D0%B7-%D1%85%D1%83%D0%B4%D0%BE%D0%B6%D0%BD%D0%B8%D0%BA%D0%BE%D0%B2';
UPDATE wp_terms SET slug = 'portret' WHERE term_id = 23 AND slug = '%D0%BF%D0%BE%D1%80%D1%82%D1%80%D0%B5%D1%82';

-- Flush rewrite rules (marker for PHP runner)
-- @flush_rewrite_rules

-- === DOWN ===
-- Rollback not recommended (SEO impact)
-- Keep old slugs in redirects table instead
```

#### 3. Migration Runner (WP-CLI команда)

```php
<?php
// wp-content/migrations/migration_runner.php

class Maslovka_Migration_Runner {
    
    private $migrations_dir;
    private $applied_file;
    
    public function __construct() {
        $this->migrations_dir = WP_CONTENT_DIR . '/migrations';
        $this->applied_file = $this->migrations_dir . '/.applied_migrations';
    }
    
    /**
     * Run pending migrations
     */
    public function migrate() {
        $pending = $this->get_pending_migrations();
        
        if (empty($pending)) {
            WP_CLI::success('No pending migrations');
            return;
        }
        
        foreach ($pending as $migration) {
            WP_CLI::log("Running: {$migration}");
            
            try {
                $this->run_migration($migration);
                $this->mark_as_applied($migration);
                WP_CLI::success("✓ {$migration}");
            } catch (Exception $e) {
                WP_CLI::error("✗ {$migration}: " . $e->getMessage());
                break; // Stop on first error
            }
        }
    }
    
    /**
     * Get list of pending migrations
     */
    private function get_pending_migrations() {
        $applied = $this->get_applied_migrations();
        $all = $this->get_all_migrations();
        
        return array_diff($all, $applied);
    }
    
    /**
     * Run single migration file
     */
    private function run_migration($file) {
        global $wpdb;
        
        $sql = file_get_contents($this->migrations_dir . '/' . $file);
        
        // Extract UP section
        preg_match('/-- === UP ===(.*?)(?:-- === DOWN ===|$)/s', $sql, $matches);
        $up_sql = trim($matches[1]);
        
        // Check for special markers
        $flush_rewrite = strpos($sql, '@flush_rewrite_rules') !== false;
        
        // Split by semicolon and execute
        $queries = array_filter(
            array_map('trim', explode(';', $up_sql)),
            function($q) {
                return !empty($q) && substr($q, 0, 2) !== '--';
            }
        );
        
        foreach ($queries as $query) {
            $result = $wpdb->query($query);
            if ($result === false) {
                throw new Exception($wpdb->last_error);
            }
        }
        
        // Execute post-migration actions
        if ($flush_rewrite) {
            flush_rewrite_rules();
        }
    }
    
    /**
     * Get applied migrations from file
     */
    private function get_applied_migrations() {
        if (!file_exists($this->applied_file)) {
            return [];
        }
        return array_filter(explode("\n", file_get_contents($this->applied_file)));
    }
    
    /**
     * Get all migration files
     */
    private function get_all_migrations() {
        $files = glob($this->migrations_dir . '/*.sql');
        return array_map('basename', $files);
    }
    
    /**
     * Mark migration as applied
     */
    private function mark_as_applied($migration) {
        file_put_contents(
            $this->applied_file,
            $migration . "\n",
            FILE_APPEND
        );
    }
    
    /**
     * Show migration status
     */
    public function status() {
        $applied = $this->get_applied_migrations();
        $all = $this->get_all_migrations();
        $pending = array_diff($all, $applied);
        
        WP_CLI::log("\nMigration Status:\n");
        
        foreach ($all as $migration) {
            $status = in_array($migration, $applied) ? '✓' : '✗';
            WP_CLI::log("{$status} {$migration}");
        }
        
        WP_CLI::log("\n" . count($applied) . " applied, " . count($pending) . " pending\n");
    }
}

// Register WP-CLI command
if (defined('WP_CLI') && WP_CLI) {
    WP_CLI::add_command('your-project migrate', function($args, $assoc_args) {
        $runner = new Maslovka_Migration_Runner();
        $runner->migrate();
    });
    
    WP_CLI::add_command('your-project migrate:status', function($args, $assoc_args) {
        $runner = new Maslovka_Migration_Runner();
        $runner->status();
    });
}
```

#### 4. Интеграция в CI/CD

```yaml
# В deploy скрипте:
- name: Run database migrations
  run: |
    ssh $SERVER "cd $WEBROOT && wp your-project migrate:status"
    ssh $SERVER "cd $WEBROOT && wp your-project migrate"
```

#### 5. Редиректы (301) для SEO

```php
<?php
// wp-content/mu-plugins/your-project-redirects.php
// Must-use plugin for redirects

add_action('init', 'your_project_handle_redirects', 1);

function your_project_handle_redirects() {
    $request_uri = $_SERVER['REQUEST_URI'];
    
    // Map old slugs to new
    $redirects = [
        // Old category slugs
        '/category/%D0%B6%D0%B8%D0%B2%D0%BE%D0%BF%D0%B8%D1%81%D1%8C/' => '/category/zhivopis/',
        '/category/%D1%81%D0%BE%D1%8E%D0%B7-%D1%85%D1%83%D0%B4%D0%BE%D0%B6%D0%BD%D0%B8%D0%BA%D0%BE%D0%B2/' => '/category/soyuz-khudozhnikov/',
        '/category/%D0%BF%D0%BE%D1%80%D1%82%D1%80%D0%B5%D1%82/' => '/category/portret/',
        
        // Old CPT slugs
        '/sobitiya/' => '/events/',
        '/vistavki/' => '/exhibitions/',
    ];
    
    // Check for matches (with and without trailing slash)
    foreach ($redirects as $old => $new) {
        if (
            strpos($request_uri, $old) === 0 ||
            strpos($request_uri, rtrim($old, '/')) === 0
        ) {
            wp_redirect($new . substr($request_uri, strlen($old)), 301);
            exit;
        }
    }
}
```

---

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy your-domain.com

on:
  push:
    branches:
      - main        # Production
      - dev         # Development
  pull_request:
    branches:
      - main

env:
  PHP_VERSION: '8.3'
  NODE_VERSION: '20'

jobs:
  # ============================================
  # 1. TESTS & VALIDATION
  # ============================================
  test:
    name: Tests & Validation
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: ${{ env.PHP_VERSION }}
          extensions: mysqli, mbstring, xml, gd
          tools: composer, wp-cli
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      
      - name: Install PHP dependencies
        run: |
          cd www/wordpress/wp-content/themes/your-theme
          composer install --no-interaction
      
      - name: Install Node dependencies
        run: |
          cd www/wordpress/wp-content/themes/your-theme
          npm ci
      
      - name: PHP Lint
        run: find www/wordpress/wp-content/themes/your-theme -name "*.php" -exec php -l {} \;
      
      - name: Build assets
        run: |
          cd www/wordpress/wp-content/themes/your-theme
          npm run build
      
      - name: Check migration syntax
        run: |
          for file in www/wordpress/wp-content/migrations/*.sql; do
            echo "Checking $file"
            # Simple syntax check (можно расширить)
            grep -q "-- === UP ===" "$file" || exit 1
          done

  # ============================================
  # 2. BUILD ASSETS
  # ============================================
  build:
    name: Build Theme Assets
    runs-on: ubuntu-latest
    needs: test
    if: always() && (needs.test.result == 'success' || needs.test.result == 'skipped')
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      
      - name: Install dependencies
        run: |
          cd www/wordpress/wp-content/themes/your-theme
          npm ci
      
      - name: Build production assets
        run: |
          cd www/wordpress/wp-content/themes/your-theme
          npm run build
      
      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: theme-assets
          path: |
            www/wordpress/wp-content/themes/your-theme/assets/css/
            www/wordpress/wp-content/themes/your-theme/assets/js/
          retention-days: 7

  # ============================================
  # 3. DEPLOY TO DEV
  # ============================================
  deploy-dev:
    name: Deploy to DEV
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/dev' && github.event_name == 'push'
    environment:
      name: development
      url: https://dev.your-domain.com
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Download build artifacts
        uses: actions/download-artifact@v4
        with:
          name: theme-assets
          path: www/wordpress/wp-content/themes/your-theme/
      
      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.8.0
        with:
          ssh-private-key: ${{ secrets.DEV_SSH_KEY }}
      
      - name: Add server to known hosts
        run: ssh-keyscan -H ${{ secrets.DEV_HOST }} >> ~/.ssh/known_hosts
      
      - name: Deploy files via rsync
        run: |
          rsync -avz --delete \
            --exclude='.git' \
            --exclude='node_modules' \
            --exclude='*.log' \
            --exclude='wp-content/uploads' \
            --exclude='wp-content/cache' \
            --exclude='.env' \
            www/wordpress/ \
            ${{ secrets.DEV_USER }}@${{ secrets.DEV_HOST }}:${{ secrets.DEV_WEBROOT }}/
      
      - name: Run migrations
        run: |
          ssh ${{ secrets.DEV_USER }}@${{ secrets.DEV_HOST }} << 'EOF'
            cd ${{ secrets.DEV_WEBROOT }}
            wp your-project migrate:status
            wp your-project migrate
          EOF
      
      - name: Clear cache
        run: |
          ssh ${{ secrets.DEV_USER }}@${{ secrets.DEV_HOST }} << 'EOF'
            cd ${{ secrets.DEV_WEBROOT }}
            wp cache flush
            wp super-cache flush
          EOF
      
      - name: Notify on success
        if: success()
        run: |
          curl -X POST ${{ secrets.TELEGRAM_WEBHOOK }} \
            -d "chat_id=${{ secrets.TELEGRAM_CHAT_ID }}" \
            -d "text=✅ DEV deployed successfully: ${{ github.sha }}"

  # ============================================
  # 4. DEPLOY TO PRODUCTION
  # ============================================
  deploy-prod:
    name: Deploy to PRODUCTION
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment:
      name: production
      url: https://your-domain.com
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Download build artifacts
        uses: actions/download-artifact@v4
        with:
          name: theme-assets
          path: www/wordpress/wp-content/themes/your-theme/
      
      # === BACKUP BEFORE DEPLOY ===
      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.8.0
        with:
          ssh-private-key: ${{ secrets.PROD_SSH_KEY }}
      
      - name: Add server to known hosts
        run: ssh-keyscan -H ${{ secrets.PROD_HOST }} >> ~/.ssh/known_hosts
      
      - name: Create database backup
        run: |
          ssh ${{ secrets.PROD_USER }}@${{ secrets.PROD_HOST }} << 'EOF'
            cd ${{ secrets.PROD_WEBROOT }}
            BACKUP_FILE="backup-$(date +%Y%m%d-%H%M%S).sql.gz"
            wp db export - | gzip > ../backups/$BACKUP_FILE
            echo "Backup created: $BACKUP_FILE"
            
            # Keep only last 10 backups
            cd ../backups
            ls -t backup-*.sql.gz | tail -n +11 | xargs -r rm
          EOF
      
      - name: Create files backup
        run: |
          ssh ${{ secrets.PROD_USER }}@${{ secrets.PROD_HOST }} << 'EOF'
            cd ${{ secrets.PROD_WEBROOT }}/..
            BACKUP_FILE="files-$(date +%Y%m%d-%H%M%S).tar.gz"
            tar -czf backups/$BACKUP_FILE \
              --exclude='wp-content/cache' \
              --exclude='wp-content/uploads' \
              html/wp-content/themes/your-theme
            echo "Files backup created: $BACKUP_FILE"
          EOF
      
      # === DEPLOY ===
      - name: Enable maintenance mode
        run: |
          ssh ${{ secrets.PROD_USER }}@${{ secrets.PROD_HOST }} << 'EOF'
            cd ${{ secrets.PROD_WEBROOT }}
            wp maintenance-mode activate
          EOF
      
      - name: Deploy files via rsync
        run: |
          rsync -avz --delete \
            --exclude='.git' \
            --exclude='node_modules' \
            --exclude='*.log' \
            --exclude='wp-content/uploads' \
            --exclude='wp-content/cache' \
            --exclude='.env' \
            www/wordpress/ \
            ${{ secrets.PROD_USER }}@${{ secrets.PROD_HOST }}:${{ secrets.PROD_WEBROOT }}/
      
      - name: Run migrations
        run: |
          ssh ${{ secrets.PROD_USER }}@${{ secrets.PROD_HOST }} << 'EOF'
            cd ${{ secrets.PROD_WEBROOT }}
            wp your-project migrate:status
            wp your-project migrate
          EOF
      
      - name: Clear cache
        run: |
          ssh ${{ secrets.PROD_USER }}@${{ secrets.PROD_HOST }} << 'EOF'
            cd ${{ secrets.PROD_WEBROOT }}
            wp cache flush
            wp super-cache flush
          EOF
      
      - name: Disable maintenance mode
        if: always()
        run: |
          ssh ${{ secrets.PROD_USER }}@${{ secrets.PROD_HOST }} << 'EOF'
            cd ${{ secrets.PROD_WEBROOT }}
            wp maintenance-mode deactivate
          EOF
      
      # === SMOKE TESTS ===
      - name: Smoke test - Check homepage
        run: |
          STATUS=$(curl -o /dev/null -s -w "%{http_code}" https://your-domain.com)
          if [ "$STATUS" != "200" ]; then
            echo "Homepage returned $STATUS"
            exit 1
          fi
      
      - name: Smoke test - Check API
        run: |
          STATUS=$(curl -o /dev/null -s -w "%{http_code}" https://your-domain.com/wp-json/)
          if [ "$STATUS" != "200" ]; then
            echo "API returned $STATUS"
            exit 1
          fi
      
      # === NOTIFICATIONS ===
      - name: Notify on success
        if: success()
        run: |
          curl -X POST ${{ secrets.TELEGRAM_WEBHOOK }} \
            -d "chat_id=${{ secrets.TELEGRAM_CHAT_ID }}" \
            -d "text=✅ PRODUCTION deployed successfully: ${{ github.sha }}"
      
      - name: Notify on failure
        if: failure()
        run: |
          curl -X POST ${{ secrets.TELEGRAM_WEBHOOK }} \
            -d "chat_id=${{ secrets.TELEGRAM_CHAT_ID }}" \
            -d "text=🚨 PRODUCTION deployment FAILED: ${{ github.sha }}"
```

---

## 🖥️ Требования к хостингу

### Минимальные требования

| Компонент | Требование | Зачем |
|-----------|-----------|-------|
| **PHP** | 8.3+ | Современный WordPress + performance |
| **MySQL** | 8.0+ | JSON support, better performance |
| **Nginx/Apache** | Любой | Веб-сервер |
| **Disk Space** | 10 GB | Сайт (5GB) + бэкапы (5GB) |
| **RAM** | 512 MB | Минимум для PHP-FPM |
| **SSH доступ** | Обязательно | Для деплоя и WP-CLI |
| **WP-CLI** | Установлен | Для миграций и автоматизации |
| **Git** | Желательно | Для клонирования репозитория (опционально) |

### НЕ требуется

❌ Docker (будет работать на обычном LAMP/LEMP)  
❌ Root доступ  
❌ Composer на сервере (собираем локально)  
❌ Node.js на сервере (собираем в CI/CD)  
❌ Отдельный сервер для БД  
❌ Load balancer  
❌ Redis/Memcached (можно добавить позже)

### Структура на сервере

```
/home/user/
  ├── html/                          # Webroot
  │   ├── .htaccess                  # Permalinks
  │   ├── index.php
  │   ├── wp-config.php              # Конфиг с переменными окружения
  │   ├── wp-content/
  │   │   ├── themes/your-theme/       # Наша тема
  │   │   ├── plugins/               # Плагины
  │   │   ├── uploads/               # НЕ синхронизируется через git
  │   │   ├── cache/                 # НЕ синхронизируется через git
  │   │   ├── migrations/            # SQL миграции
  │   │   └── mu-plugins/            # Must-use плагины (редиректы)
  │   └── ...
  ├── backups/                       # Бэкапы (вне webroot!)
  │   ├── backup-20251024-120000.sql.gz
  │   ├── backup-20251023-120000.sql.gz
  │   └── files-20251024-120000.tar.gz
  └── logs/                          # Логи (опционально)
```

### Конфигурация wp-config.php для деплоя

```php
<?php
// wp-config.php

// === Database ===
define('DB_NAME', getenv('DB_NAME') ?: 'your_project_prod');
define('DB_USER', getenv('DB_USER') ?: 'your_project_user');
define('DB_PASSWORD', getenv('DB_PASSWORD'));
define('DB_HOST', getenv('DB_HOST') ?: 'localhost');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

// === Environment ===
define('WP_ENVIRONMENT_TYPE', getenv('WP_ENV') ?: 'production');

// === Security Keys === 
// (генерировать через https://api.wordpress.org/secret-key/1.1/salt/)
define('AUTH_KEY',         getenv('AUTH_KEY'));
define('SECURE_AUTH_KEY',  getenv('SECURE_AUTH_KEY'));
// ... остальные ключи

// === Debug (только для dev) ===
if (WP_ENVIRONMENT_TYPE === 'development') {
    define('WP_DEBUG', true);
    define('WP_DEBUG_LOG', true);
    define('WP_DEBUG_DISPLAY', false);
} else {
    define('WP_DEBUG', false);
}

// === Performance ===
define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '512M');
define('DISABLE_WP_CRON', true); // Использовать system cron

// === URLs ===
define('WP_HOME', getenv('WP_HOME') ?: 'https://your-domain.com');
define('WP_SITEURL', getenv('WP_SITEURL') ?: 'https://your-domain.com');

// === File System ===
define('FS_METHOD', 'direct'); // Для rsync деплоя

$table_prefix = 'wp_';

require_once ABSPATH . 'wp-settings.php';
```

### .env файл (НЕ коммитить!)

```bash
# .env (на сервере)
DB_NAME=your_project_prod
DB_USER=your_project_user
DB_PASSWORD=secure_password_here
DB_HOST=localhost

WP_ENV=production
WP_HOME=https://your-domain.com
WP_SITEURL=https://your-domain.com

AUTH_KEY='...'
SECURE_AUTH_KEY='...'
# ... остальные ключи
```

---

## 🎯 Стратегия деплоя

### 1. Первичный деплой (один раз)

```bash
# На сервере:
cd /home/user

# 1. Клонировать репозиторий (или залить через FTP)
git clone https://github.com/yourorg/your-project.git html

# 2. Установить WP-CLI (если нет)
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# 3. Создать папки
mkdir -p backups logs

# 4. Настроить права
chmod 755 html
chmod 644 html/wp-config.php
chown -R www-data:www-data html/wp-content/uploads
chown -R www-data:www-data html/wp-content/cache

# 5. Настроить .env
nano html/.env  # Добавить переменные окружения

# 6. Загрузить базу (первый раз)
wp db import backup.sql

# 7. Запустить миграции
wp your-project migrate

# 8. Обновить URL в базе (если нужно)
wp search-replace 'http://old-domain.com' 'https://your-domain.com'

# 9. Flush permalinks
wp rewrite flush

# 10. Создать cron для wp-cron
crontab -e
# Добавить:
# */5 * * * * wp --path=/home/user/html cron event run --due-now
```

### 2. Регулярные деплои (автоматически через CI/CD)

1. Push в `dev` → автодеплой на dev сервер
2. PR в `main` → тесты
3. Merge в `main` → автодеплой на production

### 3. Ручной деплой (если нужен)

```bash
# Локально:
cd www/wordpress/wp-content/themes/your-theme
npm run build

# Деплой:
rsync -avz --delete \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='wp-content/uploads' \
  --exclude='wp-content/cache' \
  www/wordpress/ \
  user@server:/home/user/html/

# На сервере:
ssh user@server
cd /home/user/html
wp your-project migrate
wp cache flush
```

---

## ↩️ Rollback Plan

### Автоматический rollback при ошибке

```yaml
# В GitHub Actions:
- name: Rollback on failure
  if: failure()
  run: |
    ssh ${{ secrets.PROD_USER }}@${{ secrets.PROD_HOST }} << 'EOF'
      cd ${{ secrets.PROD_WEBROOT }}/..
      
      # Restore files
      LATEST_FILE_BACKUP=$(ls -t backups/files-*.tar.gz | head -1)
      tar -xzf backups/$LATEST_FILE_BACKUP -C html/
      
      # Restore database
      LATEST_DB_BACKUP=$(ls -t backups/backup-*.sql.gz | head -1)
      gunzip -c backups/$LATEST_DB_BACKUP | wp db import -
      
      wp cache flush
      wp maintenance-mode deactivate
    EOF
```

### Ручной rollback

```bash
# На сервере:
cd /home/user

# 1. Включить maintenance mode
wp maintenance-mode activate

# 2. Восстановить файлы
BACKUP_DATE="20251024-120000"  # Выбрать нужную дату
tar -xzf backups/files-$BACKUP_DATE.tar.gz -C html/

# 3. Восстановить базу
gunzip -c backups/backup-$BACKUP_DATE.sql.gz | wp db import -

# 4. Откатить миграции (вручную, если нужно)
# Удалить последние строки из .applied_migrations
nano html/wp-content/migrations/.applied_migrations

# 5. Очистить кеш
wp cache flush
wp super-cache flush

# 6. Выключить maintenance mode
wp maintenance-mode deactivate
```

---

## 📦 GitHub Secrets (настроить в репозитории)

```
# Development
DEV_SSH_KEY          # Приватный SSH ключ
DEV_HOST             # Адрес сервера
DEV_USER             # SSH пользователь
DEV_WEBROOT          # Путь к webroot (/home/user/html)

# Production
PROD_SSH_KEY         # Приватный SSH ключ
PROD_HOST            # Адрес сервера
PROD_USER            # SSH пользователь  
PROD_WEBROOT         # Путь к webroot (/home/user/html)

# Notifications
TELEGRAM_WEBHOOK     # URL вебхука Telegram
TELEGRAM_CHAT_ID     # ID чата для уведомлений
```

---

## ⏱️ Время реализации

| Задача | Время |
|--------|-------|
| Настройка структуры миграций | 2 ч |
| Написание migration runner | 2 ч |
| Создание всех миграций (SQL) | 2 ч |
| Настройка GitHub Actions | 2 ч |
| Настройка серверов (dev + prod) | 1 ч |
| Тестирование деплоя | 2 ч |
| Документация | 1 ч |
| **ИТОГО** | **12 ч** |

---

## ✅ Чеклист перед запуском

### Локально:
- [ ] Создана структура миграций
- [ ] Написан migration runner
- [ ] Все SQL миграции готовы
- [ ] Настроен GitHub Actions workflow
- [ ] Добавлен .gitignore для чувствительных данных

### На серверах:
- [ ] Установлен PHP 8.3
- [ ] Установлен MySQL 8.0
- [ ] Установлен WP-CLI
- [ ] Настроен SSH доступ
- [ ] Созданы папки backups/ и logs/
- [ ] Настроены права на папки
- [ ] Создан .env файл с переменными

### В GitHub:
- [ ] Добавлены все Secrets
- [ ] Настроены окружения (dev, production)
- [ ] Включены branch protection rules для main

### Тестирование:
- [ ] Тестовый деплой на dev
- [ ] Проверка миграций
- [ ] Проверка rollback
- [ ] Smoke tests проходят
- [ ] Уведомления работают

---

## 🎯 Итог

**Что получаем:**
✅ Автоматический деплой из git  
✅ Безопасные миграции БД с версионированием  
✅ Автоматические бэкапы перед каждым деплоем  
✅ Возможность rollback за минуту  
✅ Минимальные требования к хостингу  
✅ Zero-downtime деплой (maintenance mode на пару секунд)  
✅ Smoke tests после деплоя  
✅ Уведомления в Telegram

**Минимальный хостинг:**
- Простой shared hosting / VPS
- PHP 8.3 + MySQL 8.0 + SSH + WP-CLI
- 10 GB места
- Без Docker, без root, без сложной инфраструктуры
