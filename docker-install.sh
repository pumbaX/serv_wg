#!/bin/bash

# Скрипт для автоматической установки Docker Engine и Docker Compose на Ubuntu
# Версия: 3.0 (с Docker Compose)

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${GREEN}=== Установка Docker и Docker Compose ===${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${YELLOW}ОС: $NAME $VERSION${NC}"
echo -e "${YELLOW}Архитектура: $(uname -m)${NC}"
echo ""

# Проверка аргументов командной строки
AUTO_MODE=false
INSTALL_COMPOSE=true
COMPOSE_TYPE="plugin"  # plugin или standalone

for arg in "$@"; do
    case $arg in
        -y|--yes)
            AUTO_MODE=true
            ;;
        --no-compose)
            INSTALL_COMPOSE=false
            ;;
        --compose-plugin)
            COMPOSE_TYPE="plugin"
            ;;
        --compose-standalone)
            COMPOSE_TYPE="standalone"
            ;;
        *)
            ;;
    esac
done

# 1. Удаление старых/конфликтующих пакетов
echo -e "${YELLOW}[1/8] Удаление конфликтующих пакетов...${NC}"
sudo apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc 2>/dev/null || true
sudo apt-get autoremove -y 2>/dev/null || true
echo -e "${GREEN}✓ Старые пакеты удалены${NC}"

# 2. Обновление пакетов
echo -e "${YELLOW}[2/8] Обновление системы...${NC}"
sudo apt-get update || error_exit "Не удалось обновить список пакетов"
sudo apt-get upgrade -y || echo -e "${YELLOW}⚠️  Не удалось обновить пакеты, продолжаем...${NC}"
echo -e "${GREEN}✓ Система обновлена${NC}"

# 3. Установка зависимостей
echo -e "${YELLOW}[3/8] Установка зависимостей...${NC}"
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    jq \
    || error_exit "Не удалось установить зависимости"
echo -e "${GREEN}✓ Зависимости установлены${NC}"

# 4. Добавление GPG-ключа Docker
echo -e "${YELLOW}[4/8] Добавление GPG-ключа Docker...${NC}"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo -e "${GREEN}✓ GPG-ключ добавлен${NC}"

# 5. Добавление репозитория Docker
echo -e "${YELLOW}[5/8] Добавление репозитория Docker...${NC}"
ARCH=$(dpkg --print-architecture)
CODENAME=${VERSION_CODENAME}
if [[ -z "$CODENAME" ]]; then
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
echo -e "${YELLOW}[6/8] Установка Docker...${NC}"
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    || error_exit "Не удалось установить Docker"
echo -e "${GREEN}✓ Docker установлен${NC}"

# 7. Установка Docker Compose
if [[ "$INSTALL_COMPOSE" = true ]]; then
    echo -e "${YELLOW}[7/8] Установка Docker Compose...${NC}"
    
    if [[ "$AUTO_MODE" = false ]] && [[ -z "$COMPOSE_TYPE" ]]; then
        echo -e "${BLUE}Выберите тип Docker Compose:${NC}"
        echo "  1) Docker Compose Plugin (рекомендуется)"
        echo "     Команда: docker compose (без дефиса)"
        echo "  2) Standalone Docker Compose"
        echo "     Команда: docker-compose (с дефисом)"
        echo "  3) Оба варианта"
        read -p "Ваш выбор (1-3): " COMPOSE_CHOICE
        
        case $COMPOSE_CHOICE in
            1) COMPOSE_TYPE="plugin" ;;
            2) COMPOSE_TYPE="standalone" ;;
            3) COMPOSE_TYPE="both" ;;
            *) COMPOSE_TYPE="plugin" ;;
        esac
    fi
    
    # Установка плагина (если выбран plugin или both)
    if [[ "$COMPOSE_TYPE" = "plugin" ]] || [[ "$COMPOSE_TYPE" = "both" ]]; then
        echo -e "${YELLOW}Установка Docker Compose Plugin...${NC}"
        sudo apt-get install -y docker-compose-plugin
        echo -e "${GREEN}✓ Docker Compose Plugin установлен${NC}"
    fi
    
    # Установка standalone (если выбран standalone или both)
    if [[ "$COMPOSE_TYPE" = "standalone" ]] || [[ "$COMPOSE_TYPE" = "both" ]]; then
        echo -e "${YELLOW}Установка Docker Compose Standalone...${NC}"
        
        # Получаем последнюю версию
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')
        
        if [[ -z "$COMPOSE_VERSION" ]] || [[ "$COMPOSE_VERSION" = "null" ]]; then
            # Fallback если jq не сработал
            COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        fi
        
        echo "Скачиваем Docker Compose $COMPOSE_VERSION..."
        
        # Скачиваем
        sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
            
        # Права на выполнение
        sudo chmod +x /usr/local/bin/docker-compose
        
        # Создаем симлинк для доступа из PATH
        if [[ ! -f /usr/bin/docker-compose ]]; then
            sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        fi
        
        echo -e "${GREEN}✓ Docker Compose Standalone $COMPOSE_VERSION установлен${NC}"
    fi
    
    # Проверка установки Docker Compose
    echo -e "${YELLOW}Проверка Docker Compose...${NC}"
    
    # Проверяем плагин
    if docker compose version &>/dev/null; then
        COMPOSE_PLUGIN_VERSION=$(docker compose version 2>/dev/null | head -1)
        echo -e "${GREEN}✓ Docker Compose Plugin: $COMPOSE_PLUGIN_VERSION${NC}"
    fi
    
    # Проверяем standalone
    if command -v docker-compose &>/dev/null; then
        COMPOSE_STANDALONE_VERSION=$(docker-compose --version 2>/dev/null)
        echo -e "${GREEN}✓ Docker Compose Standalone: $COMPOSE_STANDALONE_VERSION${NC}"
    fi
    
    if ! docker compose version &>/dev/null && ! command -v docker-compose &>/dev/null; then
        echo -e "${YELLOW}⚠️  Docker Compose не установлен или не найден в PATH${NC}"
    fi
else
    echo -e "${YELLOW}[7/8] Пропускаем установку Docker Compose${NC}"
fi

# 8. Настройка службы Docker
echo -e "${YELLOW}[8/8] Настройка службы Docker...${NC}"
sudo systemctl enable docker || echo -e "${YELLOW}⚠️  Не удалось включить автозагрузку docker${NC}"
sudo systemctl start docker || error_exit "Не удалось запустить службу Docker"

# Проверяем что Docker запущен
if sudo systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Docker служба запущена${NC}"
else
    error_exit "Docker служба не запущена"
fi

# Проверка установки Docker
echo -e "${YELLOW}Проверка установки Docker...${NC}"
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

# Тестирование Docker Compose
if [[ "$INSTALL_COMPOSE" = true ]]; then
    echo -e "${YELLOW}Тестирование Docker Compose...${NC}"
    
    # Создаем простой docker-compose.yml для теста
    cat > /tmp/test-docker-compose.yml << 'EOF'
version: '3'
services:
  web:
    image: nginx:alpine
    ports:
      - "8888:80"
EOF
    
    # Пробуем разные команды
    if docker compose version &>/dev/null; then
        echo -e "${GREEN}✓ Docker Compose Plugin работает${NC}"
    elif command -v docker-compose &>/dev/null; then
        echo -e "${GREEN}✓ Docker Compose Standalone работает${NC}"
    fi
    
    rm -f /tmp/test-docker-compose.yml
fi

echo -e "${BLUE}═════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Docker и Docker Compose успешно установлены!${NC}"
echo -e "${BLUE}═════════════════════════════════════════════════${NC}"

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
echo -e "${GREEN}📦 Полезные команды:${NC}"
echo -e "${BLUE}▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬${NC}"

echo -e "${PURPLE}🐳 Docker:${NC}"
echo -e "  Проверить версию:        ${GREEN}docker --version${NC}"
echo -e "  Проверить статус:        ${GREEN}sudo systemctl status docker${NC}"
echo -e "  Тестовый контейнер:      ${GREEN}docker run hello-world${NC}"
echo -e "  Показать образы:         ${GREEN}docker images${NC}"
echo -e "  Показать контейнеры:     ${GREEN}docker ps -a${NC}"

if docker compose version &>/dev/null; then
    echo -e "${PURPLE}📦 Docker Compose Plugin:${NC}"
    echo -e "  Проверить версию:        ${GREEN}docker compose version${NC}"
    echo -e "  Запуск проекта:          ${GREEN}docker compose up -d${NC}"
    echo -e "  Остановка проекта:       ${GREEN}docker compose down${NC}"
    echo -e "  Просмотр логов:          ${GREEN}docker compose logs${NC}"
elif command -v docker-compose &>/dev/null; then
    echo -e "${PURPLE}📦 Docker Compose Standalone:${NC}"
    echo -e "  Проверить версию:        ${GREEN}docker-compose --version${NC}"
    echo -e "  Запуск проекта:          ${GREEN}docker-compose up -d${NC}"
    echo -e "  Остановка проекта:       ${GREEN}docker-compose down${NC}"
    echo -e "  Просмотр логов:          ${GREEN}docker-compose logs${NC}"
fi

echo -e "${BLUE}▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬${NC}"
echo ""
echo -e "${YELLOW}📝 Примечание:${NC}"
echo -e "Для использования docker без sudo выполните перезагрузку сессии"
echo "или команду: ${BLUE}newgrp docker${NC}"
echo ""
