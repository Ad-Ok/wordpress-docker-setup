#!/bin/bash
# 🧪 Polylang Integration Tests
# Тестирование настроек Polylang по фазам плана внедрения
# 
# Использование:
#   ./polylang-test.sh --env=local --phase=1
#   ./polylang-test.sh --env=dev --phase=3 --force-sql
#   ./polylang-test.sh --env=prod --phase=8
#   ./polylang-test.sh --env=local --only=4        # только фаза 4
#   ./polylang-test.sh --env=local --only=2,3,4    # только фазы 2, 3, 4
#
# Параметры:
#   --env=local|dev|prod    Окружение для тестирования (обязательный)
#   --phase=1-9             До какой фазы включительно тестировать (по умолчанию: 1)
#   --only=N или N,M,K      Запустить только указанные фазы
#   --force-sql             Пропустить WP-CLI и использовать только SQL
#   --help                  Показать справку

set -o pipefail

# ============================================
# Загрузка конфигурации
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Загрузка модулей тестов
TESTS_DIR="${SCRIPT_DIR}/polylang-tests"
source "${TESTS_DIR}/common.sh"
source "${TESTS_DIR}/phase-0.sh"
source "${TESTS_DIR}/phase-1.sh"
source "${TESTS_DIR}/phase-2.sh"
source "${TESTS_DIR}/phase-3.sh"
source "${TESTS_DIR}/phase-4-5.sh"
source "${TESTS_DIR}/phase-6.sh"
source "${TESTS_DIR}/phase-7.sh"
source "${TESTS_DIR}/phase-8.sh"
source "${TESTS_DIR}/phase-9.sh"

# ============================================
# Переменные
# ============================================
ENVIRONMENT=""
PHASE=1
ONLY_PHASES=""
FORCE_SQL=false
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
WP_CLI_AVAILABLE=false
SSH_AVAILABLE=false

# ============================================
# Парсинг аргументов
# ============================================
show_help() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         Polylang Integration Tests                        ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Использование:"
    echo "  ./polylang-test.sh --env=<environment> [--phase=<n>] [--only=<phases>] [--force-sql]"
    echo ""
    echo "Параметры:"
    echo "  --env=local|dev|prod    Окружение для тестирования (обязательный)"
    echo "  --phase=1-9             До какой фазы включительно тестировать (по умолчанию: 1)"
    echo "  --only=N или N,M,K      Запустить только указанные фазы (например: --only=4 или --only=2,3,4)"
    echo "  --force-sql             Пропустить WP-CLI и использовать только SQL"
    echo "  --help                  Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  ./polylang-test.sh --env=local --phase=1          # Фазы 0-1"
    echo "  ./polylang-test.sh --env=dev --phase=3 --force-sql # Фазы 0-3, только SQL"
    echo "  ./polylang-test.sh --env=local --only=4           # Только фаза 4"
    echo "  ./polylang-test.sh --env=local --only=1,2,4       # Только фазы 1, 2, 4"
    echo "  ./polylang-test.sh --env=prod --phase=8           # Фазы 0-8"
    echo ""
    echo "Фазы:"
    echo "  0 - Предварительные проверки (выполняется всегда)"
    echo "  1 - Установка и настройка Polylang"
    echo "  2 - SQL миграции (EN меню)"
    echo "  3 - Переводы темы"
    echo "  4 - Кастомные плагины"
    echo "  5 - Демо-контент"
    echo "  6 - SEO оптимизация"
    echo "  7 - Миграция на DEV"
    echo "  8 - Деплой на PROD"
    echo "  9 - Документация"
    exit 0
}

for arg in "$@"; do
    case $arg in
        --env=*)
            ENVIRONMENT="${arg#*=}"
            ;;
        --phase=*)
            PHASE="${arg#*=}"
            ;;
        --only=*)
            ONLY_PHASES="${arg#*=}"
            ;;
        --force-sql)
            FORCE_SQL=true
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Неизвестный параметр: $arg${NC}"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
done

# Проверка обязательных параметров
if [ -z "$ENVIRONMENT" ]; then
    echo -e "${RED}Ошибка: не указано окружение (--env=local|dev|prod)${NC}"
    echo "Используйте --help для справки"
    exit 1
fi

# Проверка допустимых значений
if [[ ! "$ENVIRONMENT" =~ ^(local|dev|prod)$ ]]; then
    echo -e "${RED}Ошибка: окружение должно быть local, dev или prod${NC}"
    exit 1
fi

# Валидация --phase (если не используется --only)
if [ -z "$ONLY_PHASES" ]; then
    if [[ ! "$PHASE" =~ ^[1-9]$ ]]; then
        echo -e "${RED}Ошибка: фаза должна быть от 1 до 9${NC}"
        exit 1
    fi
fi

# Валидация --only
if [ -n "$ONLY_PHASES" ]; then
    # Проверка формата: одиночная цифра или цифры через запятую
    if [[ ! "$ONLY_PHASES" =~ ^[0-9](,[0-9])*$ ]]; then
        echo -e "${RED}Ошибка: --only должен содержать номера фаз (0-9), разделённые запятыми${NC}"
        echo "Примеры: --only=4 или --only=1,2,4"
        exit 1
    fi
fi

# ============================================
# Настройка переменных окружения
# ============================================
setup_environment() {
    case "$ENVIRONMENT" in
        local)
            SITE_URL="$LOCAL_SITE_URL"
            DB_NAME="$LOCAL_DB_NAME"
            DB_USER="$LOCAL_DB_USER"
            DB_PASS="$LOCAL_DB_PASS"
            DB_HOST="$LOCAL_DB_HOST"
            DB_PORT="$LOCAL_DB_PORT"
            DB_CONTAINER="$LOCAL_DB_CONTAINER"
            WP_PATH="$LOCAL_WP_PATH"
            IS_LOCAL=true
            ;;
        dev)
            SITE_URL="$DEV_SITE_URL"
            DB_NAME="$DEV_DB_NAME"
            DB_USER="$DEV_DB_USER"
            DB_PASS="$DEV_DB_PASS"
            DB_HOST="$DEV_DB_HOST"
            SSH_USER="$DEV_SSH_USER"
            SSH_HOST="$DEV_SSH_HOST"
            SSH_PORT="$DEV_SSH_PORT"
            WP_PATH="$DEV_WP_PATH"
            IS_LOCAL=false
            ;;
        prod)
            SITE_URL="$PROD_SITE_URL"
            DB_NAME="$PROD_DB_NAME"
            DB_USER="$PROD_DB_USER"
            DB_PASS="$PROD_DB_PASS"
            DB_HOST="$PROD_DB_HOST"
            SSH_USER="$PROD_SSH_USER"
            SSH_HOST="$PROD_SSH_HOST"
            SSH_PORT="$PROD_SSH_PORT"
            WP_PATH="$PROD_WP_PATH"
            IS_LOCAL=false
            ;;
    esac
}

# ============================================
# Проверка нужно ли запускать фазу
# ============================================
should_run_phase() {
    local phase_num="$1"
    
    # Если используется --only, проверяем список
    if [ -n "$ONLY_PHASES" ]; then
        # Проверяем есть ли номер фазы в списке
        if echo "$ONLY_PHASES" | grep -qE "(^|,)${phase_num}(,|$)"; then
            return 0  # true - запустить
        else
            return 1  # false - пропустить
        fi
    fi
    
    # Иначе используем --phase для диапазона 1..N
    if [ "$phase_num" -le "$PHASE" ]; then
        return 0
    else
        return 1
    fi
}

# ============================================
# Вывод результатов
# ============================================
print_summary() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Окружение: ${BLUE}$ENVIRONMENT${NC}"
    
    if [ -n "$ONLY_PHASES" ]; then
        echo -e "  Фазы: ${BLUE}только $ONLY_PHASES${NC}"
    else
        echo -e "  Фазы: ${BLUE}0-$PHASE${NC}"
    fi
    
    echo -e "  Режим: ${BLUE}$([ "$WP_CLI_AVAILABLE" = true ] && echo 'WP-CLI + SQL' || echo 'Только SQL')${NC}"
    echo ""
    echo -e "  ${GREEN}Пройдено:${NC}  $PASSED_TESTS"
    echo -e "  ${RED}Провалено:${NC} $FAILED_TESTS"
    echo -e "  ${YELLOW}Пропущено:${NC} $SKIPPED_TESTS"
    echo ""
    
    TOTAL=$((PASSED_TESTS + FAILED_TESTS))
    
    if [ $FAILED_TESTS -eq 0 ] && [ $TOTAL -gt 0 ]; then
        echo -e "  ${GREEN}═══ ВСЕ ТЕСТЫ ПРОЙДЕНЫ ═══${NC}"
    elif [ $FAILED_TESTS -gt 0 ]; then
        echo -e "  ${RED}═══ ЕСТЬ ПРОВАЛЫ ($FAILED_TESTS) ═══${NC}"
    fi
    echo ""
}

# ============================================
# Главная функция
# ============================================
main() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         🧪 Polylang Integration Tests                     ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Окружение: ${BLUE}$ENVIRONMENT${NC}"
    
    if [ -n "$ONLY_PHASES" ]; then
        echo -e "  Режим: ${BLUE}только фазы $ONLY_PHASES${NC}"
    else
        echo -e "  Тестирование до фазы: ${BLUE}$PHASE${NC}"
    fi
    
    echo -e "  Force SQL: ${BLUE}$FORCE_SQL${NC}"
    
    # Настройка переменных окружения
    setup_environment
    
    # Фаза 0: Предварительные проверки (выполняется всегда)
    if ! phase_0_checks; then
        echo -e "${RED}Предварительные проверки не пройдены. Тестирование прервано.${NC}"
        print_summary
        exit 1
    fi
    
    # Запуск тестов по фазам
    should_run_phase 1 && phase_1_tests
    should_run_phase 2 && phase_2_tests
    should_run_phase 3 && phase_3_tests
    should_run_phase 4 && phase_4_5_tests
    should_run_phase 5 && phase_4_5_tests
    should_run_phase 6 && phase_6_tests
    should_run_phase 7 && phase_7_tests
    should_run_phase 8 && phase_8_tests
    should_run_phase 9 && phase_9_tests
    
    # Вывод результатов
    print_summary
    
    # Exit code
    if [ $FAILED_TESTS -gt 0 ]; then
        exit 1
    fi
    exit 0
}

# Запуск
main
