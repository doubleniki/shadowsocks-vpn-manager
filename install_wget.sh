#!/bin/sh

# Цветовые коды
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Проверяем наличие wget
if ! command -v wget >/dev/null 2>&1; then
    error_exit "wget не установлен. Установите его через opkg: opkg install wget"
fi

# Создаем временную директорию
TEMP_DIR="/tmp/ss_install"
mkdir -p $TEMP_DIR || error_exit "Не удалось создать временную директорию"

# Скачиваем репозиторий
print_message "INFO" "Скачивание репозитория..."
wget -q --no-check-certificate https://github.com/doubleniki/asus-router-merlin-ss-setup/archive/refs/heads/main.zip -O $TEMP_DIR/main.zip || error_exit "Не удалось скачать репозиторий"

# Распаковываем архив
print_message "INFO" "Распаковка архива..."
unzip -q $TEMP_DIR/main.zip -d $TEMP_DIR || error_exit "Не удалось распаковать архив"

# Переходим в директорию с распакованным репозиторием
cd $TEMP_DIR/asus-router-merlin-ss-setup-main || error_exit "Не удалось перейти в директорию репозитория"

# Запускаем основной скрипт установки
print_message "INFO" "Запуск установки..."
sh install.sh || error_exit "Не удалось выполнить установку"

# Очищаем временные файлы
print_message "INFO" "Очистка временных файлов..."
rm -rf $TEMP_DIR || print_message "WARNING" "Не удалось удалить временные файлы"

print_message "INFO" "Установка завершена успешно!"
exit 0
