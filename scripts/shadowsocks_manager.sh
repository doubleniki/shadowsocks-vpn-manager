#!/bin/sh
# Основной скрипт для управления Shadowsocks и маршрутизацией

# Пути к файлам конфигурации
CONFIG_DIR="/jffs/configs/shadowsocks"
CONFIG_FILE="$CONFIG_DIR/config.json"
ROUTES_FILE="$CONFIG_DIR/routes.json"
DEVICES_FILE="$CONFIG_DIR/devices.json"
LOG_FILE="$CONFIG_DIR/shadowsocks.log"
PID_FILE="/tmp/shadowsocks.pid"
MAX_LOG_SIZE=10485760  # 10MB в байтах
OPKG_TIMEOUT=60  # Таймаут для opkg в секундах
PROCESS_TIMEOUT=30  # Таймаут для процессов в секундах

# Проверяем наличие команды timeout
if ! command -v timeout >/dev/null 2>&1; then
    # Если timeout не найден, создаем функцию-заглушку
    timeout() {
        shift  # Удаляем первый аргумент (таймаут)
        "$@"   # Выполняем оставшиеся аргументы как команду
    }
fi

# Цветовые коды
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Создаем директории, если они не существуют
mkdir -p $CONFIG_DIR

# Функция для логирования
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
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
    echo "$timestamp [$level] $message" >> $LOG_FILE

    # Выводим в консоль с цветом
    echo -e "${color}$timestamp [$level] $message${NC}"

    # Проверяем размер лог-файла
    check_log_size
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

# Функция для проверки и создания директорий
check_directories() {
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR" || {
            log "ERROR" "Не удалось создать директорию $CONFIG_DIR"
            return 1
        }
        log "INFO" "Создана директория $CONFIG_DIR"
    fi
    return 0
}

# Проверка наличия необходимых пакетов
check_dependencies() {
    # Проверяем наличие shadowsocks-libev
    if [ ! -f /opt/bin/ss-redir ]; then
        log "INFO" "Shadowsocks-libev не установлен. Устанавливаем..."

        # Сначала обновляем репозитории
        log "INFO" "Обновление репозиториев пакетов..."
        timeout $OPKG_TIMEOUT opkg update || {
            log "ERROR" "Не удалось обновить репозитории пакетов"
            return 1
        }

        # Устанавливаем базовые зависимости
        log "INFO" "Установка базовых зависимостей..."
        for pkg in libuci libuci-lua libustream-openssl; do
            log "INFO" "Установка пакета $pkg..."
            timeout $OPKG_TIMEOUT opkg install $pkg || {
                log "WARNING" "Не удалось установить пакет $pkg, пробуем альтернативный репозиторий"
                # Пробуем установить из альтернативного репозитория
                timeout $OPKG_TIMEOUT opkg install --force-depends $pkg || {
                    log "ERROR" "Не удалось установить пакет $pkg даже с принудительной установкой"
                    return 1
                }
            }
        done

        # Теперь устанавливаем shadowsocks-libev
        log "INFO" "Установка shadowsocks-libev..."
        timeout $OPKG_TIMEOUT opkg install --force-depends shadowsocks-libev-ss-local shadowsocks-libev-ss-redir || {
            log "ERROR" "Таймаут при установке shadowsocks-libev"
            return 1
        }

        # Проверяем успешность установки
        if [ ! -f /opt/bin/ss-redir ]; then
            log "ERROR" "Не удалось установить shadowsocks-libev"
            return 1
        fi

        # Проверяем версию
        local version=$(ss-redir -v 2>&1 | grep -oP 'Shadowsocks-libev \K[0-9.]+')
        if [ -z "$version" ]; then
            log "WARNING" "Не удалось определить версию shadowsocks-libev"
        else
            log "INFO" "Установлена версия shadowsocks-libev: $version"
        fi
    fi

    # Проверяем наличие ipset
    if [ ! -f /sbin/ipset ]; then
        log "INFO" "Установка ipset..."
        # Пробуем установить ipset без таймаута, так как он может быть недоступен
        opkg install --force-depends ipset || {
            log "ERROR" "Не удалось установить ipset. Проверьте подключение к интернету и доступность репозиториев."
            return 1
        }

        # Проверяем, что ipset действительно установился
        if [ ! -f /sbin/ipset ]; then
            log "ERROR" "ipset не найден после установки. Попробуйте установить его вручную: opkg install ipset"
            return 1
        fi
    fi

    # Проверяем наличие iptables
    if [ ! -f /usr/sbin/iptables ]; then
        log "INFO" "Установка iptables..."
        timeout $OPKG_TIMEOUT opkg install --force-depends iptables || {
            log "ERROR" "Не удалось установить iptables"
            return 1
        }

        if [ ! -f /usr/sbin/iptables ]; then
            log "ERROR" "iptables не найден после установки"
            return 1
        fi
    fi

    log "INFO" "Все зависимости успешно установлены"
    return 0
}

# Проверка статуса Shadowsocks
check_status() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            # Проверяем, не зомби ли процесс
            local state=$(ps -o state= -p $pid 2>/dev/null)
            if [ "$state" = "Z" ]; then
                log "WARNING" "Обнаружен зомби-процесс, очищаем"
                rm -f "$PID_FILE"
                echo "stopped"
                return 1
            fi
            echo "running"
            return 0
        else
            echo "stopped"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        echo "stopped"
        return 1
    fi
}

# Запуск Shadowsocks
start_shadowsocks() {
    local status=$(check_status)

    if [ "$status" = "running" ]; then
        log "INFO" "Shadowsocks уже запущен"
        return 0
    fi

    # Проверяем зависимости
    check_dependencies || return 1

    # Проверяем наличие конфигурационного файла
    if [ ! -f "$CONFIG_FILE" ]; then
        log "ERROR" "Конфигурационный файл не найден: $CONFIG_FILE"
        return 1
    fi

    # Запускаем shadowsocks-redir
    log "INFO" "Запуск Shadowsocks..."

    # Получаем локальный порт из конфигурации
    local local_port=$(grep -o '"local_port":[^,}]*' "$CONFIG_FILE" | sed 's/"local_port"://g')
    if [ -z "$local_port" ]; then
        local_port=1080
    fi

    # Запускаем ss-redir
    ss-redir -c "$CONFIG_FILE" -f "$PID_FILE" &
    local pid=$!

    # Ждем запуска процесса
    if wait_for_process $pid $PROCESS_TIMEOUT; then
        log "INFO" "Shadowsocks успешно запущен (PID: $pid)"

        # Настраиваем правила маршрутизации
        setup_routing_rules $local_port || {
            log "ERROR" "Ошибка при настройке правил маршрутизации"
            stop_shadowsocks
            return 1
        }

        return 0
    else
        log "ERROR" "Таймаут при запуске Shadowsocks"
        rm -f "$PID_FILE"
        return 1
    fi
}

# Остановка Shadowsocks
stop_shadowsocks() {
    local status=$(check_status)

    if [ "$status" = "stopped" ]; then
        log "INFO" "Shadowsocks уже остановлен"
        return 0
    fi

    # Останавливаем процесс
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        log "INFO" "Остановка Shadowsocks (PID: $pid)..."

        # Отправляем SIGTERM
        kill $pid
        local count=0

        # Ждем завершения процесса
        while [ $count -lt $PROCESS_TIMEOUT ]; do
            if ! kill -0 $pid 2>/dev/null; then
                break
            fi
            sleep 1
            count=$((count + 1))
        done

        # Если процесс все еще работает, отправляем SIGKILL
        if kill -0 $pid 2>/dev/null; then
            log "WARNING" "Процесс не завершился, принудительное завершение"
            kill -9 $pid
        fi

        rm -f "$PID_FILE"

        # Удаляем правила маршрутизации
        cleanup_routing_rules

        log "INFO" "Shadowsocks остановлен"
        return 0
    else
        log "WARN" "PID-файл не найден, но служба может быть запущена"
        cleanup_routing_rules
        return 1
    fi
}

# Перезапуск Shadowsocks
restart_shadowsocks() {
    log "INFO" "Перезапуск Shadowsocks..."
    stop_shadowsocks
    sleep 1
    start_shadowsocks
    return $?
}

# Настройка правил маршрутизации
setup_routing_rules() {
    local local_port=$1
    local error=0

    # Очистка старых правил
    cleanup_routing_rules

    # Создаем цепочки SHADOWSOCKS
    iptables -t nat -N SHADOWSOCKS 2>/dev/null || {
        log "ERROR" "Не удалось создать цепочку SHADOWSOCKS"
        return 1
    }

    # Создаем наборы ipset
    for set in ss_bypass ss_direct ss_devices; do
        ipset create $set hash:net 2>/dev/null || {
            log "ERROR" "Не удалось создать набор $set"
            return 1
        }
    done

    # Добавляем локальные сети в bypass по умолчанию
    for network in 0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4; do
        ipset add ss_bypass $network || {
            log "ERROR" "Не удалось добавить сеть $network в ss_bypass"
            error=1
        }
    done

    if [ $error -eq 1 ]; then
        cleanup_routing_rules
        return 1
    fi

    # Загружаем пользовательские правила маршрутизации
    if [ -f "$ROUTES_FILE" ]; then
        log "INFO" "Загрузка правил маршрутизации из $ROUTES_FILE"

        # Добавляем VPN маршруты
        for route in $(grep -o '"vpn":\[[^]]*\]' $ROUTES_FILE | sed 's/"vpn":\[//g' | sed 's/\]//g' | sed 's/"//g' | sed 's/,/ /g'); do
            # Проверяем, является ли запись IP-адресом или доменом
            if echo "$route" | grep -q -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$'; then
                # Это IP или подсеть
                ipset add ss_direct $route
                log "INFO" "Добавлен IP маршрут через VPN: $route"
            else
                # Это домен, получаем IP-адреса
                for ip in $(nslookup "$route" | grep "Address:" | grep -v "#" | awk '{print $2}'); do
                    ipset add ss_direct $ip
                    log "INFO" "Добавлен IP $ip для домена $route через VPN"
                done
            fi
        done

        # Добавляем прямые маршруты
        for route in $(grep -o '"direct":\[[^]]*\]' $ROUTES_FILE | sed 's/"direct":\[//g' | sed 's/\]//g' | sed 's/"//g' | sed 's/,/ /g'); do
            # Проверяем, является ли запись IP-адресом или доменом
            if echo "$route" | grep -q -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$'; then
                # Это IP или подсеть
                ipset add ss_bypass $route
                log "INFO" "Добавлен IP маршрут напрямую: $route"
            else
                # Это домен, получаем IP-адреса
                for ip in $(nslookup "$route" | grep "Address:" | grep -v "#" | awk '{print $2}'); do
                    ipset add ss_bypass $ip
                    log "INFO" "Добавлен IP $ip для домена $route напрямую"
                done
            fi
        done
    fi

    # Загружаем правила для устройств
    if [ -f "$DEVICES_FILE" ]; then
        log "INFO" "Загрузка правил для устройств из $DEVICES_FILE"

        # Добавляем устройства VPN
        for mac in $(grep -o '"vpn":\[[^]]*\]' $DEVICES_FILE | sed 's/"vpn":\[//g' | sed 's/\]//g' | sed 's/"//g' | sed 's/,/ /g'); do
            ipset add ss_devices $mac
            log "INFO" "Добавлено устройство через VPN: $mac"
        done
    fi

    # Получаем режим маршрутизации
    local mode="all"
    if [ -f "$CONFIG_DIR/route_mode" ]; then
        mode=$(cat "$CONFIG_DIR/route_mode")
    fi

    log "INFO" "Режим маршрутизации: $mode"

    # Настраиваем правила iptables в зависимости от режима
    case "$mode" in
        all)
            # Весь трафик через VPN, кроме исключений
            iptables -t nat -A SHADOWSOCKS -p tcp -m set --match-set ss_bypass dst -j RETURN
            iptables -t nat -A SHADOWSOCKS -p tcp -m set --match-set ss_devices src -j RETURN
            iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-port $local_port
            ;;
        bypass)
            # Весь трафик напрямую, выбранные через VPN
            iptables -t nat -A SHADOWSOCKS -p tcp -m set --match-set ss_direct dst -j REDIRECT --to-port $local_port
            iptables -t nat -A SHADOWSOCKS -p tcp -m set --match-set ss_devices src -j REDIRECT --to-port $local_port
            ;;
        direct)
            # Весь трафик через VPN, выбранные напрямую
            iptables -t nat -A SHADOWSOCKS -p tcp -m set --match-set ss_bypass dst -j RETURN
            iptables -t nat -A SHADOWSOCKS -p tcp -m set ! --match-set ss_devices src -j RETURN
            iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-port $local_port
            ;;
    esac

    # Добавляем цепочку SHADOWSOCKS в PREROUTING для всех пакетов
    iptables -t nat -A PREROUTING -p tcp -j SHADOWSOCKS

    log "INFO" "Правила маршрутизации настроены"
    return 0
}

# Очистка правил маршрутизации
cleanup_routing_rules() {
    log "INFO" "Очистка правил маршрутизации..."

    # Удаляем iptables правила
    iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS 2>/dev/null
    iptables -t nat -F SHADOWSOCKS 2>/dev/null
    iptables -t nat -X SHADOWSOCKS 2>/dev/null

    # Удаляем ipset наборы
    ipset destroy ss_bypass 2>/dev/null
    ipset destroy ss_direct 2>/dev/null
    ipset destroy ss_devices 2>/dev/null

    log "INFO" "Правила маршрутизации удалены"
    return 0
}

# Сохранение конфигурации
save_config() {
    local server="$1"
    local server_port="$2"
    local password="$3"
    local method="$4"
    local timeout="$5"
    local local_port="$6"

    # Создаем директорию, если она не существует
    mkdir -p $CONFIG_DIR

    # Создаем конфигурационный файл в формате JSON
    cat > $CONFIG_FILE << EOF
{
    "server": "$server",
    "server_port": $server_port,
    "local_address": "0.0.0.0",
    "local_port": $local_port,
    "password": "$password",
    "timeout": $timeout,
    "method": "$method",
    "fast_open": false
}
EOF

    log "INFO" "Конфигурация сохранена в $CONFIG_FILE"
    return 0
}

# Сохранение режима маршрутизации
save_route_mode() {
    local mode="$1"

    # Проверка корректности режима
    if [ "$mode" != "all" ] && [ "$mode" != "bypass" ] && [ "$mode" != "direct" ]; then
        log "ERROR" "Некорректный режим маршрутизации: $mode"
        return 1
    fi

    # Сохраняем режим в файл
    echo "$mode" > "$CONFIG_DIR/route_mode"

    log "INFO" "Режим маршрутизации сохранен: $mode"
    return 0
}

# Добавление маршрута
add_route() {
    local target="$1"
    local type="$2"

    # Создаем файл маршрутов, если он не существует
    if [ ! -f "$ROUTES_FILE" ]; then
        echo '{"vpn":[],"direct":[]}' > "$ROUTES_FILE"
    fi

    # Проверяем, существует ли уже такой маршрут
    if grep -q "\"$target\"" "$ROUTES_FILE"; then
        log "WARN" "Маршрут уже существует: $target"
        return 1
    fi

    # Добавляем маршрут в соответствующий массив
    if [ "$type" = "vpn" ]; then
        # Добавляем в массив vpn
        sed -i 's/"vpn":\[/"vpn":\["'"$target"'",/g' "$ROUTES_FILE"
    else
        # Добавляем в массив direct
        sed -i 's/"direct":\[/"direct":\["'"$target"'",/g' "$ROUTES_FILE"
    fi

    # Исправляем JSON, если добавленная запись - первая в массиве
    sed -i 's/\[\"/\[/g; s/\",\]/\]/g; s/,,/,/g; s/,\]/\]/g' "$ROUTES_FILE"

    log "INFO" "Добавлен маршрут $target через $type"
    return 0
}

# Удаление маршрута
remove_route() {
    local target="$1"

    # Проверяем существование файла маршрутов
    if [ ! -f "$ROUTES_FILE" ]; then
        log "ERROR" "Файл маршрутов не существует"
        return 1
    fi

    # Удаляем маршрут из обоих массивов
    sed -i 's/"'"$target"'",//g; s/,"'"$target"'"//g; s/"'"$target"'"//g' "$ROUTES_FILE"

    # Исправляем JSON
    sed -i 's/\[\"/\[/g; s/\",\]/\]/g; s/,,/,/g; s/,\]/\]/g' "$ROUTES_FILE"

    log "INFO" "Удален маршрут: $target"
    return 0
}

# Добавление устройства
add_device() {
    local mac="$1"
    local name="$2"
    local type="$3"

    # Создаем файл устройств, если он не существует
    if [ ! -f "$DEVICES_FILE" ]; then
        echo '{"vpn":[],"direct":[],"names":{}}' > "$DEVICES_FILE"
    fi

    # Проверяем, существует ли уже такое устройство
    if grep -q "\"$mac\"" "$DEVICES_FILE"; then
        log "WARN" "Устройство уже существует: $mac"
        # Удаляем старую запись
        sed -i 's/"'"$mac"'",//g; s/,"'"$mac"'"//g; s/"'"$mac"'"//g' "$DEVICES_FILE"
    fi

    # Добавляем устройство в соответствующий массив
    if [ "$type" = "vpn" ]; then
        # Добавляем в массив vpn
        sed -i 's/"vpn":\[/"vpn":\["'"$mac"'",/g' "$DEVICES_FILE"
    else
        # Добавляем в массив direct
        sed -i 's/"direct":\[/"direct":\["'"$mac"'",/g' "$DEVICES_FILE"
    fi

    # Добавляем имя устройства
    sed -i 's/"names":{/"names":{"'"$mac"'":"'"$name"'",/g' "$DEVICES_FILE"

    # Исправляем JSON
    sed -i 's/\[\"/\[/g; s/\",\]/\]/g; s/,,/,/g; s/,\]/\]/g; s/,}/}/g' "$DEVICES_FILE"

    log "INFO" "Добавлено устройство $name ($mac) через $type"
    return 0
}

# Удаление устройства
remove_device() {
    local mac="$1"

    # Проверяем существование файла устройств
    if [ ! -f "$DEVICES_FILE" ]; then
        log "ERROR" "Файл устройств не существует"
        return 1
    fi

    # Удаляем устройство из обоих массивов
    sed -i 's/"'"$mac"'",//g; s/,"'"$mac"'"//g; s/"'"$mac"'"//g' "$DEVICES_FILE"

    # Удаляем имя устройства
    sed -i 's/"'"$mac"'":"[^"]*",//g; s/,"'"$mac"'":"[^"]*"//g; s/"'"$mac"'":"[^"]*"//g' "$DEVICES_FILE"

    # Исправляем JSON
    sed -i 's/\[\"/\[/g; s/\",\]/\]/g; s/,,/,/g; s/,\]/\]/g; s/,}/}/g' "$DEVICES_FILE"

    log "INFO" "Удалено устройство: $mac"
    return 0
}

# Получение журнала
get_logs() {
    local lines="$1"

    if [ -z "$lines" ]; then
        lines=100
    fi

    if [ -f "$LOG_FILE" ]; then
        tail -n $lines "$LOG_FILE"
    else
        echo "Файл журнала не найден"
    fi
}

# Очистка журнала
clear_logs() {
    if [ -f "$LOG_FILE" ]; then
        > "$LOG_FILE"
        log "INFO" "Журнал очищен"
    fi
    return 0
}

# Обработка команд
case "$1" in
    status)
        check_status
        ;;
    start)
        start_shadowsocks
        ;;
    stop)
        stop_shadowsocks
        ;;
    restart)
        restart_shadowsocks
        ;;
    save_config)
        save_config "$2" "$3" "$4" "$5" "$6" "$7"
        ;;
    save_route_mode)
        save_route_mode "$2"
        ;;
    add_route)
        add_route "$2" "$3"
        ;;
    remove_route)
        remove_route "$2"
        ;;
    add_device)
        add_device "$2" "$3" "$4"
        ;;
    remove_device)
        remove_device "$2"
        ;;
    get_logs)
        get_logs "$2"
        ;;
    clear_logs)
        clear_logs
        ;;
    *)
        echo "Использование: $0 {status|start|stop|restart|save_config|save_route_mode|add_route|remove_route|add_device|remove_device|get_logs|clear_logs}"
        exit 1
        ;;
esac

exit 0
