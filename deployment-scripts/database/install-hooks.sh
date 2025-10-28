#!/bin/bash
# 🔧 Installer for Git Hooks
# Установка Git hooks для автоматического управления БД

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Получить директорию проекта
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GIT_HOOKS_DIR="${PROJECT_ROOT}/.git/hooks"
SOURCE_HOOKS_DIR="${PROJECT_ROOT}/www/deployment-scripts/database/git-hooks"

echo -e "${BLUE}🔧 Установка Git Hooks${NC}\n"

# Проверить, что мы в Git репозитории
if [ ! -d "${PROJECT_ROOT}/.git" ]; then
    echo -e "${RED}✗ Это не Git репозиторий${NC}"
    exit 1
fi

# Создать директорию hooks если не существует
mkdir -p "${GIT_HOOKS_DIR}"

# Установить post-checkout hook
echo -e "${CYAN}→ Установка post-checkout hook...${NC}"

if [ -f "${GIT_HOOKS_DIR}/post-checkout" ]; then
    echo -e "${YELLOW}   ⚠️  Файл уже существует. Создаю backup...${NC}"
    cp "${GIT_HOOKS_DIR}/post-checkout" "${GIT_HOOKS_DIR}/post-checkout.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Создать символическую ссылку
ln -sf "${SOURCE_HOOKS_DIR}/post-checkout" "${GIT_HOOKS_DIR}/post-checkout"
chmod +x "${GIT_HOOKS_DIR}/post-checkout"

echo -e "${GREEN}✓ Hook установлен${NC}"

# Информация
echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Git hooks успешно установлены!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Что это дает:${NC}"
echo -e "  • Автоматическое сохранение БД при переключении веток"
echo -e "  • Автоматическое восстановление БД для новой ветки"
echo -e "  • Изоляция БД между ветками\n"

echo -e "${CYAN}Как работает:${NC}"
echo -e "  1. git checkout feature/blog"
echo -e "     → Сохраняется БД текущей ветки"
echo -e "     → Восстанавливается БД для feature/blog"
echo -e "  2. Работаете над фичей"
echo -e "  3. git checkout main"
echo -e "     → Снова автоматическое переключение БД\n"

echo -e "${YELLOW}Управление:${NC}"
echo -e "  • Включить/выключить в config.sh:"
echo -e "    ${CYAN}SNAPSHOT_AUTO_SWITCH=\"true\"${NC} или ${CYAN}\"false\"${NC}"
echo -e "  • Вручную: ${CYAN}./db-snapshot.sh restore <snapshot>${NC}\n"

echo -e "${GREEN}Готово! Теперь БД будет автоматически переключаться при checkout.${NC}\n"
