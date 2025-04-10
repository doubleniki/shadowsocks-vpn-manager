#!/bin/sh
# Установочный скрипт для Shadowsocks VPN Manager

# Определяем директории
SCRIPT_DIR="/jffs/scripts"
CONFIG_DIR="/jffs/configs/shadowsocks"
WEB_DIR="/jffs/www/shadowsocks"
CURRENT_DIR=$(dirname $(readlink -f "$0"))

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

# Проверяем наличие JFFS раздела
if [ ! -d "/jffs" ]; then
    error_exit "JFFS раздел не найден или не активирован. Пожалуйста, активируйте JFFS custom scripts в настройках роутера (Administration -> System)"
fi

# Создаем необходимые директории
print_message "INFO" "Создание директорий..."
mkdir -p $SCRIPT_DIR || error_exit "Не удалось создать директорию $SCRIPT_DIR"
mkdir -p $CONFIG_DIR || error_exit "Не удалось создать директорию $CONFIG_DIR"
mkdir -p $WEB_DIR || error_exit "Не удалось создать директорию $WEB_DIR"

# Проверяем наличие Entware
if [ ! -f "/opt/bin/opkg" ]; then
    error_exit "Entware не установлен. Пожалуйста, установите Entware через веб-интерфейс роутера (Administration -> System)"
fi

# Устанавливаем необходимые пакеты
print_message "INFO" "Установка необходимых пакетов..."
opkg update || error_exit "Не удалось обновить список пакетов"

# Проверяем наличие shadowsocks-libev
print_message "INFO" "Проверка наличия shadowsocks-libev..."
if [ ! -f "/opt/bin/ss-redir" ]; then
    print_message "INFO" "Установка shadowsocks-libev..."
    opkg install shadowsocks-libev-ss-local shadowsocks-libev-ss-redir || error_exit "Не удалось установить shadowsocks-libev"
else
    print_message "INFO" "shadowsocks-libev уже установлен."
fi

# Проверяем наличие bash
print_message "INFO" "Проверка наличия bash..."
if [ ! -f "/opt/bin/bash" ]; then
    print_message "INFO" "Установка bash..."
    opkg install bash || error_exit "Не удалось установить bash"
else
    print_message "INFO" "bash уже установлен."
fi

# Проверяем наличие nano
print_message "INFO" "Проверка наличия nano..."
if [ ! -f "/opt/bin/nano" ]; then
    print_message "INFO" "Установка nano..."
    opkg install nano || error_exit "Не удалось установить nano"
else
    print_message "INFO" "nano уже установлен."
fi

# Проверяем наличие netcat
print_message "INFO" "Проверка наличия netcat..."
if [ ! -f "/opt/bin/netcat" ]; then
    print_message "INFO" "Установка netcat..."
    opkg install netcat || error_exit "Не удалось установить netcat"
else
    print_message "INFO" "netcat уже установлен."
fi

# Проверяем наличие libuci (обычно уже установлен в прошивке)
print_message "INFO" "Проверка наличия libuci..."
if [ ! -f "/usr/lib/libuci.so" ]; then
    print_message "WARNING" "libuci не найден. Это может вызвать проблемы."
    print_message "INFO" "Попытка установки из альтернативного репозитория..."
    opkg install --force-depends libuci || print_message "WARNING" "Не удалось установить libuci, но установка продолжится."
else
    print_message "INFO" "libuci уже установлен в системе."
fi

# Проверяем наличие libuci-lua (обычно уже установлен в прошивке)
print_message "INFO" "Проверка наличия libuci-lua..."
if [ ! -f "/usr/lib/lua/luci/model/uci.lua" ]; then
    print_message "WARNING" "libuci-lua не найден. Это может вызвать проблемы."
    print_message "INFO" "Попытка установки из альтернативного репозитория..."
    opkg install --force-depends libuci-lua || print_message "WARNING" "Не удалось установить libuci-lua, но установка продолжится."
else
    print_message "INFO" "libuci-lua уже установлен в системе."
fi

# Проверяем наличие libustream-openssl (обычно уже установлен в прошивке)
print_message "INFO" "Проверка наличия libustream-openssl..."
if [ ! -f "/usr/lib/libustream-openssl.so" ]; then
    print_message "WARNING" "libustream-openssl не найден. Это может вызвать проблемы."
    print_message "INFO" "Попытка установки из альтернативного репозитория..."
    opkg install --force-depends libustream-openssl || print_message "WARNING" "Не удалось установить libustream-openssl, но установка продолжится."
else
    print_message "INFO" "libustream-openssl уже установлен в системе."
fi

# Проверяем наличие исходных файлов
print_message "INFO" "Проверка исходных файлов..."
[ -f "$CURRENT_DIR/scripts/shadowsocks_manager.sh" ] || error_exit "Файл shadowsocks_manager.sh не найден"
[ -f "$CURRENT_DIR/scripts/shadowsocks_api.sh" ] || error_exit "Файл shadowsocks_api.sh не найден"
[ -f "$CURRENT_DIR/scripts/post_mount.sh" ] || error_exit "Файл post_mount.sh не найден"
[ -f "$CURRENT_DIR/scripts/shadowsocks_daemon.sh" ] || error_exit "Файл shadowsocks_daemon.sh не найден"
[ -f "$CURRENT_DIR/web/index.html" ] || error_exit "Файл index.html не найден"

# Создаем резервные копии существующих файлов
print_message "INFO" "Создание резервных копий..."
if [ -f "$SCRIPT_DIR/shadowsocks_manager.sh" ]; then
    cp "$SCRIPT_DIR/shadowsocks_manager.sh" "$SCRIPT_DIR/shadowsocks_manager.sh.bak" || print_message "WARNING" "Предупреждение: Не удалось создать резервную копию shadowsocks_manager.sh"
fi
if [ -f "$SCRIPT_DIR/shadowsocks_api.sh" ]; then
    cp "$SCRIPT_DIR/shadowsocks_api.sh" "$SCRIPT_DIR/shadowsocks_api.sh.bak" || print_message "WARNING" "Предупреждение: Не удалось создать резервную копию shadowsocks_api.sh"
fi
if [ -f "$SCRIPT_DIR/post_mount.sh" ]; then
    cp "$SCRIPT_DIR/post_mount.sh" "$SCRIPT_DIR/post_mount.sh.bak" || print_message "WARNING" "Предупреждение: Не удалось создать резервную копию post_mount.sh"
fi
if [ -f "$SCRIPT_DIR/shadowsocks_daemon.sh" ]; then
    cp "$SCRIPT_DIR/shadowsocks_daemon.sh" "$SCRIPT_DIR/shadowsocks_daemon.sh.bak" || print_message "WARNING" "Предупреждение: Не удалось создать резервную копию shadowsocks_daemon.sh"
fi

# Копируем скрипты из репозитория
print_message "INFO" "Копирование скриптов..."
cp -f "$CURRENT_DIR/scripts/shadowsocks_manager.sh" "$SCRIPT_DIR/" || error_exit "Не удалось скопировать shadowsocks_manager.sh"
cp -f "$CURRENT_DIR/scripts/shadowsocks_api.sh" "$SCRIPT_DIR/" || error_exit "Не удалось скопировать shadowsocks_api.sh"
cp -f "$CURRENT_DIR/scripts/post_mount.sh" "$SCRIPT_DIR/" || error_exit "Не удалось скопировать post_mount.sh"
cp -f "$CURRENT_DIR/scripts/shadowsocks_daemon.sh" "$SCRIPT_DIR/" || error_exit "Не удалось скопировать shadowsocks_daemon.sh"

# Копируем веб-интерфейс
print_message "INFO" "Копирование веб-интерфейса..."
cp -f "$CURRENT_DIR/web/index.html" "$WEB_DIR/" || error_exit "Не удалось скопировать index.html"

# Копируем дополнительные файлы веб-интерфейса, если они существуют
if [ -d "$CURRENT_DIR/web/css" ]; then
    mkdir -p "$WEB_DIR/css" || error_exit "Не удалось создать директорию $WEB_DIR/css"
    cp -rf "$CURRENT_DIR/web/css/"* "$WEB_DIR/css/" || print_message "WARNING" "Предупреждение: Не удалось скопировать CSS файлы"
fi

if [ -d "$CURRENT_DIR/web/js" ]; then
    mkdir -p "$WEB_DIR/js" || error_exit "Не удалось создать директорию $WEB_DIR/js"
    cp -rf "$CURRENT_DIR/web/js/"* "$WEB_DIR/js/" || print_message "WARNING" "Предупреждение: Не удалось скопировать JS файлы"
fi

if [ -d "$CURRENT_DIR/web/img" ]; then
    mkdir -p "$WEB_DIR/img" || error_exit "Не удалось создать директорию $WEB_DIR/img"
    cp -rf "$CURRENT_DIR/web/img/"* "$WEB_DIR/img/" || print_message "WARNING" "Предупреждение: Не удалось скопировать изображения"
fi

# Делаем скрипты исполняемыми
print_message "INFO" "Установка прав на выполнение..."
chmod +x $SCRIPT_DIR/shadowsocks_manager.sh || error_exit "Не удалось установить права на выполнение для shadowsocks_manager.sh"
chmod +x $SCRIPT_DIR/shadowsocks_api.sh || error_exit "Не удалось установить права на выполнение для shadowsocks_api.sh"
chmod +x $SCRIPT_DIR/post_mount.sh || error_exit "Не удалось установить права на выполнение для post_mount.sh"
chmod +x $SCRIPT_DIR/shadowsocks_daemon.sh || error_exit "Не удалось установить права на выполнение для shadowsocks_daemon.sh"

# Включаем автозапуск Shadowsocks
print_message "INFO" "Настройка автозапуска..."
touch $CONFIG_DIR/autostart || error_exit "Не удалось создать файл autostart"

# Спрашиваем пользователя о включении веб-интерфейса
read -p "Включить веб-интерфейс? (y/n): " enable_webui
if [ "$enable_webui" = "y" ] || [ "$enable_webui" = "Y" ]; then
    # Включаем веб-интерфейс
    touch $CONFIG_DIR/webui_enabled || error_exit "Не удалось создать файл webui_enabled"

    # Проверяем, не занят ли порт 8080
    if netstat -tuln | grep -q ":8080 "; then
        print_message "WARNING" "Предупреждение: Порт 8080 уже используется. Веб-интерфейс может быть недоступен."
    fi

    # Запускаем веб-интерфейс
    print_message "INFO" "Запуск веб-интерфейса..."
    $SCRIPT_DIR/shadowsocks_api.sh start || error_exit "Не удалось запустить веб-интерфейс"
fi

# Выводим инструкцию по использованию
print_message "INFO" ""
print_message "INFO" "Установка Shadowsocks VPN Manager успешно завершена!"
print_message "INFO" ""
if [ "$enable_webui" = "y" ] || [ "$enable_webui" = "Y" ]; then
    print_message "INFO" "Веб-интерфейс доступен по адресу: http://$(ip -o -4 addr show br0 | awk '{print $4}' | cut -d'/' -f1):8080"
    print_message "INFO" ""
fi
print_message "INFO" "Управление через командную строку:"
print_message "INFO" "  Запуск VPN:       $SCRIPT_DIR/shadowsocks_manager.sh start"
print_message "INFO" "  Остановка VPN:    $SCRIPT_DIR/shadowsocks_manager.sh stop"
print_message "INFO" "  Перезапуск VPN:   $SCRIPT_DIR/shadowsocks_manager.sh restart"
print_message "INFO" "  Проверка статуса: $SCRIPT_DIR/shadowsocks_manager.sh status"
print_message "INFO" ""
print_message "INFO" "Управление автозапуском и веб-интерфейсом:"
print_message "INFO" "  $SCRIPT_DIR/shadowsocks_daemon.sh {enable-autostart|disable-autostart|enable-webui|disable-webui|start-webui|stop-webui}"
print_message "INFO" ""
print_message "INFO" "Пожалуйста, перезагрузите роутер для активации всех функций."

# Спрашиваем, хочет ли пользователь удалить исходные файлы
read -p "Удалить исходные файлы проекта? (y/n): " answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    print_message "INFO" "Удаление исходных файлов..."
    cd ..
    rm -rf "$CURRENT_DIR" || error_exit "Не удалось удалить исходные файлы"
    print_message "INFO" "Исходные файлы удалены."
fi

exit 0
