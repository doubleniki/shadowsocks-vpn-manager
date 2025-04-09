#!/bin/sh

# Путь к файлам
CONFIG_DIR="/jffs/configs/shadowsocks"
SCRIPT_DIR="/jffs/scripts"
API_PID_FILE="/tmp/shadowsocks_api.pid"

# Включение/выключение автозапуска Shadowsocks
enable_autostart() {
    touch "$CONFIG_DIR/autostart"
    echo "Автозапуск Shadowsocks включен"
}

disable_autostart() {
    rm -f "$CONFIG_DIR/autostart"
    echo "Автозапуск Shadowsocks выключен"
}

# Включение/выключение веб-интерфейса
enable_webui() {
    touch "$CONFIG_DIR/webui_enabled"
    echo "Веб-интерфейс Shadowsocks включен"
    start_webui
}

disable_webui() {
    rm -f "$CONFIG_DIR/webui_enabled"
    echo "Веб-интерфейс Shadowsocks выключен"
    stop_webui
}

# Запуск веб-интерфейса
start_webui() {
    # Проверяем, запущен ли уже сервер
    if [ -f "$API_PID_FILE" ]; then
        if kill -0 $(cat "$API_PID_FILE") 2>/dev/null; then
            echo "Веб-интерфейс уже запущен"
            return 0
        else
            rm -f "$API_PID_FILE"
        fi
    fi

    # Запускаем сервер и сохраняем PID
    $SCRIPT_DIR/shadowsocks_api.sh start &
    echo $! > "$API_PID_FILE"
    echo "Веб-интерфейс запущен"
}

# Остановка веб-интерфейса
stop_webui() {
    if [ -f "$API_PID_FILE" ]; then
        kill $(cat "$API_PID_FILE")
        rm -f "$API_PID_FILE"
        echo "Веб-интерфейс остановлен"
    else
        echo "Веб-интерфейс не запущен"
    fi
}

# Отображение справки
show_help() {
    echo "Использование: $0 {enable-autostart|disable-autostart|enable-webui|disable-webui|start-webui|stop-webui}"
    echo ""
    echo "  enable-autostart   - Включить автозапуск Shadowsocks при загрузке роутера"
    echo "  disable-autostart  - Выключить автозапуск Shadowsocks"
    echo "  enable-webui       - Включить веб-интерфейс и его автозапуск"
    echo "  disable-webui      - Выключить веб-интерфейс и его автозапуск"
    echo "  start-webui        - Запустить веб-интерфейс"
    echo "  stop-webui         - Остановить веб-интерфейс"
}

# Обработка команд
case "$1" in
    enable-autostart)
        enable_autostart
        ;;
    disable-autostart)
        disable_autostart
        ;;
    enable-webui)
        enable_webui
        ;;
    disable-webui)
        disable_webui
        ;;
    start-webui)
        start_webui
        ;;
    stop-webui)
        stop_webui
        ;;
    *)
        show_help
        exit 1
        ;;
esac

exit 0
