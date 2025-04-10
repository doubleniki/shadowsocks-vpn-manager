#!/bin/sh

# Путь к файлам
CONFIG_DIR="/jffs/configs/shadowsocks"
SCRIPT_DIR="/jffs/scripts"
LOG_FILE="$CONFIG_DIR/post_mount.log"
MANAGER_SCRIPT="$SCRIPT_DIR/shadowsocks_manager.sh"
API_SCRIPT="$SCRIPT_DIR/shadowsocks_api.sh"

# Цветовые коды
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для логирования
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local color=""

    # Выбираем цвет в зависимости от уровня сообщения
    case "$level" in
        "ERROR")
            color=$RED
            ;;
        "WARNING")
            color=$YELLOW
            ;;
        "INFO")
            color=$GREEN
            ;;
        "DEBUG")
            color=$BLUE
            ;;
    esac

    # Записываем в лог-файл без цветов
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # Выводим в консоль с цветом
    echo -e "${color}[$timestamp] [$level] $message${NC}"
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

# Запускаем HTTP-сервер для управления Shadowsocks только если веб-интерфейс включен
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
else
    log "INFO" "Веб-интерфейс отключен"
fi

exit 0
