#!/bin/sh

# Запускаем Shadowsocks, если он был включен
if [ -f "/jffs/configs/shadowsocks/autostart" ]; then
    # Ожидаем 60 секунд для полной загрузки сети
    sleep 60
    /jffs/scripts/shadowsocks_manager.sh start
fi

# Запускаем HTTP-сервер для управления Shadowsocks
if [ -f "/jffs/configs/shadowsocks/webui_enabled" ]; then
    /jffs/scripts/shadowsocks_api.sh start &
fi

exit 0
