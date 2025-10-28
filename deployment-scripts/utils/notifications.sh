#!/bin/bash
# 📱 Notifications для deployment скриптов

# Функция отправки в Telegram
send_telegram() {
    local message="$1"
    
    if [ "$TELEGRAM_ENABLED" != "true" ]; then
        return 0
    fi
    
    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        return 0
    fi
    
    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=HTML" \
        > /dev/null
}

# Функция отправки Email
send_email() {
    local message="$1"
    
    if [ "$EMAIL_ENABLED" != "true" ]; then
        return 0
    fi
    
    if [ -z "$EMAIL_TO" ]; then
        return 0
    fi
    
    echo "$message" | mail -s "your-domain.com Deployment" "$EMAIL_TO"
}

# Функция отправки в Slack
send_slack() {
    local message="$1"
    
    if [ "$SLACK_ENABLED" != "true" ]; then
        return 0
    fi
    
    if [ -z "$SLACK_WEBHOOK_URL" ]; then
        return 0
    fi
    
    curl -s -X POST \
        -H 'Content-type: application/json' \
        --data "{\"text\":\"${message}\"}" \
        "$SLACK_WEBHOOK_URL" \
        > /dev/null
}

# Главная функция отправки уведомлений
send_notification() {
    local message="$1"
    
    send_telegram "$message"
    send_email "$message"
    send_slack "$message"
}
