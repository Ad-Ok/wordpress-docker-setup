#!/bin/bash
# 🔒 Управление HTTP Basic Authentication для DEV окружения
# Использование: ./manage-htpasswd.sh [enable|disable|change|status]

set -e

# Загрузка конфигурации
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Параметры DEV окружения
SSH_USER="$DEV_SSH_USER"
SSH_HOST="$DEV_SSH_HOST"
WEBROOT="$DEV_WEBROOT"

ACTION="${1:-status}"

echo -e "${BLUE}═══ HTTP Authentication Manager (DEV) ═══${NC}"
echo ""

case "$ACTION" in
    enable)
        echo "Enabling HTTP authentication..."
        ssh "${SSH_USER}@${SSH_HOST}" << 'ENDSSH'
cd "${WEBROOT}"

# Восстанавливаем .htaccess если есть backup
if [ -f ".htaccess.noauth" ]; then
    mv .htaccess.noauth .htaccess
    echo "✓ Authentication enabled (from backup)"
else
    # Создаём заново
    if [ ! -f ".htpasswd" ]; then
        echo 'test:$apr1$ruca84Hq$dTCYlmXX7dkzByffVd4DT.' > .htpasswd
        chmod 644 .htpasswd
    fi
    
    cat > .htaccess << 'EOF'
# HTTP Basic Authentication for DEV environment
AuthType Basic
AuthName "Development Site - Restricted Access"
AuthUserFile ${WEBROOT}/.htpasswd
Require valid-user

# WordPress rules
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
EOF
    sed -i "s|\${WEBROOT}|${WEBROOT}|g" .htaccess
    echo "✓ Authentication enabled (created new)"
fi
ENDSSH
        echo -e "${GREEN}✓ HTTP authentication enabled${NC}"
        echo -e "  Username: ${YELLOW}test${NC}"
        echo -e "  Password: ${YELLOW}test${NC}"
        ;;
        
    disable)
        echo "Disabling HTTP authentication..."
        ssh "${SSH_USER}@${SSH_HOST}" << 'ENDSSH'
cd "${WEBROOT}"

# Создаём версию .htaccess без аутентификации
cat > .htaccess << 'EOF'
# WordPress rules (authentication disabled)
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
EOF

echo "✓ Authentication disabled"
ENDSSH
        echo -e "${YELLOW}⚠ HTTP authentication disabled${NC}"
        echo "  Site is now publicly accessible"
        ;;
        
    change)
        echo "Changing password..."
        echo ""
        read -p "Enter new username: " USERNAME
        read -sp "Enter new password: " PASSWORD
        echo ""
        
        # Генерируем хеш пароля локально
        HASH=$(openssl passwd -apr1 "$PASSWORD")
        
        ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
cd "${WEBROOT}"
echo '${USERNAME}:${HASH}' > .htpasswd
chmod 644 .htpasswd
echo "✓ Password changed"
ENDSSH
        echo -e "${GREEN}✓ Credentials updated${NC}"
        echo -e "  Username: ${YELLOW}${USERNAME}${NC}"
        echo -e "  Password: ${YELLOW}(hidden)${NC}"
        ;;
        
    status)
        echo "Checking authentication status..."
        STATUS=$(ssh "${SSH_USER}@${SSH_HOST}" << ENDSSH
cd "${WEBROOT}"

if [ ! -f ".htaccess" ]; then
    echo "NO_HTACCESS"
elif grep -q "AuthType Basic" .htaccess; then
    echo "ENABLED"
    if [ -f ".htpasswd" ]; then
        echo "USERS:"
        cut -d: -f1 .htpasswd
    fi
else
    echo "DISABLED"
fi
ENDSSH
)
        
        if [[ "$STATUS" == *"ENABLED"* ]]; then
            echo -e "${GREEN}✓ HTTP authentication is ENABLED${NC}"
            USERS=$(echo "$STATUS" | sed -n '/USERS:/,$p' | grep -v "USERS:")
            if [ -n "$USERS" ]; then
                echo ""
                echo "Authorized users:"
                echo "$USERS" | while read user; do
                    echo -e "  • ${YELLOW}${user}${NC}"
                done
            fi
        elif [[ "$STATUS" == "DISABLED" ]]; then
            echo -e "${YELLOW}⚠ HTTP authentication is DISABLED${NC}"
        elif [[ "$STATUS" == "NO_HTACCESS" ]]; then
            echo -e "${RED}✗ No .htaccess file found${NC}"
        fi
        ;;
        
    *)
        echo -e "${RED}Invalid action: $ACTION${NC}"
        echo ""
        echo "Usage: $0 [enable|disable|change|status]"
        echo ""
        echo "Actions:"
        echo "  enable  - Enable HTTP authentication (test/test)"
        echo "  disable - Disable HTTP authentication"
        echo "  change  - Change username/password"
        echo "  status  - Check current status"
        exit 1
        ;;
esac

echo ""
