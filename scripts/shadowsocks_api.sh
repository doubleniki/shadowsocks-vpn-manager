#!/bin/sh
# API для взаимодействия с веб-интерфейсом

# Пути к файлам и скрипты
SCRIPT_DIR="/jffs/scripts"
MAIN_SCRIPT="$SCRIPT_DIR/shadowsocks_manager.sh"
CONFIG_DIR="/jffs/configs/shadowsocks"
WEB_DIR="/jffs/www/shadowsocks"
LOG_FILE="$CONFIG_DIR/api.log"
PID_FILE="/tmp/shadowsocks_api.pid"
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

    # Проверяем размер лог-файла
    if [ -f "$LOG_FILE" ]; then
        local size=$(stat -f %z "$LOG_FILE" 2>/dev/null || stat -c %s "$LOG_FILE" 2>/dev/null)
        if [ "$size" -gt 0 ] 2>/dev/null; then
            if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
                local timestamp=$(date "+%Y%m%d_%H%M%S")
                mv "$LOG_FILE" "$LOG_FILE.$timestamp"
                touch "$LOG_FILE"
                log "INFO" "Выполнена ротация лог-файла"
            fi
        fi
    fi
}

# Функция для вывода ошибки
error_response() {
    local code=$1
    local message=$2
    echo "HTTP/1.1 $code"
    echo "Content-Type: application/json"
    echo "Access-Control-Allow-Origin: *"
    echo "Access-Control-Allow-Methods: GET, POST, OPTIONS"
    echo "Access-Control-Allow-Headers: Content-Type"
    echo ""
    echo "{\"error\":\"$message\"}"
    log "ERROR" "$message"
}

# Создаем необходимые директории
mkdir -p "$CONFIG_DIR" || {
    echo "Ошибка: Не удалось создать директорию $CONFIG_DIR"
    exit 1
}

mkdir -p "$WEB_DIR" || {
    echo "Ошибка: Не удалось создать директорию $WEB_DIR"
    exit 1
}

# Проверяем наличие основного скрипта
if [ ! -x "$MAIN_SCRIPT" ]; then
    log "ERROR" "Основной скрипт $MAIN_SCRIPT не найден или не имеет прав на выполнение"
    exit 1
fi

# Функция для вывода HTTP-заголовков
print_headers() {
    echo "HTTP/1.1 200 OK"
    echo "Content-Type: application/json"
    echo "Access-Control-Allow-Origin: *"
    echo "Access-Control-Allow-Methods: GET, POST, OPTIONS"
    echo "Access-Control-Allow-Headers: Content-Type"
    echo ""
}

# Функция для обработки OPTIONS запроса (CORS)
handle_options() {
    echo "HTTP/1.1 200 OK"
    echo "Access-Control-Allow-Origin: *"
    echo "Access-Control-Allow-Methods: GET, POST, OPTIONS"
    echo "Access-Control-Allow-Headers: Content-Type"
    echo "Content-Length: 0"
    echo ""
}

# Функция для безопасного извлечения значений из JSON
get_json_value() {
    local json=$1
    local key=$2
    echo "$json" | grep -o "\"$key\":\"[^\"]*\"" | sed "s/\"$key\":\"//g" | sed 's/"//g'
}

get_json_number() {
    local json=$1
    local key=$2
    echo "$json" | grep -o "\"$key\":[0-9]*" | sed "s/\"$key\"://g"
}

# Функция для безопасного экранирования JSON
escape_json() {
    echo "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g'
}

# Функция для обработки запросов API
handle_request() {
    local request_method=$1
    local request_uri=$2
    local data=$(cat)

    # Логируем запрос
    log "INFO" "Получен $request_method запрос: $request_uri"

    # Убираем query string из URI
    local endpoint=$(echo $request_uri | cut -d '?' -f1)

    # Если это OPTIONS запрос, обрабатываем его отдельно
    if [ "$request_method" = "OPTIONS" ]; then
        handle_options
        return
    fi

    # Выводим HTTP-заголовки
    print_headers

    # Обрабатываем запрос в зависимости от эндпоинта
    case "$endpoint" in
        "/api/status")
            # Получение статуса VPN
            local status=$($MAIN_SCRIPT status)
            if [ $? -ne 0 ]; then
                error_response "500" "Ошибка при получении статуса VPN"
                return
            fi
            echo "{\"status\":\"$(escape_json "$status")\"}"
            log "INFO" "Статус VPN: $status"
            ;;

        "/api/start")
            # Запуск VPN
            $MAIN_SCRIPT start > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                error_response "500" "Ошибка при запуске VPN"
                return
            fi
            echo "{\"result\":\"success\",\"message\":\"VPN запущен\"}"
            log "INFO" "VPN запущен"
            ;;

        "/api/stop")
            # Остановка VPN
            $MAIN_SCRIPT stop > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                error_response "500" "Ошибка при остановке VPN"
                return
            fi
            echo "{\"result\":\"success\",\"message\":\"VPN остановлен\"}"
            log "INFO" "VPN остановлен"
            ;;

        "/api/restart")
            # Перезапуск VPN
            $MAIN_SCRIPT restart > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                error_response "500" "Ошибка при перезапуске VPN"
                return
            fi
            echo "{\"result\":\"success\",\"message\":\"VPN перезапущен\"}"
            log "INFO" "VPN перезапущен"
            ;;

        "/api/config")
            if [ "$request_method" = "GET" ]; then
                # Получение текущей конфигурации
                if [ -f "$CONFIG_DIR/config.json" ]; then
                    cat "$CONFIG_DIR/config.json"
                    log "INFO" "Конфигурация получена"
                else
                    echo "{\"error\":\"Конфигурация не найдена\"}"
                    log "WARNING" "Конфигурация не найдена"
                fi
            elif [ "$request_method" = "POST" ]; then
                # Сохранение новой конфигурации
                local server=$(get_json_value "$data" "server")
                local server_port=$(get_json_number "$data" "server_port")
                local password=$(get_json_value "$data" "password")
                local method=$(get_json_value "$data" "method")
                local timeout=$(get_json_number "$data" "timeout")
                local local_port=$(get_json_number "$data" "local_port")

                # Проверяем обязательные поля
                if [ -z "$server" ] || [ -z "$server_port" ] || [ -z "$password" ] || [ -z "$method" ]; then
                    error_response "400" "Не все обязательные поля заполнены"
                    return
                fi

                # Устанавливаем значения по умолчанию
                if [ -z "$timeout" ]; then
                    timeout=300
                fi

                if [ -z "$local_port" ]; then
                    local_port=1080
                fi

                # Сохраняем конфигурацию
                $MAIN_SCRIPT save_config "$server" "$server_port" "$password" "$method" "$timeout" "$local_port" > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    error_response "500" "Ошибка при сохранении конфигурации"
                    return
                fi

                # Перезапускаем VPN для применения изменений
                local status=$($MAIN_SCRIPT status)
                if [ "$status" = "running" ]; then
                    $MAIN_SCRIPT restart > /dev/null 2>&1
                    if [ $? -ne 0 ]; then
                        error_response "500" "Ошибка при перезапуске VPN"
                        return
                    fi
                fi

                echo "{\"result\":\"success\",\"message\":\"Конфигурация сохранена\"}"
                log "INFO" "Конфигурация сохранена: сервер=$server, порт=$server_port, метод=$method"
            fi
            ;;

        "/api/route_mode")
            if [ "$request_method" = "GET" ]; then
                # Получение текущего режима маршрутизации
                if [ -f "$CONFIG_DIR/route_mode" ]; then
                    local mode=$(cat "$CONFIG_DIR/route_mode")
                    echo "{\"mode\":\"$mode\"}"
                    log "INFO" "Режим маршрутизации получен: $mode"
                else
                    echo "{\"mode\":\"all\"}"
                    log "INFO" "Режим маршрутизации по умолчанию: all"
                fi
            elif [ "$request_method" = "POST" ]; then
                # Сохранение нового режима маршрутизации
                local mode=$(get_json_value "$data" "mode")

                if [ -z "$mode" ]; then
                    error_response "400" "Режим маршрутизации не указан"
                    return
                fi

                # Проверяем допустимые значения режима
                case "$mode" in
                    "all"|"selected"|"bypass")
                        ;;
                    *)
                        error_response "400" "Недопустимый режим маршрутизации: $mode"
                        return
                        ;;
                esac

                $MAIN_SCRIPT save_route_mode "$mode" > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    error_response "500" "Ошибка при сохранении режима маршрутизации"
                    return
                fi

                # Перезапускаем VPN для применения изменений
                local status=$($MAIN_SCRIPT status)
                if [ "$status" = "running" ]; then
                    $MAIN_SCRIPT restart > /dev/null 2>&1
                    if [ $? -ne 0 ]; then
                        error_response "500" "Ошибка при перезапуске VPN"
                        return
                    fi
                fi

                echo "{\"result\":\"success\",\"message\":\"Режим маршрутизации сохранен\"}"
                log "INFO" "Режим маршрутизации сохранен: $mode"
            fi
            ;;

        "/api/routes")
            if [ "$request_method" = "GET" ]; then
                # Получение списка маршрутов
                if [ -f "$CONFIG_DIR/routes.json" ]; then
                    cat "$CONFIG_DIR/routes.json"
                    log "INFO" "Список маршрутов получен"
                else
                    echo "{\"vpn\":[],\"direct\":[]}"
                    log "INFO" "Список маршрутов пуст"
                fi
            elif [ "$request_method" = "POST" ]; then
                # Добавление нового маршрута
                local target=$(get_json_value "$data" "target")
                local type=$(get_json_value "$data" "type")

                if [ -z "$target" ] || [ -z "$type" ]; then
                    error_response "400" "Не все обязательные поля заполнены"
                    return
                fi

                # Проверяем допустимые значения типа
                case "$type" in
                    "vpn"|"direct")
                        ;;
                    *)
                        error_response "400" "Недопустимый тип маршрута: $type"
                        return
                        ;;
                esac

                $MAIN_SCRIPT add_route "$target" "$type" > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    error_response "500" "Ошибка при добавлении маршрута"
                    return
                fi

                # Перезапускаем VPN для применения изменений
                local status=$($MAIN_SCRIPT status)
                if [ "$status" = "running" ]; then
                    $MAIN_SCRIPT restart > /dev/null 2>&1
                    if [ $? -ne 0 ]; then
                        error_response "500" "Ошибка при перезапуске VPN"
                        return
                    fi
                fi

                echo "{\"result\":\"success\",\"message\":\"Маршрут добавлен\"}"
                log "INFO" "Добавлен маршрут: $target ($type)"
            fi
            ;;

        "/api/routes/delete")
            if [ "$request_method" = "POST" ]; then
                # Удаление маршрута
                local target=$(get_json_value "$data" "target")

                if [ -z "$target" ]; then
                    error_response "400" "Цель маршрута не указана"
                    return
                fi

                $MAIN_SCRIPT remove_route "$target" > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    error_response "500" "Ошибка при удалении маршрута"
                    return
                fi

                # Перезапускаем VPN для применения изменений
                local status=$($MAIN_SCRIPT status)
                if [ "$status" = "running" ]; then
                    $MAIN_SCRIPT restart > /dev/null 2>&1
                    if [ $? -ne 0 ]; then
                        error_response "500" "Ошибка при перезапуске VPN"
                        return
                    fi
                fi

                echo "{\"result\":\"success\",\"message\":\"Маршрут удален\"}"
                log "INFO" "Удален маршрут: $target"
            fi
            ;;

        "/api/devices")
            if [ "$request_method" = "GET" ]; then
                # Получение списка устройств
                if [ -f "$CONFIG_DIR/devices.json" ]; then
                    cat "$CONFIG_DIR/devices.json"
                    log "INFO" "Список устройств получен"
                else
                    echo "{\"vpn\":[],\"direct\":[],\"names\":{}}"
                    log "INFO" "Список устройств пуст"
                fi
            elif [ "$request_method" = "POST" ]; then
                # Добавление нового устройства
                local mac=$(get_json_value "$data" "mac")
                local name=$(get_json_value "$data" "name")
                local type=$(get_json_value "$data" "type")

                if [ -z "$mac" ] || [ -z "$name" ] || [ -z "$type" ]; then
                    error_response "400" "Не все обязательные поля заполнены"
                    return
                fi

                # Проверяем формат MAC-адреса
                if ! echo "$mac" | grep -qE "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"; then
                    error_response "400" "Неверный формат MAC-адреса: $mac"
                    return
                fi

                # Проверяем допустимые значения типа
                case "$type" in
                    "vpn"|"direct")
                        ;;
                    *)
                        error_response "400" "Недопустимый тип устройства: $type"
                        return
                        ;;
                esac

                $MAIN_SCRIPT add_device "$mac" "$name" "$type" > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    error_response "500" "Ошибка при добавлении устройства"
                    return
                fi

                # Перезапускаем VPN для применения изменений
                local status=$($MAIN_SCRIPT status)
                if [ "$status" = "running" ]; then
                    $MAIN_SCRIPT restart > /dev/null 2>&1
                    if [ $? -ne 0 ]; then
                        error_response "500" "Ошибка при перезапуске VPN"
                        return
                    fi
                fi

                echo "{\"result\":\"success\",\"message\":\"Устройство добавлено\"}"
                log "INFO" "Добавлено устройство: $name ($mac, $type)"
            fi
            ;;

        "/api/devices/delete")
            if [ "$request_method" = "POST" ]; then
                # Удаление устройства
                local mac=$(get_json_value "$data" "mac")

                if [ -z "$mac" ]; then
                    error_response "400" "MAC-адрес устройства не указан"
                    return
                fi

                # Проверяем формат MAC-адреса
                if ! echo "$mac" | grep -qE "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"; then
                    error_response "400" "Неверный формат MAC-адреса: $mac"
                    return
                fi

                $MAIN_SCRIPT remove_device "$mac" > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    error_response "500" "Ошибка при удалении устройства"
                    return
                fi

                # Перезапускаем VPN для применения изменений
                local status=$($MAIN_SCRIPT status)
                if [ "$status" = "running" ]; then
                    $MAIN_SCRIPT restart > /dev/null 2>&1
                    if [ $? -ne 0 ]; then
                        error_response "500" "Ошибка при перезапуске VPN"
                        return
                    fi
                fi

                echo "{\"result\":\"success\",\"message\":\"Устройство удалено\"}"
                log "INFO" "Удалено устройство: $mac"
            fi
            ;;

        "/api/logs")
            if [ "$request_method" = "GET" ]; then
                # Получение журнала
                local lines=$(echo $request_uri | grep -o 'lines=[0-9]*' | sed 's/lines=//g')

                if [ -z "$lines" ]; then
                    lines=100
                fi

                # Ограничиваем количество строк для безопасности
                if [ "$lines" -gt 1000 ]; then
                    lines=1000
                fi

                local logs=$($MAIN_SCRIPT get_logs $lines)
                if [ $? -ne 0 ]; then
                    error_response "500" "Ошибка при получении журнала"
                    return
                fi
                echo "{\"logs\":\"$(escape_json "$logs")\"}"
                log "INFO" "Журнал получен ($lines строк)"
            elif [ "$request_method" = "POST" ]; then
                # Очистка журнала
                local action=$(get_json_value "$data" "action")

                if [ "$action" = "clear" ]; then
                    $MAIN_SCRIPT clear_logs > /dev/null 2>&1
                    if [ $? -ne 0 ]; then
                        error_response "500" "Ошибка при очистке журнала"
                        return
                    fi
                    echo "{\"result\":\"success\",\"message\":\"Журнал очищен\"}"
                    log "INFO" "Журнал очищен"
                else
                    error_response "400" "Неизвестное действие: $action"
                fi
            fi
            ;;

        *)
            # Если запрос не соответствует ни одному API-эндпоинту, пытаемся обработать его как запрос статического файла
            local file_path="$WEB_DIR$(echo $request_uri | cut -d '?' -f1)"

            # Проверяем существование файла
            if [ -f "$file_path" ]; then
                # Определяем тип содержимого на основе расширения файла
                local content_type="text/plain"
                case "$file_path" in
                    *.html)
                        content_type="text/html"
                        ;;
                    *.css)
                        content_type="text/css"
                        ;;
                    *.js)
                        content_type="application/javascript"
                        ;;
                    *.json)
                        content_type="application/json"
                        ;;
                    *.png)
                        content_type="image/png"
                        ;;
                    *.jpg|*.jpeg)
                        content_type="image/jpeg"
                        ;;
                    *.gif)
                        content_type="image/gif"
                        ;;
                    *.svg)
                        content_type="image/svg+xml"
                        ;;
                esac

                # Выводим HTTP-заголовки для файла
                echo "HTTP/1.1 200 OK"
                echo "Content-Type: $content_type"
                echo ""

                # Выводим содержимое файла
                cat "$file_path"
                log "INFO" "Отправлен файл: $file_path"
            else
                # Файл не найден, возвращаем 404
                error_response "404" "Запрошенный ресурс не найден: $request_uri"
            fi
            ;;
    esac
}

# Главная функция для запуска HTTP-сервера
start_server() {
    local port=8080

    # Проверяем, запущен ли уже сервер
    if netstat -tln | grep -q ":$port "; then
        log "WARNING" "Сервер уже запущен на порту $port"
        echo "Сервер уже запущен на порту $port"
        return 1
    fi

    log "INFO" "Запуск HTTP-сервера на порту $port"
    echo "Запуск HTTP-сервера на порту $port..."

    # Сохраняем PID текущего процесса
    echo $$ > "$PID_FILE"

    # Проверяем, не блокируется ли порт файрволом
    log "INFO" "Проверка доступности порта $port"
    if ! nc -z localhost $port 2>/dev/null; then
        log "INFO" "Порт $port доступен"
    else
        log "WARNING" "Порт $port уже используется"
        echo "Порт $port уже используется"
        return 1
    fi

    # Запускаем HTTP-сервер на указанном порту
    while true; do
        # Проверяем версию netcat
        if nc -h 2>&1 | grep -q "listen mode"; then
            # Стандартная версия netcat (GNU)
            log "INFO" "Используется GNU netcat"
            nc -l -p $port -e "$0" handle_request
        elif nc -h 2>&1 | grep -q "OpenBSD"; then
            # OpenBSD версия netcat
            log "INFO" "Используется OpenBSD netcat"
            nc -l $port -e "$0" handle_request
        else
            # BusyBox версия netcat (не поддерживает -l)
            log "WARNING" "Используется BusyBox netcat, запуск через socat"

            # Проверяем наличие socat
            if command -v socat >/dev/null 2>&1; then
                log "INFO" "Запуск через socat"
                socat TCP-LISTEN:$port,fork EXEC:"$0 handle_request"
            else
                # Если socat не установлен, пробуем использовать встроенный HTTP-сервер
                log "WARNING" "socat не найден, используем встроенный HTTP-сервер"

                # Создаем временный файл для сокета
                local socket_file="/tmp/shadowsocks_api.sock"
                rm -f "$socket_file"

                # Запускаем встроенный HTTP-сервер
                log "INFO" "Запуск встроенного HTTP-сервера"
                (
                    while true; do
                        # Ожидаем подключения
                        (echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nAPI Server Running"; sleep 1) | nc -e "$0" handle_request $port
                        sleep 1
                    done
                ) &

                # Сохраняем PID фонового процесса
                echo $! > "$PID_FILE"

                # Ждем завершения фонового процесса
                wait
            fi
        fi

        # Проверяем, не был ли процесс убит
        if [ ! -f "$PID_FILE" ] || [ "$(cat "$PID_FILE")" != "$$" ]; then
            log "WARNING" "Процесс был перезапущен, завершаем текущий экземпляр"
            exit 0
        fi

        log "INFO" "Обработан запрос"
    done
}

# Функция для остановки сервера
stop_server() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            rm -f "$PID_FILE"
            log "INFO" "Сервер остановлен"
            echo "Сервер остановлен"
            return 0
        else
            rm -f "$PID_FILE"
            log "WARNING" "Процесс сервера не найден"
            echo "Процесс сервера не найден"
            return 1
        fi
    else
        log "WARNING" "PID-файл не найден"
        echo "PID-файл не найден"
        return 1
    fi
}

# Запускаем функцию в зависимости от аргументов командной строки
case "$1" in
    handle_request)
        # Эта функция вызывается через netcat при подключении к HTTP-серверу
        handle_request "$2" "$3"
        ;;
    start)
        # Запуск HTTP-сервера
        start_server
        ;;
    stop)
        # Остановка HTTP-сервера
        stop_server
        ;;
    restart)
        # Перезапуск HTTP-сервера
        stop_server
        sleep 1
        start_server
        ;;
    status)
        # Проверка статуса сервера
        if [ -f "$PID_FILE" ]; then
            local pid=$(cat "$PID_FILE")
            if kill -0 $pid 2>/dev/null; then
                echo "Сервер запущен (PID: $pid)"
                return 0
            else
                echo "Сервер не запущен (PID-файл существует, но процесс не найден)"
                return 1
            fi
        else
            echo "Сервер не запущен (PID-файл не найден)"
            return 1
        fi
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0
