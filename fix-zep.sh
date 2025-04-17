#!/bin/bash

# Function to display progress
show_progress() {
  echo ""
  echo "========================================================"
  echo "   $1"
  echo "========================================================"
  echo ""
}

show_progress "🔧 Исправление конфигурации Zep"

# Проверка существующих данных
if [ ! -f ".env" ] && [ ! -f "zep-passwords.txt" ]; then
  echo "❌ Не найден файл .env или zep-passwords.txt с переменными окружения"
  echo "Пожалуйста, убедитесь, что у вас есть необходимая информация для настройки Zep"
  exit 1
fi

# Загрузка переменных окружения
if [ -f ".env" ]; then
  echo "Загрузка переменных из .env"
  source .env
fi

if [ -f "zep-passwords.txt" ]; then
  echo "Загрузка переменных из zep-passwords.txt"
  source zep-passwords.txt
fi

# Проверка необходимых переменных
if [ -z "$ZEP_POSTGRES_USER" ] || [ -z "$ZEP_POSTGRES_PASSWORD" ] || [ -z "$ZEP_POSTGRES_DB" ] || [ -z "$OPENROUTER_API_KEY" ] || [ -z "$OPENROUTER_MODEL" ] || [ -z "$DOMAIN_NAME" ]; then
  echo "❌ Некоторые необходимые переменные окружения не найдены"
  
  # Запрашиваем недостающие данные
  if [ -z "$ZEP_POSTGRES_USER" ]; then
    read -p "Введите имя пользователя PostgreSQL для Zep (zep): " ZEP_POSTGRES_USER
    ZEP_POSTGRES_USER=${ZEP_POSTGRES_USER:-zep}
  fi
  
  if [ -z "$ZEP_POSTGRES_PASSWORD" ]; then
    read -p "Введите пароль PostgreSQL для Zep: " ZEP_POSTGRES_PASSWORD
    if [ -z "$ZEP_POSTGRES_PASSWORD" ]; then
      echo "Пароль PostgreSQL не может быть пустым"
      exit 1
    fi
  fi
  
  if [ -z "$ZEP_POSTGRES_DB" ]; then
    read -p "Введите имя базы данных PostgreSQL для Zep (zep): " ZEP_POSTGRES_DB
    ZEP_POSTGRES_DB=${ZEP_POSTGRES_DB:-zep}
  fi
  
  if [ -z "$OPENROUTER_API_KEY" ]; then
    read -p "Введите API ключ OpenRouter: " OPENROUTER_API_KEY
    if [ -z "$OPENROUTER_API_KEY" ]; then
      echo "API ключ OpenRouter не может быть пустым"
      exit 1
    fi
  fi
  
  if [ -z "$OPENROUTER_MODEL" ]; then
    read -p "Введите модель OpenRouter (meta-llama/llama-4-maverick:free): " OPENROUTER_MODEL
    OPENROUTER_MODEL=${OPENROUTER_MODEL:-"meta-llama/llama-4-maverick:free"}
  fi
  
  if [ -z "$DOMAIN_NAME" ]; then
    read -p "Введите доменное имя (например, example.com): " DOMAIN_NAME
    if [ -z "$DOMAIN_NAME" ]; then
      echo "Доменное имя не может быть пустым"
      exit 1
    fi
  fi
fi

# Остановка существующих контейнеров
show_progress "Остановка существующих контейнеров Zep"
docker compose -f zep-docker-compose.yaml down
echo "✅ Контейнеры остановлены"

# Резервное копирование docker-compose
if [ -f "zep-docker-compose.yaml" ]; then
  cp zep-docker-compose.yaml zep-docker-compose.yaml.bak
  echo "✅ Резервная копия zep-docker-compose.yaml создана как zep-docker-compose.yaml.bak"
fi

# Создание обновленного docker-compose файла
show_progress "Создание обновленного docker-compose файла"
cat > zep-docker-compose.yaml << EOL
version: '3'

services:
  zep:
    image: ghcr.io/getzep/zep:latest
    container_name: zep
    restart: unless-stopped
    environment:
      - ZEP_STORE_TYPE=postgres
      - ZEP_MEMORY_STORE_TYPE=postgres
      - ZEP_MEMORY_STORE_POSTGRES_DSN=postgres://${ZEP_POSTGRES_USER}:${ZEP_POSTGRES_PASSWORD}@zep-postgres:5432/${ZEP_POSTGRES_DB}?sslmode=disable
      - ZEP_VECTOR_STORE_TYPE=qdrant
      - ZEP_VECTOR_STORE_QDRANT_URL=http://qdrant:6333
      - ZEP_OPENAI_API_KEY=${OPENROUTER_API_KEY}
      - ZEP_OPENAI_API_BASE=https://openrouter.ai/api/v1
      - ZEP_OPENAI_EMBEDDINGS_MODEL=sentence-transformers/all-MiniLM-L6-v2
      - ZEP_OPENAI_CHAT_MODEL=${OPENROUTER_MODEL}
      - ZEP_SERVER_BASE_URL=https://zep.${DOMAIN_NAME}
    mem_limit: 512m
    cpus: 0.5
    volumes:
      - /opt/zep/data:/data
    networks:
      - app-network

  zep-postgres:
    image: postgres:15
    container_name: zep-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${ZEP_POSTGRES_USER}
      - POSTGRES_PASSWORD=${ZEP_POSTGRES_PASSWORD}
      - POSTGRES_DB=${ZEP_POSTGRES_DB}
    mem_limit: 512m
    cpus: 0.5
    volumes:
      - /opt/zep/postgres-data:/var/lib/postgresql/data
    networks:
      - app-network

  qdrant:
    image: qdrant/qdrant:latest
    container_name: qdrant
    restart: unless-stopped
    mem_limit: 1g
    cpus: 0.5
    volumes:
      - /opt/zep/qdrant-data:/qdrant/storage
    networks:
      - app-network

networks:
  app-network:
    external: true
EOL
echo "✅ Конфигурация обновлена"

# Сохранение переменных окружения в файл zep-passwords.txt
cat > zep-passwords.txt << EOL
ZEP_POSTGRES_USER="${ZEP_POSTGRES_USER}"
ZEP_POSTGRES_PASSWORD="${ZEP_POSTGRES_PASSWORD}"
ZEP_POSTGRES_DB="${ZEP_POSTGRES_DB}"
OPENROUTER_API_KEY="${OPENROUTER_API_KEY}"
OPENROUTER_MODEL="${OPENROUTER_MODEL}"
DOMAIN_NAME="${DOMAIN_NAME}"
EOL
echo "✅ Переменные окружения сохранены в zep-passwords.txt"

# Запуск обновленных контейнеров
show_progress "Запуск обновленных контейнеров"
docker compose -f zep-docker-compose.yaml up -d
echo "✅ Контейнеры запущены"

# Проверка статуса
sleep 5
if docker ps | grep -q "zep" && ! docker ps | grep -q "Restarting.*zep"; then
  show_progress "✅ Zep успешно запущен и работает"
  echo "Zep доступен по адресу: https://zep.${DOMAIN_NAME}"
  echo "API Endpoint: https://zep.${DOMAIN_NAME}/api"
else
  show_progress "⚠️ Zep не запустился или находится в состоянии перезапуска"
  echo "Проверьте логи с помощью команды:"
  echo "docker compose -f zep-docker-compose.yaml logs zep"
fi

# Вывод инструкций
echo ""
echo "Для дальнейшей отладки можно использовать:"
echo "- Логи: docker compose -f zep-docker-compose.yaml logs"
echo "- Статус: docker compose -f zep-docker-compose.yaml ps"
echo "- Перезапуск: docker compose -f zep-docker-compose.yaml restart" 