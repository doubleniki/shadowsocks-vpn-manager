#!/bin/sh
# API для взаимодействия с веб-интерфейсом

# Пути к файлам и скриптам
SCRIPT_DIR="/jffs/scripts"
MAIN_SCRIPT="$SCRIPT_DIR/shadowsocks_manager.sh"
CONFIG_DIR="/jffs/configs/shadowsocks"
WEB_DIR="/jffs/www/shadowsocks"

# Создаем необходимые директории
mkdir -p $CONFIG_DIR
mkdir -p $WEB_DIR

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

# Функция для обработки запросов API
handle_request() {
    local request_method=$1
    local request_uri=$2
    local data=$(cat)

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
            echo "{\"status\":\"$status\"}"
            ;;

        "/api/start")
            # Запуск VPN
            $MAIN_SCRIPT start > /dev/null 2>&1
            echo "{\"result\":\"success\",\"message\":\"VPN запущен\"}"
            ;;

        "/api/stop")
            # Остановка VPN
            $MAIN_SCRIPT stop > /dev/null 2>&1
            echo "{\"result\":\"success\",\"message\":\"VPN остановлен\"}"
            ;;

        "/api/restart")
            # Перезапуск VPN
            $MAIN_SCRIPT restart > /dev/null 2>&1
            echo "{\"result\":\"success\",\"message\":\"VPN перезапущен\"}"
            ;;

        "/api/config")
            if [ "$request_method" = "GET" ]; then
                # Получение текущей конфигурации
                if [ -f "$CONFIG_DIR/config.json" ]; then
                    cat "$CONFIG_DIR/config.json"
                else
                    echo "{\"error\":\"Конфигурация не найдена\"}"
                fi
            elif [ "$request_method" = "POST" ]; then
                # Сохранение новой конфигурации
                local server=$(echo $data | grep -o '"server":"[^"]*"' | sed 's/"server":"//g' | sed 's/"//g')
                local server_port=$(echo $data | grep -o '"server_port":[0-9]*' | sed 's/"server_port"://g')
                local password=$(echo $data | grep -o '"password":"[^"]*"' | sed 's/"password":"//g' | sed 's/"//g')
                local method=$(echo $data | grep -o '"method":"[^"]*"' | sed 's/"method":"//g' | sed 's/"//g')
                local timeout=$(echo $data | grep -o '"timeout":[0-9]*' | sed 's/"timeout"://g')
                local local_port=$(echo $data | grep -o '"local_port":[0-9]*' | sed 's/"local_port"://g')

                if [ -z "$server" ] || [ -z "$server_port" ] || [ -z "$password" ] || [ -z "$method" ]; then
                    echo "{\"error\":\"Не все обязательные поля заполнены\"}"
                    return
                fi

                if [ -z "$timeout" ]; then
                    timeout=300
                fi

                if [ -z "$local_port" ]; then
                    local_port=1080
                fi

                $MAIN_SCRIPT save_config "$server" "$server_port" "$password" "$method" "$timeout" "$local_port" > /dev/null 2>&1

                # Перезапускаем VPN для применения изменений
                local status=$($MAIN_SCRIPT status)
                if [ "$status" = "running" ]; then
                    $MAIN_SCRIPT restart > /dev/null 2>&1
                fi

                echo "{\"result\":\"success\",\"message\":\"Конфигурация сохранена\"}"
            fi
            ;;

        "/api/route_mode")
            if [ "$request_method" = "GET" ]; then
                # Получение текущего режима маршрутизации
                if [ -f "$CONFIG_DIR/route_mode" ]; then
                    local mode=$(cat "$CONFIG_DIR/route_mode")
                    echo "{\"mode\":\"$mode\"}"
                else
                    echo "{\"mode\":\"all\"}"
                fi
            elif [ "$request_method" = "POST" ]; then
                # Сохранение нового режима маршрутизации
                local mode=$(echo $data | grep -o '"mode":"[^"]*"' | sed 's/"mode":"//g' | sed 's/"//g')

                if [ -z "$mode" ]; then
                    echo "{\"error\":\"Режим маршрутизации не указан\"}"
                    return
                fi

                $MAIN_SCRIPT save_route_mode "$mode" > /dev/null 2>&1

                # Перезапускаем VPN для применения изменений
                local status=$($MAIN_SCRIPT status)
                if [ "$status" = "running" ]; then
                    $MAIN_SCRIPT restart > /dev/null 2>&1
                fi

                echo "{\"result\":\"success\",\"message\":\"Режим маршрутизации сохранен\"}"
            fi
            ;;

        "/api/routes")
            if [ "$request_method" = "GET" ]; then
                # Получение списка маршрутов
                if [ -f "$CONFIG_DIR/routes.json" ]; then
                    cat "$CONFIG_DIR/routes.json"
                else
                    echo "{\"vpn\":[],\"direct\":[]}"
                fi
            elif [ "$request_method" = "POST" ]; then
                # Добавление нового маршрута
                local target=$(echo $data | grep -o '"target":"[^"]*"' | sed 's/"target":"//g' | sed 's/"//g')
                local type=$(echo $data | grep -o '"type":"[^"]*"' | sed 's/"type":"//g' | sed 's/"//g')

                if [ -z "$target" ] || [ -z "$type" ]; then
                    echo "{\"error\":\"Не все обязательные поля заполнены\"}"
                    return
                fi

                $MAIN_SCRIPT add_route "$target" "$type" > /dev/null 2>&1

                # Перезапускаем VPN для применения изменений
                local status=$($MAIN_SCRIPT status)
                if [ "$status" = "running" ]; then
                    $MAIN_SCRIPT restart > /dev/null 2>&1
                fi

                echo "{\"result\":\"success\",\"message\":\"Маршрут добавлен\"}"
            fi
            ;;

        "/api/routes/delete")
            if [ "$request_method" = "POST" ]; then
                # Удаление маршрута
                local target=$(echo $data | grep -o '"target":"[^"]*"' | sed 's/"target":"//g' | sed 's/"//g')

                if [ -z "$target" ]; then
                    echo "{\"error\":\"Цель маршрута не указана\"}"
                    return
                fi

                $MAIN_SCRIPT remove_route "$target" > /dev/null 2>&1

                # Перезапускаем VPN для применения изменений
                local status=$($MAIN_SCRIPT status)
                if [ "$status" = "running" ]; then
                    $MAIN_SCRIPT restart > /dev/null 2>&1
                fi

                echo "{\"result\":\"success\",\"message\":\"Маршрут удален\"}"
            fi
            ;;

        "/api/devices")
            if [ "$request_method" = "GET" ]; then
                # Получение списка устройств
                if [ -f "$CONFIG_DIR/devices.json" ]; then
                    cat "$CONFIG_DIR/devices.json"
                else
                    echo "{\"vpn\":[],\"direct\":[],\"names\":{}}"
                fi
            elif [ "$request_method" = "POST" ]; then
                # Добавление нового устройства
                local mac=$(echo $data | grep -o '"mac":"[^"]*"' | sed 's/"mac":"//g' | sed 's/"//g')
                local name=$(echo $data | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g')
                local type=$(echo $data | grep -o '"type":"[^"]*"' | sed 's/"type":"//g' | sed 's/"//g')

                if [ -z "$mac" ] || [ -z "$name" ] || [ -z "$type" ]; then
                    echo "{\"error\":\"Не все обязательные поля заполнены\"}"
                    return
                fi

                $MAIN_SCRIPT add_device "$mac" "$name" "$type" > /dev/null 2>&1

                # Перезапускаем VPN для применения изменений
                local status=$($MAIN_SCRIPT status)
                if [ "$status" = "running" ]; then
                    $MAIN_SCRIPT restart > /dev/null 2>&1
                fi

                echo "{\"result\":\"success\",\"message\":\"Устройство добавлено\"}"
            fi
            ;;

        "/api/devices/delete")
            if [ "$request_method" = "POST" ]; then
                # Удаление устройства
                local mac=$(echo $data | grep -o '"mac":"[^"]*"' | sed 's/"mac":"//g' | sed 's/"//g')

                if [ -z "$mac" ]; then
                    echo "{\"error\":\"MAC-адрес устройства не указан\"}"
                    return
                fi

                $MAIN_SCRIPT remove_device "$mac" > /dev/null 2>&1

                # Перезапускаем VPN для применения изменений
                local status=$($MAIN_SCRIPT status)
                if [ "$status" = "running" ]; then
                    $MAIN_SCRIPT restart > /dev/null 2>&1
                fi

                echo "{\"result\":\"success\",\"message\":\"Устройство удалено\"}"
            fi
            ;;

        "/api/logs")
            if [ "$request_method" = "GET" ]; then
                # Получение журнала
                local lines=$(echo $request_uri | grep -o 'lines=[0-9]*' | sed 's/lines=//g')

                if [ -z "$lines" ]; then
                    lines=100
                fi

                local logs=$($MAIN_SCRIPT get_logs $lines)
                echo "{\"logs\":\"$(echo $logs | sed 's/"/\\"/g' | sed 's/\n/\\n/g')\"}"
            elif [ "$request_method" = "POST" ]; then
                # Очистка журнала
                local action=$(echo $data | grep -o '"action":"[^"]*"' | sed 's/"action":"//g' | sed 's/"//g')

                if [ "$action" = "clear" ]; then
                    $MAIN_SCRIPT clear_logs > /dev/null 2>&1
                    echo "{\"result\":\"success\",\"message\":\"Журнал очищен\"}"
                else
                    echo "{\"error\":\"Неизвестное действие\"}"
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
            else
                # Файл не найден, возвращаем 404
                echo "HTTP/1.1 404 Not Found"
                echo "Content-Type: application/json"
                echo ""
                echo "{\"error\":\"Not Found\",\"message\":\"Запрошенный ресурс не найден\",\"path\":\"$request_uri\"}"
            fi
            ;;
    esac
}

# Главная функция для запуска HTTP-сервера
start_server() {
    local port=8080

    # Проверяем, запущен ли уже сервер
    if netstat -tln | grep -q ":$port "; then
        echo "Сервер уже запущен на порту $port"
        return 1
    fi

    # Запускаем HTTP-сервер на указанном порту
    while true; do
        nc -l -p $port -e "$0" handle_request
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
