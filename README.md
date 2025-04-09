# Shadowsocks VPN Manager for ASUS Routers

Shadowsocks VPN Manager - это решение для настройки и управления Shadowsocks VPN клиентом на роутерах ASUS с прошивкой Asuswrt-Merlin. Проект предоставляет веб-интерфейс для удобного управления VPN подключением, настройки маршрутизации трафика для отдельных сайтов и устройств.

## Возможности

- Простая установка и управление Shadowsocks VPN клиентом
- Веб-интерфейс для удобной настройки
- Гибкая маршрутизация трафика:
  - "Весь трафик через VPN" - все подключения идут через VPN
  - "Весь трафик напрямую, выбранные через VPN" - только выбранные сайты через VPN
  - "Весь трафик через VPN, выбранные напрямую" - все через VPN, кроме исключений
- Управление маршрутизацией для отдельных устройств в сети
- Настройка правил маршрутизации по доменам или IP-адресам
- Удобный просмотр журнала работы

## Требования

- Роутер ASUS с прошивкой Asuswrt-Merlin
  - Протестировано на ASUS RT-AX86U Pro
  - Должно работать на других моделях с прошивкой Merlin
- Установленный Entware
- Доступ по SSH к роутеру
- Сервер Shadowsocks для подключения

## Установка

### 1. Подготовка

Прежде чем начать установку, убедитесь, что:

1. На вашем роутере установлена прошивка Asuswrt-Merlin
2. Активирован JFFS раздел и пользовательские скрипты
3. Установлен пакет Entware

### 2. Активация JFFS раздела (если еще не активирован)

1. Войдите в веб-интерфейс роутера
2. Перейдите в "Administration" → "System"
3. Включите опцию "Enable JFFS custom scripts and configs"
4. Нажмите "Apply" и перезагрузите роутер

### 3. Установка Entware (если еще не установлен)

1. Войдите в веб-интерфейс роутера
2. Перейдите в "Administration" → "System"
3. В секции Entware нажмите кнопку "Download and install Entware"
4. Следуйте инструкциям на экране

### 4. Подключение к роутеру по SSH

#### Из Windows

1. Установите программу PuTTY или аналогичную
2. Откройте PuTTY и введите IP-адрес вашего роутера (обычно 192.168.50.1 или 192.168.1.1)
3. Укажите порт 22 (стандартный порт SSH) или тот, что у вас настроен
4. Нажмите "Open" для подключения
5. При запросе учетных данных введите:
   - Логин: admin (или ваш логин администратора)
   - Пароль: тот же, что используется для входа в веб-интерфейс роутера

#### Из Linux или MacOS

1. Откройте терминал
2. Выполните команду:

```bash
ssh admin@192.168.50.1 -p <порт>
```

(замените IP-адрес на адрес вашего роутера и порт на тот, что у вас настроен)
3. Введите пароль администратора при запросе

### 5. Установка Shadowsocks VPN Manager

#### Установка из репозитория Git

1. Клонируйте репозиторий на роутер:

```bash
cd /tmp
opkg update
opkg install git git-http
git clone https://github.com/your-username/shadowsocks-vpn-manager.git
cd shadowsocks-vpn-manager
```

2.Запустите установочный скрипт:

```bash
chmod +x install.sh
./install.sh
```

3.После установки выберите опцию удаления исходных файлов, если вам больше не нужен репозиторий

4.Перезагрузите роутер для активации всех функций:

```bash
reboot
```

#### Ручная установка

Если у вас нет возможности использовать Git, вы можете установить решение вручную:

1. Скачайте архив с проектом на свой компьютер
2. Распакуйте его
3. Загрузите файлы на роутер через SCP или другим способом
4. Запустите установочный скрипт:

```bash
chmod +x install.sh
./install.sh
```

## Настройка Shadowsocks

### 1. Доступ к веб-интерфейсу

После установки веб-интерфейс будет доступен по адресу:

```bash
http://[IP-роутера]:8080
```

Например: `http://192.168.50.1:8080`

### 2. Настройка подключения

1. В веб-интерфейсе перейдите на вкладку "Настройки"
2. Введите данные вашего Shadowsocks сервера:
   - Сервер: IP-адрес или домен вашего Shadowsocks сервера
   - Порт: порт сервера
   - Пароль: пароль для аутентификации
   - Метод шифрования: выберите метод, соответствующий настройкам сервера
3. Нажмите "Сохранить настройки"
4. Нажмите кнопку "Включить VPN" для запуска соединения

### 3. Настройка маршрутизации

1. В разделе "Режим маршрутизации" выберите один из режимов:
   - "Весь трафик через VPN" - весь интернет-трафик идет через VPN
   - "Весь трафик напрямую, выбранные через VPN" - весь трафик идет напрямую, только выбранные сайты через VPN
   - "Весь трафик через VPN, выбранные напрямую" - весь трафик через VPN, только выбранные сайты напрямую
2. Нажмите "Сохранить режим"

### 4. Добавление правил маршрутизации

1. Перейдите на вкладку "Маршрутизация"
2. Для добавления домена или IP-адреса:
   - Введите домен (например, google.com) или IP-адрес
   - Выберите тип маршрутизации (через VPN или напрямую)
   - Нажмите "Добавить"
3. Правила маршрутизации будут отображаться в таблицах ниже

### 5. Управление устройствами

1. Перейдите на вкладку "Устройства"
2. Для добавления устройства:
   - Введите MAC-адрес устройства в формате XX:XX:XX:XX:XX:XX
   - Введите имя устройства для удобной идентификации
   - Выберите тип маршрутизации (через VPN или напрямую)
   - Нажмите "Добавить"
3. Список устройств будет отображаться в таблице ниже

## Управление через командную строку

Если веб-интерфейс недоступен, вы можете управлять Shadowsocks VPN через SSH:

```bash
# Проверка статуса
/jffs/scripts/shadowsocks_manager.sh status

# Запуск VPN
/jffs/scripts/shadowsocks_manager.sh start

# Остановка VPN
/jffs/scripts/shadowsocks_manager.sh stop

# Перезапуск VPN
/jffs/scripts/shadowsocks_manager.sh restart

# Управление автозапуском и веб-интерфейсом
/jffs/scripts/shadowsocks_daemon.sh enable-autostart
/jffs/scripts/shadowsocks_daemon.sh disable-autostart
/jffs/scripts/shadowsocks_daemon.sh enable-webui
/jffs/scripts/shadowsocks_daemon.sh disable-webui
```

## Расположение файлов

- **/jffs/scripts/shadowsocks_manager.sh** - основной скрипт управления Shadowsocks
- **/jffs/scripts/shadowsocks_api.sh** - API для веб-интерфейса
- **/jffs/scripts/post-mount** - скрипт автозагрузки
- **/jffs/scripts/shadowsocks_daemon.sh** - скрипт управления службами
- **/jffs/configs/shadowsocks/** - директория с конфигурационными файлами
  - **config.json** - настройки подключения
  - **routes.json** - правила маршрутизации
  - **devices.json** - настройки устройств
  - **shadowsocks.log** - журнал работы
- **/jffs/www/shadowsocks/** - директория с файлами веб-интерфейса

## Устранение неполадок

### Проблемы с подключением

1. Проверьте корректность данных сервера, порта, пароля и метода шифрования
2. Убедитесь, что сервер Shadowsocks доступен с вашего роутера
3. Проверьте журнал работы (`/jffs/configs/shadowsocks/shadowsocks.log`)

### Проблемы с веб-интерфейсом

1. Убедитесь, что веб-сервер запущен:

   ```
   ps | grep shadowsocks_api
   ```

2. Перезапустите веб-интерфейс:

   ```
   /jffs/scripts/shadowsocks_daemon.sh stop-webui
   /jffs/scripts/shadowsocks_daemon.sh start-webui
   ```

### Проблемы с маршрутизацией

1. Проверьте правила iptables:

   ```
   iptables -t nat -L SHADOWSOCKS
   ```

2. Проверьте наборы ipset:

   ```
   ipset list ss_bypass
   ipset list ss_direct
   ipset list ss_devices
   ```

## Безопасность

Веб-интерфейс не имеет аутентификации, поэтому рекомендуется:

1. Использовать его только в локальной сети
2. Отключать веб-интерфейс, когда он не используется:

   ```
   /jffs/scripts/shadowsocks_daemon.sh disable-webui
   ```

## Лицензия

Этот проект распространяется под лицензией MIT. См. файл LICENSE для получения дополнительной информации.

## Поддержка и участие в разработке

Если у вас есть вопросы, предложения или вы нашли ошибку, пожалуйста, создайте Issue в репозитории или отправьте Pull Request с исправлениями или улучшениями.

## Благодарности

- Проект Asuswrt-Merlin за предоставление расширенной прошивки для роутеров ASUS
- Разработчикам Shadowsocks за создание эффективного инструмента для обхода ограничений
- Всем пользователям, которые помогают улучшать этот проект
