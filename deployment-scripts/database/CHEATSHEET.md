# 📋 Database Management - Шпаргалка

## 🚀 Первая установка

```bash
cd www/deployment-scripts/database
./install-hooks.sh
```

---

## 🔄 Частые команды

### Загрузить свежие данные с продакшена
```bash
./db-sync.sh pull prod
```

### Создать snapshot перед изменениями
```bash
./db-snapshot.sh create "описание"
```

### Откатить изменения
```bash
./db-snapshot.sh restore latest
```

### Создать миграцию
```bash
./db-create-migration.sh "add new table"
# Редактируйте: migrations/00X_add_new_table.sql
```

### Применить миграции
```bash
./db-migrate.sh apply local   # Тест локально
./db-migrate.sh apply dev     # Потом на DEV
./db-migrate.sh apply prod    # После тестов на PROD
```

---

## 📖 Полная документация

Читайте: [README.md](./README.md)

---

## 🆘 Что-то пошло не так?

```bash
# Восстановить последний snapshot
./db-snapshot.sh restore latest

# Посмотреть все snapshots
./db-snapshot.sh list

# Проверить Docker
docker ps | grep mysql

# Помощь
./db-snapshot.sh help
./db-sync.sh help
./db-migrate.sh help
```

---

## 🎯 Ваши 4 сценария

### 1. LOCAL → PROD (initial deploy)
```bash
./db-sync.sh push prod
```

### 2. PROD → LOCAL (обновить данные)
```bash
./db-sync.sh pull prod
```

### 3. LOCAL → DEV (миграции)
```bash
./db-migrate.sh apply dev
```

### 4. DEV → PROD (миграции)
```bash
./db-migrate.sh apply prod
```

---

## 🔀 Переключение веток

**Автоматически** (если установлен hook):
```bash
git checkout feature/blog  # БД переключается автоматически
```

**Вручную**:
```bash
./db-snapshot.sh create    # Сохранить текущую
git checkout feature/blog
./db-snapshot.sh restore latest  # Восстановить для новой ветки
```
