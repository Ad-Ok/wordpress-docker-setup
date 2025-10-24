# 🚀 Установка WP-CLI на Sprinthost

## 📋 Предварительные требования

- SSH доступ к серверу ([инструкция по созданию SSH ключей](https://help.sprinthost.ru/file-transfer/ssh-and-sftp#ssh-keys))
- PHP 7.0+ установлен на сервере
- Доступ к командной строке

---

## 🔧 Шаг 1: Подключение по SSH

```bash
ssh ваш_логин@ip_сервера
```

*Замените `ваш_логин` на ваш реальный логин от Sprinthost*

---

## 📥 Шаг 2: Скачивание WP-CLI

```bash
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
```

---

## ⚙️ Шаг 3: Настройка WP-CLI

### Сделайте файл исполняемым и переместите в домашнюю директорию

```bash
chmod +x wp-cli.phar
mv wp-cli.phar /home/ваш_логин/wp-cli.phar
```

### Добавьте алиас для удобства

Отредактируйте файл `~/.bashrc`:

```bash
echo 'alias wp="php /home/ваш_логин/wp-cli.phar"' >> ~/.bashrc
source ~/.bashrc
```

---

## ✅ Шаг 4: Проверка установки

### Перейдите в директорию WordPress

```bash
cd public_html
```

### Проверьте работу WP-CLI

```bash
wp core version
wp plugin list
wp db check
```

---

## 🎯 Использование WP-CLI

### Основные команды

```bash
# Управление плагинами
wp plugin list
wp plugin install akismet
wp plugin activate akismet

# Управление темами
wp theme list
wp theme activate twentytwentyfour

# Работа с базой данных
wp db export backup.sql
wp db import backup.sql

# Управление пользователями
wp user list
wp user create newuser newuser@example.com --role=editor

# Очистка кеша
wp cache flush
wp super-cache flush
```

---

## 🔍 Диагностика проблем

### Если команда `wp` не найдена:

```bash
# Проверьте алиас
cat ~/.bashrc | grep wp

# Или используйте полный путь
php /home/ваш_логин/wp-cli.phar --version
```

### Если проблемы с правами:

```bash
# Проверьте права на wp-cli.phar
ls -la /home/ваш_логин/wp-cli.phar

# Исправьте права если нужно
chmod 755 /home/ваш_логин/wp-cli.phar
```

---

## 📚 Полезные ссылки

- [Официальная документация WP-CLI](https://wp-cli.org/)
- [Справочник команд WP-CLI](https://developer.wordpress.org/cli/commands/)
- [WP-CLI Handbook](https://make.wordpress.org/cli/handbook/)

---

## ⚠️ Важные замечания

- **Резервное копирование**: Всегда делайте бэкап перед изменениями через WP-CLI
- **Тестирование**: Сначала тестируйте команды на dev окружении
- **Права**: Убедитесь, что у вас есть права на изменение файлов WordPress
- **Версии**: Используйте актуальную версию WP-CLI

---

## 🎉 Готово!

Теперь вы можете использовать WP-CLI для автоматизации задач WordPress на вашем хостинге Sprinthost! 🚀