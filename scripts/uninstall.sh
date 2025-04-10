#!/bin/sh
# Скрипт для удаления Shadowsocks VPN Manager

# Определяем директории
SCRIPT_DIR="/jffs/scripts"
CONFIG_DIR="/jffs/configs/shadowsocks"
WEB_DIR="/jffs/www/shadowsocks"

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

# Проверяем, запущен ли VPN
if [ -f "/tmp/shadowsocks.pid" ]; then
    print_message "WARNING" "VPN все еще запущен. Останавливаем..."
    $SCRIPT_DIR/shadowsocks_manager.sh stop || error_exit "Не удалось остановить VPN"
fi

# Проверяем, запущен ли веб-интерфейс
if [ -f "/tmp/shadowsocks_api.pid" ]; then
    print_message "WARNING" "Веб-интерфейс все еще запущен. Останавливаем..."
    $SCRIPT_DIR/shadowsocks_api.sh stop || error_exit "Не удалось остановить веб-интерфейс"
fi

# Удаляем скрипты
print_message "INFO" "Удаление скриптов..."
rm -f $SCRIPT_DIR/shadowsocks_manager.sh || print_message "WARNING" "Не удалось удалить shadowsocks_manager.sh"
rm -f $SCRIPT_DIR/shadowsocks_api.sh || print_message "WARNING" "Не удалось удалить shadowsocks_api.sh"
rm -f $SCRIPT_DIR/post_mount.sh || print_message "WARNING" "Не удалось удалить post_mount.sh"
rm -f $SCRIPT_DIR/shadowsocks_daemon.sh || print_message "WARNING" "Не удалось удалить shadowsocks_daemon.sh"

# Удаляем конфигурационные файлы
print_message "INFO" "Удаление конфигурационных файлов..."
rm -f $CONFIG_DIR/config.json || print_message "WARNING" "Не удалось удалить config.json"
rm -f $CONFIG_DIR/routes.json || print_message "WARNING" "Не удалось удалить routes.json"
rm -f $CONFIG_DIR/devices.json || print_message "WARNING" "Не удалось удалить devices.json"
rm -f $CONFIG_DIR/shadowsocks.log || print_message "WARNING" "Не удалось удалить shadowsocks.log"
rm -f $CONFIG_DIR/autostart || print_message "WARNING" "Не удалось удалить autostart"
rm -f $CONFIG_DIR/webui_enabled || print_message "WARNING" "Не удалось удалить webui_enabled"

# Удаляем веб-интерфейс
print_message "INFO" "Удаление веб-интерфейса..."
rm -f $WEB_DIR/index.html || print_message "WARNING" "Не удалось удалить index.html"
rm -rf $WEB_DIR/css || print_message "WARNING" "Не удалось удалить директорию css"
rm -rf $WEB_DIR/js || print_message "WARNING" "Не удалось удалить директорию js"
rm -rf $WEB_DIR/img || print_message "WARNING" "Не удалось удалить директорию img"

# Удаляем временные файлы
print_message "INFO" "Удаление временных файлов..."
rm -f /tmp/shadowsocks.pid || print_message "WARNING" "Не удалось удалить shadowsocks.pid"
rm -f /tmp/shadowsocks_api.pid || print_message "WARNING" "Не удалось удалить shadowsocks_api.pid"

# Удаляем пустые директории
print_message "INFO" "Удаление пустых директорий..."
rmdir $CONFIG_DIR 2>/dev/null || print_message "WARNING" "Не удалось удалить директорию $CONFIG_DIR"
rmdir $WEB_DIR 2>/dev/null || print_message "WARNING" "Не удалось удалить директорию $WEB_DIR"

# Спрашиваем пользователя о удалении установленных пакетов
read -p "Удалить установленные пакеты (shadowsocks-libev, ipset, bash, nano, netcat)? (y/n): " remove_packages
if [ "$remove_packages" = "y" ] || [ "$remove_packages" = "Y" ]; then
    print_message "INFO" "Удаление пакетов..."
    opkg remove shadowsocks-libev-ss-local shadowsocks-libev-ss-redir || print_message "WARNING" "Не удалось удалить shadowsocks-libev"
    opkg remove ipset || print_message "WARNING" "Не удалось удалить ipset"
    opkg remove bash || print_message "WARNING" "Не удалось удалить bash"
    opkg remove nano || print_message "WARNING" "Не удалось удалить nano"
    opkg remove netcat || print_message "WARNING" "Не удалось удалить netcat"
fi

print_message "INFO" "Удаление Shadowsocks VPN Manager успешно завершено!"
print_message "INFO" "Пожалуйста, перезагрузите роутер для завершения процесса удаления."

exit 0
