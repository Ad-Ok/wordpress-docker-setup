# 🚀 Deployment Cheatsheet

Быстрая справка по деплою WordPress.

## 🎯 Какой скрипт использовать?

```
┌─────────────────────────────────────────────────────────┐
│  Это первый раз на сервере?                             │
│                                                          │
│  ✅ ДА  →  ./initial-deploy.sh [prod|dev]              │
│  ❌ НЕТ →  ./deploy-prod.sh или ./deploy-dev.sh        │
└─────────────────────────────────────────────────────────┘
```

## 📋 Быстрый старт

### Первый раз (Initial Setup)

```bash
# 1. Настройка конфигурации
cd deployment-scripts
cp config.example.sh config.sh
nano config.sh

# 2. Первый деплой на DEV
./initial-deploy.sh dev

# 3. Первый деплой на PROD (когда готовы)
./initial-deploy.sh prod
```

### Ежедневная работа

```bash
# 1. Разработка
git add .
git commit -m "feat: new feature"  # автобилд CSS/JS
git push origin dev

# 2. Деплой на DEV
./deploy-dev.sh

# 3. Тестирование, затем мерж в main
git checkout main
git merge dev
git push origin main

# 4. Деплой на PROD
./deploy-prod.sh
```

## 📁 Что загружается

### Initial Deploy (первый раз)

```
✅ Загружается:
  • Ядро WordPress (wp-admin, wp-includes)
  • wp-content полностью
  • wp-config.php, .htaccess
  • Все темы и плагины
  • Uploads (картинки)

❌ НЕ загружается:
  • node_modules/
  • .git/ (локальный)
  • deployment-scripts/
  • docker-compose.yml
  • logs/, .env
```

### Regular Deploy (обычный)

```
✅ Обновляется:
  • Только измененные файлы (git pull)
  • Быстро и эффективно
```

## 🔧 Команды

### Initial Deployment

```bash
# PROD
./initial-deploy.sh prod

# DEV
./initial-deploy.sh dev
```

**Что делает:**
- Загружает полный WordPress через rsync
- Инициализирует Git на сервере
- Настраивает права доступа
- ~5-10 минут

### Regular Deployment

```bash
# PROD (с проверками)
./deploy-prod.sh

# DEV (быстро)
./deploy-dev.sh

# Dry-run (тест без изменений)
./deploy-prod.sh --dry-run
```

**Что делает:**
- Pre-deployment checklist
- Бэкап
- Git pull
- Миграции
- Smoke tests
- ~30 секунд

### Откат (Rollback)

```bash
# Откатить на 1 коммит назад
./rollback.sh prod

# Откатить на конкретный коммит
./rollback.sh prod abc123
```

### Hotfix (Срочное исправление)

```bash
# Создать hotfix ветку и задеплоить
./hotfix.sh prod "fix-critical-bug"
```

## 🔍 Проверки

### До деплоя

```bash
# Проверить что готово к деплою
./pre-deployment-checklist.sh
```

**Проверяет:**
- ✓ Git статус (нет незакомиченных изменений)
- ✓ На правильной ветке
- ✓ Изменения запушены
- ✓ Тесты проходят
- ✓ Билд успешен

### После деплоя

```bash
# Smoke tests автоматически, но можно запустить вручную
./smoke-tests.sh prod
```

**Проверяет:**
- ✓ Сайт отвечает (HTTP 200)
- ✓ Админка доступна
- ✓ API работает

## 🔐 Безопасность

### Файлы с паролями

```bash
# В .gitignore (НЕ коммитятся):
deployment-scripts/config.sh    # SSH credentials
.env                             # Docker passwords

# Шаблоны (в git):
deployment-scripts/config.example.sh
.env.example
```

### Настройка config.sh

```bash
cd deployment-scripts
cp config.example.sh config.sh
chmod 600 config.sh  # Важно!
nano config.sh

# Заполнить:
PROD_SSH_USER="your_user"
PROD_SSH_HOST="your_ip"
PROD_WEBROOT="/path/to/site"
```

## 🆘 Troubleshooting

### Скрипт говорит "First deployment detected"

```bash
# Это нормально для первого раза!
# Используйте:
./initial-deploy.sh prod

# Не используйте:
./deploy-prod.sh  # это для обновлений
```

### SSH connection failed

```bash
# Проверить SSH ключи
ssh-add -l
ssh-add ~/.ssh/id_rsa

# Проверить подключение
ssh your_user@your_server
```

### Permission denied

```bash
# На сервере
ssh your_user@your_server
sudo chown -R $USER:$USER /path/to/site
```

### Git pull failed

```bash
# На сервере проверить Git
ssh your_user@your_server
cd /path/to/site
git status
git remote -v
```

### Сайт не работает после деплоя

```bash
# Откатиться
./rollback.sh prod

# Проверить логи на сервере
ssh your_user@your_server
tail -f /var/log/nginx/error.log
tail -f /var/log/php-fpm/error.log
```

## 📊 Сравнение скриптов

| Скрипт | Когда | Метод | Скорость | Проверки |
|--------|-------|-------|----------|----------|
| `initial-deploy.sh` | Первый раз | rsync | 🐢 5-10 мин | Базовые |
| `deploy-prod.sh` | Обновления PROD | git pull | ⚡ 30 сек | Полные |
| `deploy-dev.sh` | Обновления DEV | git pull | ⚡ 10 сек | Минимальные |
| `hotfix.sh` | Срочные фиксы | git cherry-pick | ⚡ 1 мин | Средние |
| `rollback.sh` | Откат | git reset | ⚡ 20 сек | Smoke tests |

## 📚 Документация

- [README.md](../README.md) — общая информация
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) — полный гайд
- [INITIAL_DEPLOYMENT.md](INITIAL_DEPLOYMENT.md) — детали первого деплоя
- [.deployignore](../.deployignore) — что не загружается

## ✅ Чеклист перед деплоем

```bash
□ Все изменения закоммичены
□ Билд успешен (CSS/JS собраны)
□ Тесты проходят
□ Изменения запушены в нужную ветку
□ config.sh настроен
□ SSH доступ работает
□ Есть свежий бэкап (для PROD)
□ Уведомлена команда (для PROD)
```

## 💡 Полезные команды

```bash
# Проверить что изменится
git diff origin/main

# Посмотреть историю деплоев (на сервере)
ssh user@server
cd /path/to/site
git log --oneline -10

# Проверить текущую версию на сервере
ssh user@server "cd /path/to/site && git rev-parse --short HEAD"

# Список бэкапов
ssh user@server "ls -lth /path/to/backups | head -10"

# Размер сайта на сервере
ssh user@server "du -sh /path/to/site"
```

---

**🚀 Happy Deploying!**
