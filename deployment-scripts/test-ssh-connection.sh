#!/bin/bash
# 🔍 SSH Server Diagnostics
# Проверка соединения и состояния сервера

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SSH_USER="a1182962"
SSH_HOST="141.8.192.186"
SSH_PORT="22"

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           SSH SERVER DIAGNOSTICS - DEV                    ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# TEST 1: Базовая проверка доступности хоста
# ============================================
echo -e "${BLUE}═══ TEST 1/8: Host Reachability (ping) ═══${NC}"
echo "Testing: ${SSH_HOST}"
echo ""

if ping -c 4 -W 2000 "${SSH_HOST}" > /dev/null 2>&1; then
    PING_RESULT=$(ping -c 4 "${SSH_HOST}" | tail -1)
    echo -e "${GREEN}✓${NC} Host is reachable"
    echo "  ${PING_RESULT}"
else
    echo -e "${RED}✗${NC} Host is NOT reachable via ping"
fi
echo ""

# ============================================
# TEST 2: Проверка SSH порта
# ============================================
echo -e "${BLUE}═══ TEST 2/8: SSH Port Check ═══${NC}"
echo "Testing: ${SSH_HOST}:${SSH_PORT}"
echo ""

if nc -z -w 5 "${SSH_HOST}" "${SSH_PORT}" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} SSH port ${SSH_PORT} is OPEN"
else
    echo -e "${RED}✗${NC} SSH port ${SSH_PORT} is CLOSED or filtered"
fi
echo ""

# ============================================
# TEST 3: Множественные SSH подключения
# ============================================
echo -e "${BLUE}═══ TEST 3/8: Multiple SSH Connections Test ═══${NC}"
echo "Testing 10 consecutive SSH connections..."
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0
TOTAL_TIME=0

for i in {1..10}; do
    START=$(date +%s%N)
    
    if ssh -o BatchMode=yes -o ConnectTimeout=10 "${SSH_USER}@${SSH_HOST}" "echo 'test'" > /dev/null 2>&1; then
        END=$(date +%s%N)
        DURATION=$(( (END - START) / 1000000 ))
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        TOTAL_TIME=$((TOTAL_TIME + DURATION))
        echo -e "  ${GREEN}✓${NC} Connection ${i}/10: OK (${DURATION}ms)"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo -e "  ${RED}✗${NC} Connection ${i}/10: FAILED"
    fi
    
    sleep 0.5
done

echo ""
echo "Results:"
echo "  Success: ${SUCCESS_COUNT}/10"
echo "  Failed:  ${FAIL_COUNT}/10"
if [ ${SUCCESS_COUNT} -gt 0 ]; then
    AVG_TIME=$((TOTAL_TIME / SUCCESS_COUNT))
    echo "  Average connection time: ${AVG_TIME}ms"
fi
echo ""

# ============================================
# TEST 4: Проверка uptime и load average
# ============================================
echo -e "${BLUE}═══ TEST 4/8: Server Uptime & Load ═══${NC}"
echo ""

SERVER_INFO=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "${SSH_USER}@${SSH_HOST}" "uptime" 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Server uptime:"
    echo "  ${SERVER_INFO}"
    echo ""
    
    # Парсим load average
    LOAD=$(echo "${SERVER_INFO}" | grep -oE 'load average[s]?: [0-9.]+, [0-9.]+, [0-9.]+' || echo "")
    if [ -n "${LOAD}" ]; then
        echo "  Load: ${LOAD}"
        
        # Проверяем первое значение load average
        LOAD1=$(echo "${LOAD}" | grep -oE '[0-9.]+' | head -1)
        if (( $(echo "${LOAD1} > 5.0" | bc -l) )); then
            echo -e "  ${RED}⚠️  High load detected!${NC}"
        elif (( $(echo "${LOAD1} > 2.0" | bc -l) )); then
            echo -e "  ${YELLOW}⚠️  Moderate load${NC}"
        else
            echo -e "  ${GREEN}✓${NC} Load is normal"
        fi
    fi
else
    echo -e "${RED}✗${NC} Could not retrieve uptime"
    echo "  Error: ${SERVER_INFO}"
fi
echo ""

# ============================================
# TEST 5: Проверка свободной памяти
# ============================================
echo -e "${BLUE}═══ TEST 5/8: Memory Usage ═══${NC}"
echo ""

MEM_INFO=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "${SSH_USER}@${SSH_HOST}" "free -h" 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Memory status:"
    echo "${MEM_INFO}" | head -2 | while read line; do
        echo "  ${line}"
    done
else
    echo -e "${RED}✗${NC} Could not retrieve memory info"
fi
echo ""

# ============================================
# TEST 6: Проверка дискового пространства
# ============================================
echo -e "${BLUE}═══ TEST 6/8: Disk Space ═══${NC}"
echo ""

DISK_INFO=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "${SSH_USER}@${SSH_HOST}" "df -h /home" 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Disk space on /home:"
    echo "${DISK_INFO}" | while read line; do
        echo "  ${line}"
    done
    
    # Проверяем процент использования
    USAGE=$(echo "${DISK_INFO}" | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ -n "${USAGE}" ] && [ "${USAGE}" -gt 90 ]; then
        echo -e "  ${RED}⚠️  Disk usage is critically high (${USAGE}%)${NC}"
    elif [ -n "${USAGE}" ] && [ "${USAGE}" -gt 80 ]; then
        echo -e "  ${YELLOW}⚠️  Disk usage is high (${USAGE}%)${NC}"
    else
        echo -e "  ${GREEN}✓${NC} Disk space is sufficient"
    fi
else
    echo -e "${RED}✗${NC} Could not retrieve disk info"
fi
echo ""

# ============================================
# TEST 7: Проверка активных SSH соединений
# ============================================
echo -e "${BLUE}═══ TEST 7/8: Active SSH Connections ═══${NC}"
echo ""

SSH_CONNECTIONS=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "${SSH_USER}@${SSH_HOST}" "who | grep -c '${SSH_USER}'" 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Active SSH sessions for user ${SSH_USER}: ${SSH_CONNECTIONS}"
    
    # Показываем детали
    SSH_DETAILS=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "${SSH_USER}@${SSH_HOST}" "who | grep '${SSH_USER}'" 2>&1)
    echo ""
    echo "Details:"
    echo "${SSH_DETAILS}" | while read line; do
        echo "  ${line}"
    done
else
    echo -e "${YELLOW}⚠️${NC}  Could not retrieve SSH connection info"
fi
echo ""

# ============================================
# TEST 8: Проверка лимитов пользователя
# ============================================
echo -e "${BLUE}═══ TEST 8/8: User Limits & Resources ═══${NC}"
echo ""

LIMITS=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "${SSH_USER}@${SSH_HOST}" "ulimit -a" 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} User resource limits:"
    echo "${LIMITS}" | grep -E "(open files|max user processes|pending signals)" | while read line; do
        echo "  ${line}"
    done
else
    echo -e "${RED}✗${NC} Could not retrieve user limits"
fi
echo ""

# ============================================
# TEST 9: Проверка времени отклика при передаче данных
# ============================================
echo -e "${BLUE}═══ BONUS: Data Transfer Speed Test ═══${NC}"
echo ""

echo "Testing small file transfer speed..."

# Создаем тестовый файл 10MB
TEST_FILE=$(mktemp)
dd if=/dev/zero of="${TEST_FILE}" bs=1M count=10 2>/dev/null

START=$(date +%s)
if scp -o BatchMode=yes -o ConnectTimeout=10 "${TEST_FILE}" "${SSH_USER}@${SSH_HOST}:/tmp/test_upload.tmp" > /dev/null 2>&1; then
    END=$(date +%s)
    DURATION=$((END - START))
    
    if [ ${DURATION} -eq 0 ]; then
        DURATION=1
    fi
    
    SPEED=$((10 / DURATION))
    echo -e "${GREEN}✓${NC} 10MB file transferred in ${DURATION} seconds (~${SPEED} MB/s)"
    
    # Удаляем тестовый файл с сервера
    ssh -o BatchMode=yes "${SSH_USER}@${SSH_HOST}" "rm -f /tmp/test_upload.tmp" 2>/dev/null
else
    echo -e "${RED}✗${NC} File transfer failed"
fi

rm -f "${TEST_FILE}"
echo ""

# ============================================
# SUMMARY
# ============================================
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}SUMMARY${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ ${FAIL_COUNT} -eq 0 ]; then
    echo -e "${GREEN}✓${NC} All SSH connection tests passed"
    echo ""
    echo "Recommendations:"
    echo "  • Server appears to be stable"
    echo "  • You can proceed with file synchronization"
    echo "  • Consider using --bwlimit option for large transfers"
else
    echo -e "${YELLOW}⚠️${NC}  Some connection issues detected (${FAIL_COUNT}/10 failed)"
    echo ""
    echo "Possible causes:"
    echo "  • Server may be under heavy load"
    echo "  • Network instability"
    echo "  • SSH connection limits reached"
    echo "  • Firewall or rate limiting"
    echo ""
    echo "Recommendations:"
    echo "  • Wait a few minutes and try again"
    echo "  • Use --bwlimit option to limit bandwidth"
    echo "  • Consider splitting sync into smaller batches"
fi

echo ""
