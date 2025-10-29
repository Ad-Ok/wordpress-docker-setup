# 📝 Deployment Scripts - Quick Reference

## 🚀 Основные команды

```bash
# 🆕 INITIAL DEPLOY (первый раз на новом сервере)
./deployment-scripts/initial-deploy.sh prod   # Первый деплой на PROD (включая БД)
./deployment-scripts/initial-deploy.sh dev    # Первый деплой на DEV (включая БД)

# DEV деплой (ежедневная работа)
./deployment-scripts/deploy-dev.sh

# PROD деплой (релиз)
./deployment-scripts/deploy-prod.sh

# Hotfix (срочное исправление)
./deployment-scripts/hotfix.sh "описание бага"

# Rollback (откат)
./deployment-scripts/rollback.sh prod

# Pre-deployment checklist (проверки)
./deployment-scripts/pre-deployment-checklist.sh

# Smoke tests (тесты после деплоя)
./deployment-scripts/smoke-tests.sh prod
```

## 📁 Структура

```
deployment-scripts/
├── README.md                          # Документация
├── QUICK_START.md                     # Эта шпаргалка (в docs/)
├── INITIAL_DEPLOY_GUIDE.md            # 🆕 Подробная инструкция для initial-deploy (в docs/)
├── config.example.sh                  # Пример конфигурации
├── config.sh                          # Ваша конфигурация (НЕ коммитить!)
├── initial-deploy.sh                  # 🆕 Первоначальный деплой (включая БД)
├── deploy-dev.sh                      # Деплой на DEV
├── deploy-prod.sh                     # Деплой на PROD
├── rollback.sh                        # Откат к предыдущей версии
├── pre-deployment-checklist.sh        # 10 проверок перед деплоем
├── smoke-tests.sh                     # 8 тестов после деплоя
├── hotfix.sh                          # Быстрый хотфикс
└── utils/
    ├── backup.sh                      # Бэкап БД и файлов
    └── notifications.sh               # Уведомления (Telegram/Email)
```

## ⚙️ Первоначальная настройка

```bash
# 1. Скопировать и настроить конфигурацию
cd deployment-scripts
cp config.example.sh config.sh
nano config.sh

# 2. Защитить credentials
chmod 600 config.sh

# 3. Проверить, что скрипты исполняемые
chmod +x *.sh utils/*.sh

# 4. Настроить Git Hook для автобилда
# (уже настроен в .git/hooks/pre-commit)
```

## 🎯 Ответы на ваши вопросы

### 1. ✅ Без Composer — всё через копирование файлов
Решено: все плагины/темы в git, никаких `composer install`

### 2. ✅ Git на сервере — деплой через SSH
Решено: все скрипты используют `ssh` + `git pull`

### 3. ✅ Билд ассетов локально через Git Hooks
**Решение:** Pre-commit hook автоматически билдит CSS/JS

**Как работает:**
```bash
# При коммите:
git commit -m "fix: update styles"

# Автоматически:
# 1. Проверяет изменения в SCSS/JS
# 2. Билдит ассеты (npm run build)
# 3. Добавляет собранные файлы в коммит
# 4. Если ошибка — отменяет коммит
```

**Преимущества:**
- ✅ Не нужен Node.js на сервере
- ✅ Быстрый деплой (только `git pull`)
- ✅ Всегда свежие ассеты в git
- ✅ Нет конфликтов при merge

**Нюансы:**
- ⚠️ Собранные файлы **НЕ** добавляем в `.gitignore`
- ⚠️ Размер репозитория немного больше
- ⚠️ При merge могут быть конфликты в CSS/JS (редко)

### 4. ✅ База данных — пока не обсуждаем
Окей, сфокусировались только на файлах

### 5. ✅ Hotfix и Rollback — реализованы!

**Hotfix workflow:**
```bash
./hotfix.sh "Fix critical bug"
# Создаёт ветку hotfix/fix-critical-bug
# Коммитит
# Пушит
# Merge в main
# Deploy на PROD
# Удаляет hotfix ветку
```

**Rollback workflow:**
```bash
./rollback.sh prod
# Показывает список бэкапов
# Выбираешь нужный
# Восстанавливает БД + файлы
# Готово!
```

### 6. ✅ Пункт 4 (Релизный деплой) — детали

**Pre-deployment checklist** (10 проверок):
1. Git статус (нет незакоммиченных)
2. Собранные ассеты (свежие CSS/JS)
3. Зависимости (package-lock актуален)
4. PHP синтаксис (нет ошибок)
5. Версия темы (обновлена)
6. Миграции (есть новые)
7. .gitignore (собранные файлы в git)
8. SSH к серверу (работает)
9. Диск (есть место)
10. Бэкап (недавний существует)

**Smoke tests** (8 тестов):
1. Homepage — HTTP 200
2. REST API — работает
3. Admin Ajax — доступен
4. CSS — загружается
5. JS — загружается
6. PHP ошибки — нет в логах
7. Response time — < 5 сек
8. Критичные страницы — работают

**Реализация:**
- Всё в `deploy-prod.sh`
- Автоматически запускается checklist
- Спрашивает подтверждение
- Делает бэкап
- Включает maintenance mode
- Git pull
- Миграции
- Очистка кеша
- Выключает maintenance
- Запускает smoke tests
- Отправляет уведомление

---

## 🎨 Git Hooks — детали

### Pre-commit Hook

**Файл:** `.git/hooks/pre-commit`

**Логика:**
```bash
# 1. Проверяет staged изменения
git diff --cached --name-only

# 2. Если изменились SCSS/JS исходники
if [ SCSS changed ]; then
    npm run build:css
    git add assets/css/*.css
fi

if [ JS changed ]; then
    npm run build:js
    git add assets/js/*.min.js
fi

# 3. Если билд упал — отменяет коммит
if [ build failed ]; then
    exit 1
fi
```

**Отключить (если нужно):**
```bash
git commit --no-verify -m "skip hook"
```

### package.json в теме

Должен содержать:
```json
{
  "scripts": {
    "build": "npm run build:css && npm run build:js",
    "build:css": "sass assets/scss:assets/css --style=compressed",
    "build:js": "webpack --mode production"
  }
}
```

---

## 📊 Итоговая архитектура

```
LOCAL (MacBook)
│
├─ Работа в dev ветке
├─ Git commit → Pre-commit hook → Билд ассетов
├─ Git push → На сервер идут готовые файлы
│
↓
DEV SERVER (your_server_ip)
│
├─ /home/your_ssh_user/dev.your-domain.com
├─ Git pull origin dev
├─ Миграции (если есть)
├─ Очистка кеша
├─ Готово! dev.your-domain.com
│
↓ (после тестирования)
│
PROD SERVER (your_server_ip)
│
├─ /home/your_ssh_user/your-domain.com
├─ Pre-deployment checklist ✓
├─ Бэкап БД + файлов
├─ Maintenance mode ON
├─ Git pull origin main
├─ Миграции
├─ Очистка кеша
├─ Maintenance mode OFF
├─ Smoke tests ✓
└─ your-domain.com работает!
```

---

## 🔥 Ваше решение: Bash-скрипты + Git Hooks

**Плюсы:**
- ✅ Простота (нет CI/CD сервисов)
- ✅ Контроль (всё локально)
- ✅ Быстрота (мгновенный деплой)
- ✅ Гибкость (можно кастомизировать)
- ✅ Автоматизация (git hooks)
- ✅ Безопасность (бэкапы + rollback)

**Минусы:**
- ⚠️ Требует SSH доступ
- ⚠️ Собранные файлы в git (больше размер)
- ⚠️ Нужно настроить локально (один раз)

---

## 🎯 Что дальше?

1. **Настроить config.sh** с данными из `creds.txt`
2. **Протестировать deploy-dev.sh**
3. **Сделать тестовый коммит** (проверить git hook)
4. **Протестировать deploy-prod.sh --dry-run**
5. **Сделать первый PROD деплой**
6. **Настроить уведомления** (Telegram/Email)

---

## 📚 Полная документация

См. [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
