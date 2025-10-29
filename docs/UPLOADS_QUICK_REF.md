# 📤 Uploads Sync - Quick Reference

## Быстрый старт

```bash
cd /Users/adoknov/work/maslovka/www/deployment-scripts

# 1. Проверить что будет синхронизировано (безопасно)
./sync-uploads.sh dev --dry-run

# 2. Реальная синхронизация
./sync-uploads.sh dev

# 3. Для prod (после тестирования на dev)
./sync-uploads.sh prod
```

## Основные команды

| Команда | Описание |
|---------|----------|
| `./sync-uploads.sh dev` | Синхронизация на DEV |
| `./sync-uploads.sh prod` | Синхронизация на PROD |
| `./sync-uploads.sh dev --dry-run` | Проверка без реальной передачи |
| `./sync-uploads.sh dev --delete` | Синхронизация с удалением (осторожно!) |

## Что будет отфильтровано автоматически

- `.DS_Store`, `._*`, `__MACOSX` (macOS мусор)
- `Thumbs.db`, `desktop.ini` (Windows мусор)
- `*.swp`, `*~` (временные файлы)
- `.git/`, `.cache/`

## Размеры

- **Локальная папка**: 3.2 GB (9419 файлов)
- **15 файлов** размером >50MB
- **Оценка времени**: ~1.5-2 часа (первый раз)

## Для долгих операций используйте screen

```bash
# Запустить в screen
screen -S uploads-sync
./sync-uploads.sh prod

# Отсоединиться: Ctrl+A, затем D
# Вернуться: screen -r uploads-sync
```

## Типичный workflow

### Первый деплой:
```bash
./initial-deploy.sh dev    # Деплой инфраструктуры
./sync-uploads.sh dev      # Синхронизация uploads
```

### Обновление uploads:
```bash
# Если добавили новые изображения
./sync-uploads.sh dev      # Только новые/изменённые файлы!
```

## Проблемы и решения

### Обрыв соединения
→ Просто запустите скрипт снова - rsync продолжит с места остановки

### Медленная загрузка
→ Используйте screen/tmux, можно отключиться и вернуться позже

### Слишком большие файлы
→ См. UPLOADS_SYNC_GUIDE.md раздел "Оптимизация"

## Полная документация

- [UPLOADS_SYNC_GUIDE.md](UPLOADS_SYNC_GUIDE.md) - подробное руководство
- [UPLOADS_SOLUTION_SUMMARY.md](/Users/adoknov/work/maslovka/UPLOADS_SOLUTION_SUMMARY.md) - резюме решения
