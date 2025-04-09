#!/bin/sh
# Установочный скрипт для Shadowsocks VPN Manager

# Определяем директории
SCRIPT_DIR="/jffs/scripts"
CONFIG_DIR="/jffs/configs/shadowsocks"
WEB_DIR="/jffs/www/shadowsocks"
CURRENT_DIR=$(dirname $(readlink -f "$0"))

# Функция для вывода ошибки и выхода
error_exit() {
    echo "Ошибка: $1"
    exit 1
}

# Проверяем наличие JFFS раздела
if [ ! -d "/jffs" ]; then
    error_exit "JFFS раздел не найден или не активирован. Пожалуйста, активируйте JFFS custom scripts в настройках роутера (Administration -> System)"
fi

# Создаем необходимые директории
echo "Создание директорий..."
mkdir -p $SCRIPT_DIR || error_exit "Не удалось создать директорию $SCRIPT_DIR"
mkdir -p $CONFIG_DIR || error_exit "Не удалось создать директорию $CONFIG_DIR"
mkdir -p $WEB_DIR || error_exit "Не удалось создать директорию $WEB_DIR"

# Проверяем наличие Entware
if [ ! -f "/opt/bin/opkg" ]; then
    error_exit "Entware не установлен. Пожалуйста, установите Entware через веб-интерфейс роутера (Administration -> System)"
fi

# Устанавливаем необходимые пакеты
echo "Установка необходимых пакетов..."
opkg update || error_exit "Не удалось обновить список пакетов"
opkg install shadowsocks-libev-ss-local shadowsocks-libev-ss-redir libuci libuci-lua libustream-openssl bash nano netcat || error_exit "Не удалось установить необходимые пакеты"

# Проверяем наличие исходных файлов
echo "Проверка исходных файлов..."
[ -f "$CURRENT_DIR/scripts/shadowsocks_manager.sh" ] || error_exit "Файл shadowsocks_manager.sh не найден"
[ -f "$CURRENT_DIR/scripts/shadowsocks_api.sh" ] || error_exit "Файл shadowsocks_api.sh не найден"
[ -f "$CURRENT_DIR/scripts/post-mount" ] || error_exit "Файл post-mount не найден"
[ -f "$CURRENT_DIR/scripts/shadowsocks_daemon.sh" ] || error_exit "Файл shadowsocks_daemon.sh не найден"
[ -f "$CURRENT_DIR/web/index.html" ] || error_exit "Файл index.html не найден"

# Создаем резервные копии существующих файлов
echo "Создание резервных копий..."
if [ -f "$SCRIPT_DIR/shadowsocks_manager.sh" ]; then
    cp "$SCRIPT_DIR/shadowsocks_manager.sh" "$SCRIPT_DIR/shadowsocks_manager.sh.bak" || echo "Предупреждение: Не удалось создать резервную копию shadowsocks_manager.sh"
fi
if [ -f "$SCRIPT_DIR/shadowsocks_api.sh" ]; then
    cp "$SCRIPT_DIR/shadowsocks_api.sh" "$SCRIPT_DIR/shadowsocks_api.sh.bak" || echo "Предупреждение: Не удалось создать резервную копию shadowsocks_api.sh"
fi
if [ -f "$SCRIPT_DIR/post-mount" ]; then
    cp "$SCRIPT_DIR/post-mount" "$SCRIPT_DIR/post-mount.bak" || echo "Предупреждение: Не удалось создать резервную копию post-mount"
fi
if [ -f "$SCRIPT_DIR/shadowsocks_daemon.sh" ]; then
    cp "$SCRIPT_DIR/shadowsocks_daemon.sh" "$SCRIPT_DIR/shadowsocks_daemon.sh.bak" || echo "Предупреждение: Не удалось создать резервную копию shadowsocks_daemon.sh"
fi

# Копируем скрипты из репозитория
echo "Копирование скриптов..."
cp -f "$CURRENT_DIR/scripts/shadowsocks_manager.sh" "$SCRIPT_DIR/" || error_exit "Не удалось скопировать shadowsocks_manager.sh"
cp -f "$CURRENT_DIR/scripts/shadowsocks_api.sh" "$SCRIPT_DIR/" || error_exit "Не удалось скопировать shadowsocks_api.sh"
cp -f "$CURRENT_DIR/scripts/post-mount" "$SCRIPT_DIR/" || error_exit "Не удалось скопировать post-mount"
cp -f "$CURRENT_DIR/scripts/shadowsocks_daemon.sh" "$SCRIPT_DIR/" || error_exit "Не удалось скопировать shadowsocks_daemon.sh"

# Копируем веб-интерфейс
echo "Копирование веб-интерфейса..."
cp -f "$CURRENT_DIR/web/index.html" "$WEB_DIR/" || error_exit "Не удалось скопировать index.html"

# Копируем дополнительные файлы веб-интерфейса, если они существуют
if [ -d "$CURRENT_DIR/web/css" ]; then
    mkdir -p "$WEB_DIR/css" || error_exit "Не удалось создать директорию $WEB_DIR/css"
    cp -rf "$CURRENT_DIR/web/css/"* "$WEB_DIR/css/" || echo "Предупреждение: Не удалось скопировать CSS файлы"
fi

if [ -d "$CURRENT_DIR/web/js" ]; then
    mkdir -p "$WEB_DIR/js" || error_exit "Не удалось создать директорию $WEB_DIR/js"
    cp -rf "$CURRENT_DIR/web/js/"* "$WEB_DIR/js/" || echo "Предупреждение: Не удалось скопировать JS файлы"
fi

if [ -d "$CURRENT_DIR/web/img" ]; then
    mkdir -p "$WEB_DIR/img" || error_exit "Не удалось создать директорию $WEB_DIR/img"
    cp -rf "$CURRENT_DIR/web/img/"* "$WEB_DIR/img/" || echo "Предупреждение: Не удалось скопировать изображения"
fi

# Делаем скрипты исполняемыми
echo "Установка прав на выполнение..."
chmod +x $SCRIPT_DIR/shadowsocks_manager.sh || error_exit "Не удалось установить права на выполнение для shadowsocks_manager.sh"
chmod +x $SCRIPT_DIR/shadowsocks_api.sh || error_exit "Не удалось установить права на выполнение для shadowsocks_api.sh"
chmod +x $SCRIPT_DIR/post-mount || error_exit "Не удалось установить права на выполнение для post-mount"
chmod +x $SCRIPT_DIR/shadowsocks_daemon.sh || error_exit "Не удалось установить права на выполнение для shadowsocks_daemon.sh"

# Включаем автозапуск Shadowsocks
echo "Настройка автозапуска..."
touch $CONFIG_DIR/autostart || error_exit "Не удалось создать файл autostart"

# Включаем веб-интерфейс
touch $CONFIG_DIR/webui_enabled || error_exit "Не удалось создать файл webui_enabled"

# Проверяем, не занят ли порт 8080
if netstat -tuln | grep -q ":8080 "; then
    echo "Предупреждение: Порт 8080 уже используется. Веб-интерфейс может быть недоступен."
fi

# Запускаем веб-интерфейс
echo "Запуск веб-интерфейса..."
$SCRIPT_DIR/shadowsocks_api.sh start || error_exit "Не удалось запустить веб-интерфейс"

# Выводим инструкцию по использованию
echo ""
echo "Установка Shadowsocks VPN Manager успешно завершена!"
echo ""
echo "Веб-интерфейс доступен по адресу: http://$(ip -o -4 addr show br0 | awk '{print $4}' | cut -d'/' -f1):8080"
echo ""
echo "Управление через командную строку:"
echo "  Запуск VPN:       $SCRIPT_DIR/shadowsocks_manager.sh start"
echo "  Остановка VPN:    $SCRIPT_DIR/shadowsocks_manager.sh stop"
echo "  Перезапуск VPN:   $SCRIPT_DIR/shadowsocks_manager.sh restart"
echo "  Проверка статуса: $SCRIPT_DIR/shadowsocks_manager.sh status"
echo ""
echo "Управление автозапуском и веб-интерфейсом:"
echo "  $SCRIPT_DIR/shadowsocks_daemon.sh {enable-autostart|disable-autostart|enable-webui|disable-webui|start-webui|stop-webui}"
echo ""
echo "Пожалуйста, перезагрузите роутер для активации всех функций."

# Спрашиваем, хочет ли пользователь удалить исходные файлы
read -p "Удалить исходные файлы проекта? (y/n): " answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    echo "Удаление исходных файлов..."
    cd ..
    rm -rf "$CURRENT_DIR" || error_exit "Не удалось удалить исходные файлы"
    echo "Исходные файлы удалены."
fi

exit 0
