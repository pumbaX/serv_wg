#!/bin/bash

# Скрипт для установки AmneziaWG на Ubuntu

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}=== Установка AmneziaWG на Ubuntu ===${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. Обновление системы (опционально, но рекомендуется)
read -p "Выполнить полное обновление системы (full-upgrade)? Рекомендуется для ядра. (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Обновление системы...${NC}"
    sudo apt-get update && sudo apt-get full-upgrade -y
    echo -e "${YELLOW}⚠️  Если ядро было обновлено, рекомендуется перезагрузить систему после завершения скрипта.${NC}"
fi

# 2. Настройка deb-src в sources.list
echo -e "${YELLOW}Настройка репозиториев исходного кода (deb-src)...${NC}"
if ! grep -q "^deb-src" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    # Если deb-src не найден, пытаемся раскомментировать существующие строки
    sudo sed -i 's/# deb-src/deb-src/g' /etc/apt/sources.list
    echo -e "${GREEN}✓ Репозитории deb-src активированы${NC}"
else
    echo -e "${GREEN}✓ Репозитории deb-src уже настроены${NC}"
fi

# 3. Установка зависимостей
echo -e "${YELLOW}Установка необходимых пакетов...${NC}"
sudo apt-get update
sudo apt-get install -y \
    software-properties-common \
    python3-launchpadlib \
    gnupg2 \
    linux-headers-$(uname -r) || { echo -e "${RED}Ошибка установки зависимостей${NC}"; exit 1; }

# 4. Добавление PPA
echo -e "${YELLOW}Добавление Amnezia PPA...${NC}"
sudo add-apt-repository -y ppa:amnezia/ppa || { echo -e "${RED}Ошибка добавления PPA${NC}"; exit 1; }

# 5. Установка AmneziaWG
echo -e "${YELLOW}Установка amneziawg...${NC}"
sudo apt-get update
sudo apt-get install -y amneziawg || { echo -e "${RED}Ошибка установки amneziawg${NC}"; exit 1; }

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ AmneziaWG успешно установлен!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Теперь вы можете использовать утилиту ${GREEN}awg${NC} для настройки интерфейсов."
echo -e "Конфиги обычно лежат в: ${BLUE}/etc/amnezia/amneziawg/${NC}"
