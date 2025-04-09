#!/bin/sh
# API для взаимодействия с веб-интерфейсом

# Пути к файлам и скрипты
SCRIPT_DIR="/jffs/scripts"
MAIN_SCRIPT="$SCRIPT_DIR/shadowsocks_manager.sh"
CONFIG_DIR="/jffs/configs/shadowsocks"
WEB_DIR="/jffs/www/shadowsocks"
LOG_FILE="$CONFIG_DIR/api.log"

# Функция для логирования
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
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
mkdir -p $CONFIG_DIR
mkdir -p $WEB_DIR

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
            echo "{\"status\":\"$status\"}"
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
                echo "{\"logs\":\"$(echo $logs | sed 's/"/\\"/g' | sed 's/\n/\\n/g')\"}"
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

    # Запускаем HTTP-сервер на указанном порту
    while true; do
        nc -l -p $port -e "$0" handle_request
        log "INFO" "Обработан запрос"
    done
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
    *)
        echo "Использование: $0 {start}"
        exit 1
        ;;
esac

exit 0
