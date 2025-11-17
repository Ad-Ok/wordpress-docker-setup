#!/bin/bash

# Скрипт деплоя исправлений плагинов на dev/prod сервер
# Дата: 17 ноября 2025
# Использование: ./deploy-plugin-fixes.sh dev|prod

set -e

ENV=${1:-dev}

echo "🔧 Деплой исправлений плагинов на $ENV..."

# 1. Проверка параметров
if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
    echo "❌ Ошибка: Укажите окружение: dev или prod"
    echo "Использование: $0 dev|prod"
    exit 1
fi

# 2. Загрузка конфигурации
source deployment-scripts/config.sh

if [ "$ENV" == "dev" ]; then
    SERVER=$DEV_SERVER
    DB_NAME=$DEV_DB_NAME
    DB_USER=$DEV_DB_USER
    DB_PASS=$DEV_DB_PASS
else
    SERVER=$PROD_SERVER
    DB_NAME=$PROD_DB_NAME
    DB_USER=$PROD_DB_USER
    DB_PASS=$PROD_DB_PASS
fi

echo "📡 Сервер: $SERVER"

# 3. Бэкап базы данных (на всякий случай)
echo "💾 Создание бэкапа базы данных..."
ssh $SERVER "mysqldump -u$DB_USER -p$DB_PASS $DB_NAME wp_maslovka_redirects > ~/backup_redirects_$(date +%Y%m%d_%H%M%S).sql"
echo "✅ Бэкап создан"

# 4. Загрузка обновлённых плагинов
echo "📤 Загрузка обновлённых файлов плагинов..."

# Транслитератор
rsync -avz --progress \
    wordpress/wp-content/plugins/maslovka-transliterator/maslovka-transliterator.php \
    $SERVER:~/domains/$DOMAIN/public_html/wp-content/plugins/maslovka-transliterator/

# Редиректы (главный файл + SQL скрипты)
rsync -avz --progress \
    wordpress/wp-content/plugins/maslovka-redirects/maslovka-redirects.php \
    wordpress/wp-content/plugins/maslovka-redirects/*.sql \
    $SERVER:~/domains/$DOMAIN/public_html/wp-content/plugins/maslovka-redirects/

echo "✅ Файлы загружены"

# 5. Очистка мусорных редиректов
echo "🧹 Очистка мусорных редиректов из базы..."
ssh $SERVER << EOF
mysql -u$DB_USER -p$DB_PASS $DB_NAME << SQL
DELETE FROM wp_maslovka_redirects 
WHERE source_url LIKE '%chernovik%' 
   OR source_url LIKE '%draft%'
   OR source_url LIKE '%25%'
   OR source_url LIKE '%\_\_trashed%'
   OR source_url LIKE '%nbsp%';

SELECT ROW_COUNT() as deleted_count;
SQL
EOF
echo "✅ Мусор удалён"

# 6. Пересоздание триггера
echo "🔄 Пересоздание MySQL триггера..."
ssh $SERVER << EOF
mysql -u$DB_USER -p$DB_PASS $DB_NAME < ~/domains/$DOMAIN/public_html/wp-content/plugins/maslovka-redirects/update-trigger.sql
EOF
echo "✅ Триггер обновлён"

# 7. Проверка триггера
echo "🔍 Проверка триггера..."
ssh $SERVER << EOF
mysql -u$DB_USER -p$DB_PASS $DB_NAME -e "SHOW TRIGGERS LIKE 'wp_posts';"
EOF

# 8. Проверка на наличие мусора
echo "🔍 Проверка на наличие мусорных редиректов..."
GARBAGE_COUNT=$(ssh $SERVER << EOF
mysql -u$DB_USER -p$DB_PASS $DB_NAME -sN -e "
SELECT COUNT(*) FROM wp_maslovka_redirects 
WHERE source_url LIKE '%chernovik%' 
   OR source_url LIKE '%25%'
   OR source_url LIKE '%nbsp%'
   OR source_url LIKE '%\_\_trashed%';
"
EOF
)

if [ "$GARBAGE_COUNT" -eq 0 ]; then
    echo "✅ База чистая, мусорных редиректов не найдено!"
else
    echo "⚠️  Найдено мусорных редиректов: $GARBAGE_COUNT"
    echo "Выполните ручную проверку!"
fi

# 9. Итоги
echo ""
echo "✅ Деплой исправлений завершён!"
echo ""
echo "📋 Что сделано:"
echo "  ✅ Обновлён плагин транслитерации"
echo "  ✅ Обновлён плагин редиректов"
echo "  ✅ Очищены мусорные редиректы"
echo "  ✅ Пересоздан MySQL триггер"
echo "  ✅ Создан бэкап базы"
echo ""
echo "🧪 Рекомендации по тестированию:"
echo "  1. Создать тестовое событие с кириллическим заголовком"
echo "  2. Сохранить как черновик, затем опубликовать"
echo "  3. Проверить slug - должен быть латиницей без 'chernovik'"
echo "  4. Изменить slug опубликованного события"
echo "  5. Проверить таблицу редиректов - не должно быть мусора"
echo ""
echo "📝 Подробности: /www/PLUGIN_FIX_REPORT_2025-11-17.md"
