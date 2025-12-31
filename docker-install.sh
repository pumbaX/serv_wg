#!/bin/bash

# Скрипт для автоматической установки Docker Engine на Ubuntu
# Версия: 2.0 (исправленная и оптимизированная)

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода ошибок
error_exit() {
    echo -e "${RED}[ОШИБКА] $1${NC}" >&2
    exit 1
}

# Функция для проверки прав
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  Внимание: Скрипт запущен от root. Рекомендуется запускать от обычного пользователя.${NC}"
        read -p "Продолжить? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Проверка на Ubuntu
if ! [[ -f /etc/os-release ]]; then
    error_exit "Не удалось определить дистрибутив Linux"
fi

# Загружаем информацию о системе
source /etc/os-release
if [[ "$ID" != "ubuntu" ]]; then
    echo -e "${YELLOW}⚠️  Внимание: Скрипт предназначен для Ubuntu. Текущий дистрибутив: $ID${NC}"
    read -p "Продолжить установку? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}=== Автоматическая установка Docker ===${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}ОС: $NAME $VERSION${NC}"
echo -e "${YELLOW}Архитектура: $(uname -m)${NC}"
echo ""

# Проверка аргументов командной строки
AUTO_MODE=false
for arg in "$@"; do
    case $arg in
        -y|--yes)
            AUTO_MODE=true
            ;;
        *)
            ;;
    esac
done

# 1. Удаление старых/конфликтующих пакетов (упрощенная версия)
echo -e "${YELLOW}[1/7] Удаление конфликтующих пакетов...${NC}"
sudo apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc 2>/dev/null || true
sudo apt-get autoremove -y 2>/dev/null || true
echo -e "${GREEN}✓ Старые пакеты удалены${NC}"

# 2. Обновление пакетов
echo -e "${YELLOW}[2/7] Обновление системы...${NC}"
sudo apt-get update || error_exit "Не удалось обновить список пакетов"
sudo apt-get upgrade -y || echo -e "${YELLOW}⚠️  Не удалось обновить пакеты, продолжаем...${NC}"
echo -e "${GREEN}✓ Система обновлена${NC}"

# 3. Установка зависимостей
echo -e "${YELLOW}[3/7] Установка зависимостей...${NC}"
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    || error_exit "Не удалось установить зависимости"
echo -e "${GREEN}✓ Зависимости установлены${NC}"

# 4. Добавление GPG-ключа Docker (исправленная версия)
echo -e "${YELLOW}[4/7] Добавление GPG-ключа Docker...${NC}"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo -e "${GREEN}✓ GPG-ключ добавлен${NC}"

# 5. Добавление репозитория Docker (исправленная версия)
echo -e "${YELLOW}[5/7] Добавление репозитория Docker...${NC}"
# Используем переменную из /etc/os-release
ARCH=$(dpkg --print-architecture)
CODENAME=${VERSION_CODENAME}
if [[ -z "$CODENAME" ]]; then
    # Fallback на lsb_release если VERSION_CODENAME не определилась
    CODENAME=$(lsb_release -cs)
fi

echo "Архитектура: $ARCH"
echo "Кодовое имя: $CODENAME"

echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
echo -e "${GREEN}✓ Репозиторий добавлен${NC}"

# Обновляем список пакетов
echo -e "${YELLOW}Обновление списка пакетов...${NC}"
sudo apt-get update || error_exit "Не удалось обновить список пакетов с репозиторием Docker"

# 6. Установка Docker
echo -e "${YELLOW}[6/7] Установка Docker...${NC}"
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    || error_exit "Не удалось установить Docker"
echo -e "${GREEN}✓ Docker установлен${NC}"

# 7. Настройка службы Docker
echo -e "${YELLOW}[7/7] Настройка службы Docker...${NC}"
sudo systemctl enable docker || echo -e "${YELLOW}⚠️  Не удалось включить автозагрузку docker${NC}"
sudo systemctl start docker || error_exit "Не удалось запустить службу Docker"

# Проверяем что Docker запущен
if sudo systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Docker служба запущена${NC}"
else
    error_exit "Docker служба не запущена"
fi

# Проверка установки
echo -e "${YELLOW}Проверка установки...${NC}"
DOCKER_VERSION=$(sudo docker --version 2>/dev/null)
if [[ -n "$DOCKER_VERSION" ]]; then
    echo -e "${GREEN}✓ $DOCKER_VERSION${NC}"
else
    error_exit "Docker CLI не работает"
fi

# Тестовый запуск hello-world
echo -e "${YELLOW}Тестирование Docker...${NC}"
if timeout 30 sudo docker run --rm hello-world > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker работает корректно!${NC}"
else
    echo -e "${YELLOW}⚠️  Не удалось запустить тестовый контейнер (возможно нет сети)${NC}"
    echo -e "${YELLOW}   Docker установлен, но требуется проверка подключения${NC}"
fi

echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}✅ Docker успешно установлен!${NC}"
echo -e "${BLUE}=================================${NC}"

# Добавление пользователя в группу docker
ADD_TO_GROUP=true
if [[ "$AUTO_MODE" = false ]]; then
    echo -e "${YELLOW}Добавить текущего пользователя ($USER) в группу docker?${NC}"
    echo -e "Это позволит запускать docker без sudo (y/n, по умолчанию y): "
    read -r response
    if [[ ! "$response" =~ ^([nN][oO]|[nN])$ ]]; then
        ADD_TO_GROUP=true
    else
        ADD_TO_GROUP=false
    fi
fi

if [[ "$ADD_TO_GROUP" = true ]]; then
    echo -e "${YELLOW}Добавление пользователя $USER в группу docker...${NC}"
    sudo groupadd -f docker
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✓ Пользователь $USER добавлен в группу docker${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  ВНИМАНИЕ: Для применения изменений:${NC}"
    echo -e "   1. Выйдите из системы и зайдите заново"
    echo -e "   2. Или выполните команду: ${BLUE}newgrp docker${NC}"
    echo -e "   3. Или перезапустите терминал/сессию"
    echo ""
fi

echo ""
echo -e "${GREEN}Установка завершена успешно!${NC}"
echo ""
echo -e "${BLUE}▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬${NC}"
echo -e "${GREEN}📦 Полезные команды Docker:${NC}"
echo -e "${BLUE}▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬${NC}"
echo -e "  Проверить версию:        ${GREEN}docker --version${NC}"
echo -e "  Проверить статус:        ${GREEN}sudo systemctl status docker${NC}"
echo -e "  Запустить тестовый контейнер: ${GREEN}docker run hello-world${NC}"
echo -e "  Показать образы:         ${GREEN}docker images${NC}"
echo -e "  Показать контейнеры:     ${GREEN}docker ps -a${NC}"
echo -e "  Показать информацию:     ${GREEN}docker info${NC}"
echo -e "${BLUE}▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬${NC}"
echo ""
echo -e "${YELLOW}📝 Примечание:${NC}"
echo -e "Для использования docker без sudo выполните перезагрузку сессии"
echo "или команду: ${BLUE}newgrp docker${NC}"
echo ""
