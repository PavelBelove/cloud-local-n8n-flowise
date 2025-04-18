#!/bin/bash

# Проверка запуска от имени root
if [ "$(id -u)" != "0" ]; then
   echo "Этот скрипт должен быть запущен с правами root" 
   echo "Используйте: sudo $0"
   exit 1
fi

# Определение текущей директории
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR"

echo "Устанавливаем все сервисы..."

# Удаление старых контейнеров если они есть
echo "Удаляем старые контейнеры..."
docker stop n8n flowise zep caddy crawl4ai postgres 2>/dev/null || true
docker rm n8n flowise zep caddy crawl4ai postgres 2>/dev/null || true
docker network rm app-network 2>/dev/null || true

# Создание директорий
echo "Создаем директории..."
mkdir -p /opt/n8n/files
mkdir -p /opt/flowise
mkdir -p /opt/zep

# Создание Docker сети
echo "Создаем Docker сеть..."
docker network create app-network

# Генерация случайных паролей
N8N_PASSWORD=$(tr -dc 'A-Za-z0-9!#$%&*+' < /dev/urandom | head -c 20)
FLOWISE_PASSWORD=$(tr -dc 'A-Za-z0-9!#$%&*+' < /dev/urandom | head -c 20)
ENCRYPTION_KEY=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
SECRET_KEY=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)

# Создание .env файла
echo "Создаем .env файл..."
cat > .env << EOL
# N8N
N8N_ENCRYPTION_KEY=$ENCRYPTION_KEY
N8N_USER_MANAGEMENT_JWT_SECRET=$SECRET_KEY
N8N_DEFAULT_USER_EMAIL=admin@example.com
N8N_DEFAULT_USER_PASSWORD=$N8N_PASSWORD

# Flowise
FLOWISE_USERNAME=admin
FLOWISE_PASSWORD=$FLOWISE_PASSWORD

# Система
TIMEZONE=Europe/Moscow
EOL

# Создание Caddyfile
echo "Создаем Caddyfile..."
cat > /opt/n8n/Caddyfile << EOL
localhost {
    reverse_proxy n8n:5678
}

flowise.localhost {
    reverse_proxy flowise:3001
}

zep.localhost {
    reverse_proxy zep:8000
}

crawl4ai.localhost {
    reverse_proxy crawl4ai:11235
}
EOL

# Создание docker-compose файлов
echo "Создаем docker-compose файлы..."

# n8n
cat > n8n-docker-compose.yaml << EOL
version: '3'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    environment:
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY}
      - N8N_USER_MANAGEMENT_DISABLED=false
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_PERSONALIZATION_ENABLED=false
      - N8N_USER_MANAGEMENT_JWT_SECRET=\${N8N_USER_MANAGEMENT_JWT_SECRET}
      - N8N_DEFAULT_USER_EMAIL=\${N8N_DEFAULT_USER_EMAIL}
      - N8N_DEFAULT_USER_PASSWORD=\${N8N_DEFAULT_USER_PASSWORD}
      - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
    volumes:
      - n8n_data:/home/node/.n8n
      - /opt/n8n/files:/files
    networks:
      - app-network

  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    ports:
      - 80:80
      - 443:443
    volumes:
      - /opt/n8n/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - app-network

volumes:
  n8n_data:
  caddy_data:
  caddy_config:

networks:
  app-network:
    external: true
EOL

# Flowise
cat > flowise-docker-compose.yaml << EOL
version: '3'

services:
  flowise:
    image: flowiseai/flowise
    restart: unless-stopped
    container_name: flowise
    environment:
      - PORT=3001
      - FLOWISE_USERNAME=\${FLOWISE_USERNAME}
      - FLOWISE_PASSWORD=\${FLOWISE_PASSWORD}
    volumes:
      - /opt/flowise:/root/.flowise
    networks:
      - app-network

networks:
  app-network:
    external: true
EOL

# Zep
cat > zep-docker-compose.yaml << EOL
version: '3'

services:
  zep:
    image: ghcr.io/getzep/zep-cloud:latest
    container_name: zep
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      # Store configuration
      - ZEP_STORE_TYPE=postgres
      - ZEP_MEMORY_STORE_POSTGRES_DSN=postgres://postgres:postgres@postgres:5432/postgres?sslmode=disable
      # NLP configuration
      - ZEP_NLP_SERVER_TYPE=local
    networks:
      - app-network
    depends_on:
      - postgres

  postgres:
    image: postgres:latest
    container_name: zep-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_USER=postgres
      - POSTGRES_DB=postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app-network

volumes:
  postgres_data:

networks:
  app-network:
    external: true
EOL

# Crawl4AI
cat > crawl4ai-docker-compose.yaml << EOL
version: '3'

services:
  crawl4ai:
    image: unclecode/crawl4ai:basic
    container_name: crawl4ai
    restart: unless-stopped
    ports:
      - "11235:11235"
    volumes:
      - /dev/shm:/dev/shm
    networks:
      - app-network

networks:
  app-network:
    external: true
EOL

# Запуск всех сервисов
echo "Запускаем сервисы..."
source .env

# N8N и Caddy
echo "Запускаем N8N и Caddy..."
docker compose -f n8n-docker-compose.yaml up -d
sleep 5

# Flowise
echo "Запускаем Flowise..."
docker compose -f flowise-docker-compose.yaml up -d
sleep 5

# Zep
echo "Запускаем Zep..."
docker compose -f zep-docker-compose.yaml up -d
sleep 5

# Crawl4AI
echo "Запускаем Crawl4AI..."
docker compose -f crawl4ai-docker-compose.yaml up -d
sleep 5

# Проверка статуса
echo "Проверяем статус контейнеров..."
if docker ps | grep -q "Restarting\|Exit"; then
  echo "⚠️ Внимание: Некоторые контейнеры не запустились. Проверьте логи."
else
  echo "✅ Все контейнеры запущены успешно!"
fi

# Вывод доступов
echo ""
echo "✅ Установка завершена!"
echo "Доступы к сервисам:"
echo "N8N: http://localhost"
echo "Логин: admin@example.com"
echo "Пароль: $N8N_PASSWORD"
echo ""
echo "Flowise: http://flowise.localhost"
echo "Логин: admin"
echo "Пароль: $FLOWISE_PASSWORD"
echo ""
echo "Zep: http://zep.localhost"
echo ""
echo "Crawl4AI: http://crawl4ai.localhost или http://localhost:11235"

exit 0 