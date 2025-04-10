#!/bin/sh
# Установочный скрипт для Shadowsocks VPN Manager

# Подключаем общие функции
. "$(dirname "$0")/scripts/common.sh"

# Определяем директории
SCRIPT_DIR="/jffs/scripts"
CONFIG_DIR="/jffs/configs/shadowsocks"
WEB_DIR="/jffs/www/shadowsocks"
CURRENT_DIR="$(dirname "$(readlink -f "$0")")"

# Цветовые коды
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщения с цветом
print_message() {
    local level=$1
    shift
    local message="$*"
    local color=""

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

    echo -e "${color}$message${NC}"
}

# Функция для вывода ошибки и выхода
error_exit() {
    print_message "ERROR" "Ошибка: $1"
    exit 1
}

# Проверяем наличие необходимых компонентов
check_entware
check_jffs
check_system_libraries

# Создаем необходимые директории
create_directory "$CONFIG_DIR" "конфигурации"
create_directory "$WEB_DIR" "веб-интерфейса"

# Проверяем наличие необходимых файлов
[ -f "$CURRENT_DIR/scripts/uninstall.sh" ] || error_exit "Файл uninstall.sh не найден"
[ -f "$CURRENT_DIR/scripts/shadowsocks_manager.sh" ] || error_exit "Файл shadowsocks_manager.sh не найден"
[ -f "$CURRENT_DIR/scripts/shadowsocks_api.sh" ] || error_exit "Файл shadowsocks_api.sh не найден"
[ -f "$CURRENT_DIR/scripts/shadowsocks_daemon.sh" ] || error_exit "Файл shadowsocks_daemon.sh не найден"
[ -f "$CURRENT_DIR/scripts/post-mount.sh" ] || error_exit "Файл post-mount.sh не найден"

# Копируем скрипты
copy_file "$CURRENT_DIR/scripts/uninstall.sh" "$SCRIPT_DIR/" "uninstall.sh"
copy_file "$CURRENT_DIR/scripts/shadowsocks_manager.sh" "$SCRIPT_DIR/" "shadowsocks_manager.sh"
copy_file "$CURRENT_DIR/scripts/shadowsocks_api.sh" "$SCRIPT_DIR/" "shadowsocks_api.sh"
copy_file "$CURRENT_DIR/scripts/shadowsocks_daemon.sh" "$SCRIPT_DIR/" "shadowsocks_daemon.sh"
copy_file "$CURRENT_DIR/scripts/post-mount.sh" "$SCRIPT_DIR/" "post-mount.sh"

# Устанавливаем права на выполнение
set_executable "$SCRIPT_DIR/uninstall.sh" "uninstall.sh"
set_executable "$SCRIPT_DIR/shadowsocks_manager.sh" "shadowsocks_manager.sh"
set_executable "$SCRIPT_DIR/shadowsocks_api.sh" "shadowsocks_api.sh"
set_executable "$SCRIPT_DIR/shadowsocks_daemon.sh" "shadowsocks_daemon.sh"
set_executable "$SCRIPT_DIR/post-mount.sh" "post-mount.sh"

# Устанавливаем необходимые пакеты
install_package "shadowsocks-libev" "/opt/bin/ss-server" "shadowsocks-libev"
install_package "wget" "/opt/bin/wget" "wget"
install_package "curl" "/opt/bin/curl" "curl"
install_package "jq" "/opt/bin/jq" "jq"

# Создаем резервную копию конфигурации, если она существует
if [ -f "$CONFIG_DIR/config.json" ]; then
    cp "$CONFIG_DIR/config.json" "$CONFIG_DIR/config.json.bak" || print_message "WARNING" "Не удалось создать резервную копию конфигурации"
fi

# Копируем конфигурацию по умолчанию
copy_file "$CURRENT_DIR/config/config.json" "$CONFIG_DIR/" "config.json"

# Копируем файлы веб-интерфейса
copy_file "$CURRENT_DIR/www/index.html" "$WEB_DIR/" "index.html"
copy_file "$CURRENT_DIR/www/style.css" "$WEB_DIR/" "style.css"
copy_file "$CURRENT_DIR/www/script.js" "$WEB_DIR/" "script.js"

print_message "INFO" "Установка Shadowsocks VPN Manager завершена успешно"
print_message "INFO" "Для доступа к веб-интерфейсу откройте http://<IP-адрес_роутера>:8080/shadowsocks/"
print_message "INFO" "Для удаления Shadowsocks VPN Manager выполните скрипт uninstall.sh"
