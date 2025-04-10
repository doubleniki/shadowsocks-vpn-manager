# Shadowsocks VPN Manager для ASUS Router с прошивкой Merlin

Менеджер для управления Shadowsocks VPN на роутерах ASUS с прошивкой Merlin. Поддерживает автоматическую маршрутизацию трафика, веб-интерфейс для управления и автозапуск при перезагрузке роутера.

## Структура проекта

```bash
asus-router-merlin-ss-setup/
├── README.md
├── install.sh
├── install_wget.sh
├── scripts/
│   ├── uninstall.sh
│   ├── shadowsocks_manager.sh
│   ├── shadowsocks_api.sh
│   ├── post_mount.sh
│   └── shadowsocks_daemon.sh
├── config/
│   └── routing/
│       └── default_routes.json
└── web/
    ├── index.html
    ├── css/
    ├── js/
    └── img/
```

## Требования

- Роутер ASUS с прошивкой Merlin
- Активированный JFFS раздел
- Установленный Entware
- Доступ к интернету

## Установка

### Способ 1: Установка через wget (рекомендуется)

```bash
wget -qO- https://raw.githubusercontent.com/doubleniki/asus-router-merlin-ss-setup/main/install_wget.sh | sh
```

### Способ 2: Ручная установка

1. Клонируйте репозиторий:

```bash
git clone https://github.com/doubleniki/asus-router-merlin-ss-setup.git
cd asus-router-merlin-ss-setup
```

2. Запустите скрипт установки:

```bash
sh install.sh
```

## Настройка маршрутизации

По умолчанию предоставляются следующие правила маршрутизации:

1. Китайские сервисы (baidu.com, qq.com, taobao.com и др.)
2. Российские сервисы (yandex.ru, mail.ru, vk.com и др.)
3. Локальная сеть (192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12)

Вы можете изменить правила маршрутизации, отредактировав файл `/jffs/configs/shadowsocks/routes.json`.

## Управление

### Через командную строку

```bash
# Запуск VPN
/jffs/scripts/shadowsocks_manager.sh start

# Остановка VPN
/jffs/scripts/shadowsocks_manager.sh stop

# Перезапуск VPN
/jffs/scripts/shadowsocks_manager.sh restart

# Проверка статуса
/jffs/scripts/shadowsocks_manager.sh status
```

### Управление автозапуском и веб-интерфейсом

```bash
/jffs/scripts/shadowsocks_daemon.sh {enable-autostart|disable-autostart|enable-webui|disable-webui|start-webui|stop-webui}
```

### Через веб-интерфейс

После включения веб-интерфейса, он будет доступен по адресу:

```bash
http://<IP-адрес-роутера>:8080
```

## Удаление

Для удаления Shadowsocks VPN Manager выполните:

```bash
/jffs/scripts/uninstall.sh
```

## Лицензия

MIT License

## Автор

doubleniki

## Поддержка

Если у вас возникли проблемы или есть предложения по улучшению, пожалуйста, создайте issue в репозитории проекта.
