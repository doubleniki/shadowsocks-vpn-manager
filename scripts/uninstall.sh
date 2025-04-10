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
rm -f "$SCRIPT_DIR/shadowsocks_manager.sh" || print_message "WARNING" "Предупреждение: Не удалось удалить shadowsocks_manager.sh"
rm -f "$SCRIPT_DIR/shadowsocks_api.sh" || print_message "WARNING" "Предупреждение: Не удалось удалить shadowsocks_api.sh"
rm -f "$SCRIPT_DIR/post_mount.sh" || print_message "WARNING" "Предупреждение: Не удалось удалить post_mount.sh"
rm -f "$SCRIPT_DIR/shadowsocks_daemon.sh" || print_message "WARNING" "Предупреждение: Не удалось удалить shadowsocks_daemon.sh"

# Удаляем конфигурационные файлы
print_message "INFO" "Удаление конфигурационных файлов..."
rm -rf "$CONFIG_DIR" || print_message "WARNING" "Предупреждение: Не удалось удалить директорию конфигурации"

# Удаляем веб-интерфейс
print_message "INFO" "Удаление веб-интерфейса..."
rm -rf "$WEB_DIR" || print_message "WARNING" "Предупреждение: Не удалось удалить директорию веб-интерфейса"

# Спрашиваем пользователя о удалении пакетов
read -p "Удалить установленные пакеты (shadowsocks-libev, ipset, bash, nano, netcat, wget, timeout, socat, curl, iptables)? (y/n): " remove_packages
if [ "$remove_packages" = "y" ] || [ "$remove_packages" = "Y" ]; then
    print_message "INFO" "Удаление пакетов..."

    # Удаляем shadowsocks-libev
    print_message "INFO" "Удаление shadowsocks-libev..."
    opkg remove shadowsocks-libev-ss-local shadowsocks-libev-ss-redir || print_message "WARNING" "Предупреждение: Не удалось удалить shadowsocks-libev"

    # Удаляем ipset
    print_message "INFO" "Удаление ipset..."
    opkg remove ipset || print_message "WARNING" "Предупреждение: Не удалось удалить ipset"

    # Удаляем bash
    print_message "INFO" "Удаление bash..."
    opkg remove bash || print_message "WARNING" "Предупреждение: Не удалось удалить bash"

    # Удаляем nano
    print_message "INFO" "Удаление nano..."
    opkg remove nano || print_message "WARNING" "Предупреждение: Не удалось удалить nano"

    # Удаляем netcat
    print_message "INFO" "Удаление netcat..."
    opkg remove netcat || print_message "WARNING" "Предупреждение: Не удалось удалить netcat"

    # Удаляем wget
    print_message "INFO" "Удаление wget..."
    opkg remove wget || print_message "WARNING" "Предупреждение: Не удалось удалить wget"

    # Удаляем timeout
    print_message "INFO" "Удаление timeout..."
    opkg remove coreutils-timeout || print_message "WARNING" "Предупреждение: Не удалось удалить timeout"

    # Удаляем socat
    print_message "INFO" "Удаление socat..."
    opkg remove socat || print_message "WARNING" "Предупреждение: Не удалось удалить socat"

    # Удаляем curl
    print_message "INFO" "Удаление curl..."
    opkg remove curl || print_message "WARNING" "Предупреждение: Не удалось удалить curl"

    # Удаляем iptables
    print_message "INFO" "Удаление iptables..."
    opkg remove iptables || print_message "WARNING" "Предупреждение: Не удалось удалить iptables"
fi

# Удаляем сам скрипт удаления
print_message "INFO" "Удаление скрипта удаления..."
rm -f "$SCRIPT_DIR/uninstall.sh" || print_message "WARNING" "Предупреждение: Не удалось удалить uninstall.sh"

print_message "INFO" "Удаление Shadowsocks VPN Manager завершено!"
print_message "INFO" "Пожалуйста, перезагрузите роутер для завершения процесса удаления."

exit 0
