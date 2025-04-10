#!/bin/sh
# Общие функции для скриптов Shadowsocks VPN Manager

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
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

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

    echo -e "${color}[$timestamp] [$level] $message${NC}"
}

# Функция для вывода ошибки и выхода
error_exit() {
    print_message "ERROR" "Ошибка: $1"
    exit 1
}

# Функция для проверки и установки пакета
install_package() {
    local package_name=$1
    local binary_path=$2
    local opkg_package=$3

    if [ ! -f "$binary_path" ]; then
        print_message "INFO" "Установка $package_name..."
        opkg install $opkg_package || error_exit "Не удалось установить $package_name"
    else
        print_message "INFO" "$package_name уже установлен."
    fi
}

# Функция для проверки и удаления пакета
remove_package() {
    local package_name=$1
    local opkg_package=$2

    print_message "INFO" "Удаление $package_name..."
    opkg remove $opkg_package || print_message "WARNING" "Предупреждение: Не удалось удалить $package_name"
}

# Функция для создания директории
create_directory() {
    local dir=$1
    local dir_name=$2

    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || error_exit "Не удалось создать директорию $dir_name"
        print_message "INFO" "Создана директория $dir_name"
    fi
}

# Функция для копирования файла
copy_file() {
    local source=$1
    local destination=$2
    local file_name=$3

    cp -f "$source" "$destination" || error_exit "Не удалось скопировать $file_name"
    print_message "INFO" "Скопирован файл $file_name"
}

# Функция для установки прав на выполнение
set_executable() {
    local file=$1
    local file_name=$2

    chmod +x "$file" || error_exit "Не удалось установить права на выполнение для $file_name"
    print_message "INFO" "Установлены права на выполнение для $file_name"
}

# Функция для проверки наличия Entware
check_entware() {
    if [ ! -f "/opt/bin/opkg" ]; then
        error_exit "Entware не установлен. Пожалуйста, установите Entware через веб-интерфейс роутера (Administration -> System)"
    fi
}

# Функция для проверки наличия JFFS
check_jffs() {
    if [ ! -d "/jffs" ]; then
        error_exit "JFFS раздел не найден или не активирован. Пожалуйста, активируйте JFFS custom scripts в настройках роутера (Administration -> System)"
    fi
}

# Функция для проверки системных библиотек
check_system_libraries() {
    local libraries=(
        "/usr/lib/libuci.so:libuci"
        "/usr/lib/lua/luci/model/uci.lua:libuci-lua"
        "/usr/lib/libustream-openssl.so:libustream-openssl"
    )

    for lib in "${libraries[@]}"; do
        IFS=':' read -r path name <<< "$lib"
        if [ ! -f "$path" ]; then
            print_message "ERROR" "$name не найден. Это критическая ошибка, так как библиотека должна быть в прошивке."
            error_exit "Отсутствует критическая системная библиотека $name"
        fi
    done

    print_message "INFO" "Все необходимые системные библиотеки найдены."
}
