#!/bin/sh
# Скрипт для проверки и исправления проблем с API-сервером

# Пути к файлам и скрипты
SCRIPT_DIR="/jffs/scripts"
API_SCRIPT="$SCRIPT_DIR/shadowsocks_api.sh"
CONFIG_DIR="/jffs/configs/shadowsocks"
LOG_FILE="$CONFIG_DIR/api_check.log"

# Функция для логирования
log() {
    local message="$*"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Создаем директорию для логов, если она не существует
mkdir -p "$CONFIG_DIR"

# Проверяем, запущен ли API-сервер
log "Проверка статуса API-сервера..."
if [ -x "$API_SCRIPT" ]; then
    # Проверяем статус сервера
    if $API_SCRIPT status > /dev/null 2>&1; then
        log "API-сервер запущен"
    else
        log "API-сервер не запущен, запускаем..."
        $API_SCRIPT start > /dev/null 2>&1 &
        sleep 2
    fi
else
    log "Ошибка: API-скрипт не найден или не имеет прав на выполнение"
    exit 1
fi

# Проверяем, слушает ли порт 8080
log "Проверка порта 8080..."
if netstat -tln | grep -q ":8080 "; then
    log "Порт 8080 прослушивается"
else
    log "Порт 8080 не прослушивается, перезапускаем сервер..."
    $API_SCRIPT stop > /dev/null 2>&1
    sleep 1
    $API_SCRIPT start > /dev/null 2>&1 &
    sleep 2
fi

# Проверяем, доступен ли сервер
log "Проверка доступности сервера..."
if nc -z localhost 8080 2>/dev/null; then
    log "Сервер доступен локально"
else
    log "Сервер недоступен локально, пробуем альтернативный метод..."

    # Пробуем использовать curl
    if command -v curl >/dev/null 2>&1; then
        if curl -s http://localhost:8080/api/status > /dev/null; then
            log "Сервер доступен через curl"
        else
            log "Сервер недоступен через curl"
        fi
    else
        log "curl не установлен, пропускаем проверку"
    fi
fi

# Проверяем файрвол
log "Проверка правил файрвола..."
if [ -f "/jffs/scripts/firewall-start" ]; then
    if grep -q "8080" "/jffs/scripts/firewall-start"; then
        log "Правило для порта 8080 найдено в файрволе"
    else
        log "Правило для порта 8080 не найдено в файрволе, добавляем..."
        echo "iptables -I INPUT -p tcp --dport 8080 -j ACCEPT" >> "/jffs/scripts/firewall-start"
        iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
        log "Правило добавлено"
    fi
else
    log "Файл firewall-start не найден, создаем..."
    echo "#!/bin/sh" > "/jffs/scripts/firewall-start"
    echo "iptables -I INPUT -p tcp --dport 8080 -j ACCEPT" >> "/jffs/scripts/firewall-start"
    chmod +x "/jffs/scripts/firewall-start"
    iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
    log "Файл firewall-start создан и правило добавлено"
fi

# Проверяем, доступен ли сервер извне
log "Проверка доступности сервера извне..."
local_ip=$(ip -o -4 addr show br0 | awk '{print $4}' | cut -d'/' -f1)
if [ -n "$local_ip" ]; then
    log "Локальный IP: $local_ip"
    if nc -z $local_ip 8080 2>/dev/null; then
        log "Сервер доступен извне по IP $local_ip"
    else
        log "Сервер недоступен извне по IP $local_ip"
    fi
else
    log "Не удалось определить локальный IP"
fi

log "Проверка завершена"
log "Веб-интерфейс должен быть доступен по адресу: http://$local_ip:8080"

exit 0
