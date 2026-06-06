# CLAUDE.md — проект Maslovka (maslovka.org)

Сайт музея «Городок художников на Масловке». WordPress + кастомная тема, LEMP в Docker.

## ⚠️ Главный источник правды

**Детальная инструкция:** [wordpress/.github/copilot-instructions.md](wordpress/.github/copilot-instructions.md).
Читай её ПЕРЕД любой задачей — там CPT, ACF-поля, БД, миграции, деплой, сборка темы.
Этот файл — только краткая выжимка для Claude Code.

## Структура репозиториев (ДВЕ git-репы!)

- `~/work/maslovka/` — просто папка-контейнер, **НЕ git-репозиторий** (локальные дампы, скриншоты, переписка).
- `~/work/maslovka/www/` — **основная репа** `Ad-Ok/wordpress-docker-setup`. Docker-обвязка, deploy-скрипты, настройки Claude (`CLAUDE.md`, `.claude/`), общая документация по инфраструктуре в `docs/`. НЕ деплоится на сервер (см. `.deployignore`).
- `~/work/maslovka/www/wordpress/` — **git submodule** `Sten129/maslovkaorg`. Сам WordPress-проект: темы, плагины, миграции, документация по фичам сайта (`wordpress/docs/`). **Это деплоится на сервер** (через `git pull` на сервере).

Изменения кода сайта и документация по фичам → в submodule `wordpress/`.
Настройки Claude / Docker / деплой-обвязка → в основную репу `www/`.
Помни про двойной коммит при изменении submodule (коммит в сабрепе + обновление указателя в `www/`).

## Команды

```bash
# Docker (всегда из www/, всегда `docker compose` с пробелом)
docker compose up -d
docker compose exec php bash
docker compose exec mysql mysql -u wordpress_user -pwordpress_password wordpress_db

# Сборка темы (Node 20, из wordpress/wp-content/themes/maslovka/)
npm run build        # production (+ i18n)
npm run build:dev    # dev без минификации
npm run watch        # авто-пересборка
npm run test         # jest + проверка билда
```

**Собранные ассеты (`assets/css`, `assets/js`) коммитятся** — на сервере нет Node.

## Где что искать в теме

`wordpress/wp-content/themes/maslovka/`
- `single-events.php`, `page-events-universal.php` — события
- `inc/components/` — переиспользуемые блоки (`events-grid.php`, `exhibitions-grid.php`)
- `inc/helpers/acf-helpers.php` — `maslovka_get_field($selector, $post_id, $format, $default)` с экранированием (`text|html|url|attr|raw`)
- `src/scss/`, `src/js/` — исходники (правим здесь, потом `npm run build`)

ACF-поля задаются КОДОМ в `wordpress/wp-content/mu-plugins/maslovka-custom-fields/inc/acf-fields/`
(напр. `events.php`). **Не создавать поля через админку** — только в этих файлах.

## Кнопка Radario в событиях (контекст текущей задачи)

Реализована через два ACF-поля события (`events.php`):
- `ссылка_для_кнопки` (text) — сюда вставляют HTML/JS-эмбед Radario, выводится как `raw`
- `текст_в_кнопке` (text) — подпись, прокидывается в `data-btn-text` обёртки `.news_buttons_main`

JS (`src/js/index.js`, блок «radario fix btn») находит `.radario-button` внутри
`.news_buttons_main`, добавляет классы `news__block-btn btn-primary` и подставляет текст + стрелку.

Места вывода: `single-events.php` (хедер + низ), `inc/components/events-grid.php` (карточка сетки).

## Git / коммиты

- НЕ добавлять trailers об авторстве модели.
- Submodule коммитим отдельно, затем обновляем указатель в `www/`.
