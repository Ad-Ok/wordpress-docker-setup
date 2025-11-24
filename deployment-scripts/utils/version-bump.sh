#!/bin/bash
# Утилита для автоматического увеличения версии темы

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Путь к style.css темы относительно корня проекта
THEME_STYLE_CSS="${SCRIPT_DIR}/../wordpress/wp-content/themes/maslovka/style.css"

##
# Получить текущую версию из style.css
##
get_current_version() {
    if [ ! -f "$THEME_STYLE_CSS" ]; then
        echo "0.0.0"
        return 1
    fi
    
    # Извлекаем версию из строки "Version: X.Y.Z"
    local version=$(grep -E "^Version:" "$THEME_STYLE_CSS" | head -1 | sed 's/Version: *//' | tr -d '[:space:]')
    
    if [ -z "$version" ]; then
        echo "0.0.0"
        return 1
    fi
    
    echo "$version"
    return 0
}

##
# Увеличить patch версию (последнюю цифру)
##
bump_version() {
    local current_version=$(get_current_version)
    
    if [ -z "$current_version" ]; then
        echo -e "${YELLOW}⚠️  Cannot read current version from style.css${NC}"
        return 1
    fi
    
    # Разбиваем версию на компоненты
    IFS='.' read -r major minor patch <<< "$current_version"
    
    # Убираем возможные нечисловые символы
    major=$(echo "$major" | grep -o '[0-9]*')
    minor=$(echo "$minor" | grep -o '[0-9]*')
    patch=$(echo "$patch" | grep -o '[0-9]*')
    
    # Устанавливаем defaults если пусто
    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}
    
    # Увеличиваем patch версию
    patch=$((patch + 1))
    
    local new_version="${major}.${minor}.${patch}"
    
    echo -e "${BLUE}Updating theme version: ${current_version} → ${new_version}${NC}"
    
    # Обновляем версию в style.css
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^Version: .*/Version: ${new_version}/" "$THEME_STYLE_CSS"
    else
        # Linux
        sed -i "s/^Version: .*/Version: ${new_version}/" "$THEME_STYLE_CSS"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Version updated to ${new_version}${NC}"
        echo "$new_version"
        return 0
    else
        echo -e "${YELLOW}⚠️  Failed to update version${NC}"
        return 1
    fi
}

##
# Основная функция для вызова из других скриптов
##
version_bump() {
    echo -e "${BLUE}═══ Version Bump ═══${NC}"
    echo ""
    
    local new_version=$(bump_version)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    echo ""
    echo -e "${GREEN}✓ Version bump complete${NC}"
    echo -e "${BLUE}New version: ${new_version}${NC}"
    
    return 0
}
