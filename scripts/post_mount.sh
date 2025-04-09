#!/bin/sh

# Путь к файлам
CONFIG_DIR="/jffs/configs/shadowsocks"
SCRIPT_DIR="/jffs/scripts"
LOG_FILE="$CONFIG_DIR/post_mount.log"
MANAGER_SCRIPT="$SCRIPT_DIR/shadowsocks_manager.sh"
API_SCRIPT="$SCRIPT_DIR/shadowsocks_api.sh"

# Функция для логирования
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    echo "$message"
}

# Функция для проверки наличия скрипта
check_script() {
    local script=$1
    if [ ! -f "$script" ]; then
        log "ERROR" "Скрипт не найден: $script"
        return 1
    fi
    if [ ! -x "$script" ]; then
        log "ERROR" "Скрипт не имеет прав на выполнение: $script"
        return 1
    fi
    return 0
}

# Функция для проверки доступности сети
check_network() {
    local max_attempts=30
    local attempt=1
    local wait_time=2

    while [ $attempt -le $max_attempts ]; do
        if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            log "INFO" "Сеть доступна"
            return 0
        fi
        log "INFO" "Ожидание доступности сети (попытка $attempt из $max_attempts)"
        sleep $wait_time
        attempt=$((attempt + 1))
    done

    log "ERROR" "Сеть недоступна после $max_attempts попыток"
    return 1
}

# Создаем директорию для логов, если она не существует
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
fi

# Запускаем Shadowsocks, если он был включен
if [ -f "$CONFIG_DIR/autostart" ]; then
    log "INFO" "Обнаружен файл автозапуска Shadowsocks"

    if check_script "$MANAGER_SCRIPT"; then
        log "INFO" "Ожидание инициализации сети..."
        if check_network; then
            log "INFO" "Запуск Shadowsocks Manager"
            $MANAGER_SCRIPT start
            if [ $? -eq 0 ]; then
                log "INFO" "Shadowsocks Manager успешно запущен"
            else
                log "ERROR" "Ошибка при запуске Shadowsocks Manager"
            fi
        fi
    fi
fi

# Запускаем HTTP-сервер для управления Shadowsocks
if [ -f "$CONFIG_DIR/webui_enabled" ]; then
    log "INFO" "Обнаружен файл включения веб-интерфейса"

    if check_script "$API_SCRIPT"; then
        log "INFO" "Запуск HTTP-сервера"
        $API_SCRIPT start &
        if [ $? -eq 0 ]; then
            log "INFO" "HTTP-сервер успешно запущен"
        else
            log "ERROR" "Ошибка при запуске HTTP-сервера"
        fi
    fi
fi

exit 0
