#!/bin/sh
# Установочный скрипт для Shadowsocks VPN Manager

# Определяем директории
SCRIPT_DIR="/jffs/scripts"
CONFIG_DIR="/jffs/configs/shadowsocks"
WEB_DIR="/jffs/www/shadowsocks"
CURRENT_DIR=$(dirname $(readlink -f "$0"))

# Проверяем наличие JFFS раздела
if [ ! -d "/jffs" ]; then
    echo "Ошибка: JFFS раздел не найден или не активирован"
    echo "Пожалуйста, активируйте JFFS custom scripts в настройках роутера (Administration -> System)"
    exit 1
fi

# Создаем необходимые директории
mkdir -p $SCRIPT_DIR
mkdir -p $CONFIG_DIR
mkdir -p $WEB_DIR

# Проверяем наличие Entware
if [ ! -f "/opt/bin/opkg" ]; then
    echo "Ошибка: Entware не установлен"
    echo "Пожалуйста, установите Entware через веб-интерфейс роутера (Administration -> System)"
    exit 1
fi

# Устанавливаем необходимые пакеты
echo "Установка необходимых пакетов..."
opkg update
opkg install shadowsocks-libev-ss-local shadowsocks-libev-ss-redir libuci libuci-lua libustream-openssl bash nano netcat

# Копируем скрипты из репозитория
echo "Копирование скриптов..."
cp -f "$CURRENT_DIR/scripts/shadowsocks_manager.sh" "$SCRIPT_DIR/"
cp -f "$CURRENT_DIR/scripts/shadowsocks_api.sh" "$SCRIPT_DIR/"
cp -f "$CURRENT_DIR/scripts/post-mount" "$SCRIPT_DIR/"
cp -f "$CURRENT_DIR/scripts/shadowsocks_daemon.sh" "$SCRIPT_DIR/"

# Копируем веб-интерфейс
echo "Копирование веб-интерфейса..."
cp -f "$CURRENT_DIR/web/index.html" "$WEB_DIR/"

# Делаем скрипты исполняемыми
chmod +x $SCRIPT_DIR/shadowsocks_manager.sh
chmod +x $SCRIPT_DIR/shadowsocks_api.sh
chmod +x $SCRIPT_DIR/post-mount
chmod +x $SCRIPT_DIR/shadowsocks_daemon.sh

# Включаем автозапуск Shadowsocks
mkdir -p $CONFIG_DIR
touch $CONFIG_DIR/autostart

# Включаем веб-интерфейс
touch $CONFIG_DIR/webui_enabled

# Запускаем веб-интерфейс
$SCRIPT_DIR/shadowsocks_api.sh start &

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
    rm -rf "$CURRENT_DIR"
    echo "Исходные файлы удалены."
fi

exit 0
