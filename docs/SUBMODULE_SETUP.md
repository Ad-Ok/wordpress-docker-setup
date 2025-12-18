# 📦 Git Submodule Setup для WordPress проекта

## ✅ Текущая структура

```
maslovka/
├── www/                                    # 📦 Репозиторий: wordpress-docker-setup
│   ├── .git/
│   ├── .gitmodules                        # Конфигурация submodules
│   ├── docker-compose.yml
│   ├── nginx/
│   ├── php/
│   ├── mysql/
│   └── wordpress/                          # 📦 Submodule: wordpress-submodule
│       ├── .git                           # Ссылка на submodule repo
│       ├── .gitignore                     # Игнорирует WordPress core
│       └── wp-content/                    # Контент проекта
│           ├── themes/
│           │   └── maslovka/
│           ├── plugins/
│           ├── fonts/
│           └── cache/
```

## 🔗 Настроенные репозитории

1. **Основной репозиторий (Docker setup)**
   - Репозиторий: `Ad-Ok/wordpress-docker-setup`
   - Путь: `/path/to/your/project/www/`
   - Ветка: `dev`

2. **Submodule (WordPress content)**
   - Репозиторий: `Sten129/wordpress-submodule`
   - Путь: `/path/to/your/project/www/wordpress/`
   - Ветка: `main`

## 📋 Как работать с submodules

### Клонирование проекта на новой машине

```bash
# Вариант 1: Клонировать с submodules сразу
git clone --recurse-submodules git@github.com:Ad-Ok/wordpress-docker-setup.git
cd wordpress-docker-setup

# Вариант 2: Клонировать и инициализировать submodules потом
git clone git@github.com:Ad-Ok/wordpress-docker-setup.git
cd wordpress-docker-setup
git submodule init
git submodule update
```

### Работа с WordPress контентом

```bash
# Перейти в submodule
cd www/wordpress

# Проверить текущую ветку
git branch

# Внести изменения
cd wp-content/themes/your-theme
# ... редактируете файлы ...

# Закоммитить изменения в submodule
git add .
git commit -m "Update theme styles"
git push origin main

# Вернуться в основной репозиторий и обновить ссылку на submodule
cd /path/to/your/project/www
git add wordpress
git commit -m "Update wordpress submodule to latest version"
git push origin dev
```

### Обновление submodule на последнюю версию

```bash
cd www/wordpress
git pull origin main

cd ..
git add wordpress
git commit -m "Update wordpress submodule"
git push
```

### Проверка статуса submodules

```bash
# Из корня основного репозитория
cd /path/to/your/project/www
git submodule status

# Показывает: commit_hash wordpress (branch_name)
```

## 🚀 Workflow для разработки

### Сценарий 1: Обновление темы

```bash
# 1. Перейти в wordpress submodule
cd /path/to/your/project/www/wordpress

# 2. Убедиться что на актуальной ветке
git checkout main
git pull origin main

# 3. Работать с темой
cd wp-content/themes/your-theme
vim style.css

# 4. Закоммитить в submodule
cd /path/to/your/project/www/wordpress
git add wp-content/themes/your-theme
git commit -m "feat: update header styles"
git push origin main

# 5. Обновить ссылку в основном репозитории
cd /path/to/your/project/www
git add wordpress
git commit -m "chore: update wordpress submodule"
git push origin dev
```

### Сценарий 2: Обновление Docker конфигурации

```bash
# 1. Работать в основном репозитории
cd /path/to/your/project/www
vim docker-compose.yml

# 2. Закоммитить
git add docker-compose.yml
git commit -m "feat: add Redis container"
git push origin dev
```

### Сценарий 3: Синхронизация с командой

```bash
# 1. Получить последние изменения основного репозитория
cd /path/to/your/project/www
git pull origin dev

# 2. Обновить submodules
git submodule update --remote --merge

# Или более безопасный вариант:
cd wordpress
git pull origin main
```

## ⚠️ Важные моменты

### 1. Submodule всегда на конкретном commit

Submodule в основном репозитории указывает на **конкретный коммит**, а не на ветку. Это означает:

```bash
# После git pull в основном репозитории
cd www/wordpress
git status
# Может показать: HEAD detached at 7053436

# Чтобы работать с веткой:
git checkout main
git pull origin main
```

### 2. Не забывайте коммитить изменения в двух местах

1. **Сначала** коммитите в submodule (`wordpress/`)
2. **Потом** коммитите обновление ссылки в основном репо (`www/`)

### 3. .gitignore в submodule

Файл `www/wordpress/.gitignore` игнорирует WordPress core файлы:
- `/wp-admin/`
- `/wp-includes/`
- `/index.php`
- И другие core файлы

Это значит, что в репозиторий `wordpress-submodule` попадает **только** `wp-content/`.

### 4. ⚠️ Деплой: незакоммиченные изменения только в submodule блокируют деплой

**Правило:** Изменения в главном репозитории (`www/`) НЕ являются препятствием для деплоя. Только **незакоммиченные изменения в submodule** (`wordpress/`) блокируют деплой.

**Почему:**
- Главный репозиторий может содержать локальные конфиги, документацию, временные файлы
- Submodule содержит **контент сайта** (темы, плагины, uploads) — это критично для консистентности
- Деплой скрипты синхронизируют именно submodule, поэтому он должен быть в чистом состоянии
## 🔧 Полезные команды

```bash
# Показать все submodules
git submodule

# Показать URL submodules
git config --file .gitmodules --get-regexp url

# Обновить все submodules до последних коммитов
git submodule update --remote

# Выполнить команду во всех submodules
git submodule foreach 'git pull origin main'

# Клонировать проект и сразу инициализировать submodules
git clone --recurse-submodules <repo-url>

# Удалить submodule (если нужно)
git submodule deinit wordpress
git rm wordpress
rm -rf .git/modules/wordpress
```

## 🎯 Advantages этой структуры

✅ **Разделение ответственности**: Docker setup отдельно, WordPress content отдельно
✅ **Версионирование**: Можно фиксировать конкретные версии wp-content с конкретными версиями Docker setup
✅ **Переиспользование**: Docker setup можно использовать для других WordPress проектов
✅ **Чистая история**: Изменения в контенте не засоряют историю инфраструктуры
✅ **Независимое развитие**: Можно работать над темой без пересборки Docker образов

## 📚 Дополнительные ресурсы

- [Git Submodules Documentation](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [Working with submodules](https://github.blog/open-source/git/working-with-submodules/)
- [Submodules best practices](https://www.atlassian.com/git/tutorials/git-submodule)

---

## ✅ Текущее состояние

- [x] WordPress репозиторий склонирован
- [x] Submodule добавлен в основной репозиторий
- [x] .gitignore настроен
- [x] Структура проверена
- [x] Готово к работе! 🎉
