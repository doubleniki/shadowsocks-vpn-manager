#!/bin/sh

# Пути к файлам
CONFIG_DIR="/jffs/configs/shadowsocks"
SCRIPT_DIR="/jffs/scripts"
API_SCRIPT="$SCRIPT_DIR/shadowsocks_api.sh"
API_PID_FILE="/tmp/shadowsocks_api.pid"
LOG_FILE="$CONFIG_DIR/daemon.log"
MAX_LOG_SIZE=10485760  # 10MB в байтах

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

    echo -e "${color}[$level] $message${NC}"
}

# Функция для проверки размера лог-файла
check_log_size() {
    if [ -f "$LOG_FILE" ]; then
        local size=$(stat -f %z "$LOG_FILE" 2>/dev/null || stat -c %s "$LOG_FILE" 2>/dev/null)
        if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            rotate_log
        fi
    fi
}

# Функция для ротации лог-файла
rotate_log() {
    local timestamp=$(date "+%Y%m%d_%H%M%S")
    mv "$LOG_FILE" "$LOG_FILE.$timestamp"
    touch "$LOG_FILE"
    log "INFO" "Выполнена ротация лог-файла"
}

# Функция для проверки версии API скрипта
check_api_version() {
    if [ -f "$API_SCRIPT" ]; then
        local version=$($API_SCRIPT version 2>/dev/null)
        if [ -z "$version" ]; then
            log "WARNING" "Не удалось определить версию API скрипта"
            return 0
        fi
        log "INFO" "Версия API скрипта: $version"
    fi
    return 0
}

# Функция для проверки наличия директорий
check_directories() {
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
        log "INFO" "Создана директория конфигурации: $CONFIG_DIR"
    fi

    if [ ! -d "$SCRIPT_DIR" ]; then
        log "ERROR" "Директория скриптов не существует: $SCRIPT_DIR"
        return 1
    fi

    return 0
}

# Функция для проверки наличия API скрипта
check_api_script() {
    if [ ! -f "$API_SCRIPT" ]; then
        log "ERROR" "API скрипт не найден: $API_SCRIPT"
        return 1
    fi

    if [ ! -x "$API_SCRIPT" ]; then
        log "ERROR" "API скрипт не имеет прав на выполнение: $API_SCRIPT"
        return 1
    fi

    return 0
}

# Функция для очистки PID файла при выходе
cleanup() {
    if [ -f "$API_PID_FILE" ]; then
        log "INFO" "Очистка PID файла при выходе"
        rm -f "$API_PID_FILE"
    fi
    exit 0
}

# Обработка сигналов
trap cleanup SIGTERM SIGINT

# Включение/выключение автозапуска Shadowsocks
enable_autostart() {
    check_directories || return 1

    touch "$CONFIG_DIR/autostart"
    log "INFO" "Автозапуск Shadowsocks включен"
}

disable_autostart() {
    check_directories || return 1

    rm -f "$CONFIG_DIR/autostart"
    log "INFO" "Автозапуск Shadowsocks выключен"
}

# Включение/выключение веб-интерфейса
enable_webui() {
    check_directories || return 1
    check_api_script || return 1

    touch "$CONFIG_DIR/webui_enabled"
    log "INFO" "Веб-интерфейс Shadowsocks включен"
    start_webui
}

disable_webui() {
    check_directories || return 1

    rm -f "$CONFIG_DIR/webui_enabled"
    log "INFO" "Веб-интерфейс Shadowsocks выключен"
    stop_webui
}

# Запуск веб-интерфейса
start_webui() {
    check_directories || return 1
    check_api_script || return 1
    check_api_version || return 1

    # Проверяем, запущен ли уже сервер
    if [ -f "$API_PID_FILE" ]; then
        if kill -0 $(cat "$API_PID_FILE") 2>/dev/null; then
            log "INFO" "Веб-интерфейс уже запущен"
            return 0
        else
            log "WARNING" "Найден устаревший PID файл, удаляем"
            rm -f "$API_PID_FILE"
        fi
    fi

    # Запускаем сервер и сохраняем PID
    log "INFO" "Запуск веб-интерфейса"
    $API_SCRIPT start > /dev/null 2>&1 &
    local pid=$!
    echo $pid > "$API_PID_FILE"

    # Проверяем, что процесс запустился
    sleep 1
    if kill -0 $pid 2>/dev/null; then
        log "INFO" "Веб-интерфейс успешно запущен (PID: $pid)"
        return 0
    else
        log "ERROR" "Не удалось запустить веб-интерфейс"
        rm -f "$API_PID_FILE"
        return 1
    fi
}

# Остановка веб-интерфейса
stop_webui() {
    check_directories || return 1

    if [ -f "$API_PID_FILE" ]; then
        local pid=$(cat "$API_PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            log "INFO" "Остановка веб-интерфейса (PID: $pid)"
            kill $pid
            sleep 1
            if kill -0 $pid 2>/dev/null; then
                log "WARNING" "Процесс не завершился, принудительное завершение"
                kill -9 $pid
            fi
        fi
        rm -f "$API_PID_FILE"
        log "INFO" "Веб-интерфейс остановлен"
    else
        log "INFO" "Веб-интерфейс не запущен"
    fi
}

# Отображение справки
show_help() {
    echo "Использование: $0 {enable-autostart|disable-autostart|enable-webui|disable-webui|start-webui|stop-webui}"
    echo ""
    echo "  enable-autostart   - Включить автозапуск Shadowsocks при загрузке роутера"
    echo "  disable-autostart  - Выключить автозапуск Shadowsocks"
    echo "  enable-webui       - Включить веб-интерфейс и его автозапуск"
    echo "  disable-webui      - Выключить веб-интерфейс и его автозапуск"
    echo "  start-webui        - Запустить веб-интерфейс"
    echo "  stop-webui         - Остановить веб-интерфейс"
}

# Проверяем директории при запуске
check_directories || exit 1

# Обработка команд
case "$1" in
    enable-autostart)
        enable_autostart
        ;;
    disable-autostart)
        disable_autostart
        ;;
    enable-webui)
        enable_webui
        ;;
    disable-webui)
        disable_webui
        ;;
    start-webui)
        start_webui
        ;;
    stop-webui)
        stop_webui
        ;;
    *)
        show_help
        exit 1
        ;;
esac

exit 0
