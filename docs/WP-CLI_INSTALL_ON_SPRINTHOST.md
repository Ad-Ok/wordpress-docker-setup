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
mv wp-cli.phar ~/wp-cli.phar
```

### Добавьте алиас для удобства

**ВАЖНО**: На Sprinthost алиасы нужно добавлять в `~/.bash_profile`, а не в `~/.bashrc`

```bash
echo 'alias wp="/usr/local/bin/php ~/wp-cli.phar"' >> ~/.bash_profile
source ~/.bash_profile
```

### Альтернативный способ (если PHP в другом месте):

```bash
# Найдите путь к PHP
which php

# Добавьте алиас с полным путем
echo 'alias wp="/usr/local/bin/php ~/wp-cli.phar"' >> ~/.bash_profile
source ~/.bash_profile
```

---

## ✅ Шаг 4: Проверка установки

### Перейдите в директорию WordPress

```bash
cd domains/ваш_домен/public_html
```

*Замените `ваш_домен` на ваше доменное имя*

### Проверьте работу WP-CLI

```bash
# Используйте полный путь (самый надежный способ)
/usr/local/bin/php ~/wp-cli.phar --version

# Или перейдите в директорию WordPress и используйте полный путь
cd domains/ваш_домен/public_html
/usr/local/bin/php ~/wp-cli.phar core version
/usr/local/bin/php ~/wp-cli.phar plugin list
/usr/local/bin/php ~/wp-cli.phar db check
```

**Примечание**: На Sprinthost SSH сессии не всегда загружают `.bash_profile`, поэтому рекомендуется использовать полный путь к WP-CLI.

---

## 🚀 Установка WordPress с помощью WP-CLI

Если WordPress еще не установлен, вот как установить его с помощью WP-CLI:

### Шаг 1: Перейдите в директорию сайта

```bash
cd domains/ваш_домен/public_html
```

### Шаг 2: Скачайте WordPress

```bash
/usr/local/bin/php ~/wp-cli.phar core download --locale=ru_RU
```

### Шаг 3: Создайте конфигурационный файл

```bash
/usr/local/bin/php ~/wp-cli.phar config create --dbname=имя_базы --dbuser=пользователь_базы --dbpass=пароль_базы --dbhost=localhost
```

### Шаг 4: Установите WordPress

```bash
/usr/local/bin/php ~/wp-cli.phar core install --url=ваш_домен --title="Название сайта" --admin_user=admin --admin_password=пароль --admin_email=email@example.com
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