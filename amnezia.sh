#!/bin/bash

# Обновление системы (опционально)
read -p "Выполнить полное обновление системы? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo apt update && sudo apt full-upgrade -y
    echo "Обновление завершено. Перезагрузите систему и запустите скрипт снова."
    exit 0
fi

# Проверка и настройка репозиториев с исходным кодом
if ! grep -q "^deb-src" /etc/apt/sources.list; then
    echo "Добавляем репозиторий с исходным кодом..."
    sudo sed -i 's/^deb \(.*\)$/deb \1\ndeb-src \1/' /etc/apt/sources.list
fi

# Установка зависимостей
echo "Установка зависимостей..."
sudo apt update
sudo apt install -y software-properties-common python3-launchpadlib gnupg2 linux-headers-$(uname -r)

# Добавление PPA репозитория
echo "Добавление репозитория Amnezia..."
sudo add-apt-repository -y ppa:amnezia/ppa

# Установка AmneziaVPN
echo "Установка AmneziaVPN..."
sudo apt update
sudo apt install -y amneziawg

echo "Установка завершена!"
