#!/bin/bash

# Скрипт для добавления переменных Zep в существующий .env файл

# Проверяем наличие необходимых прав
if [ "$EUID" -ne 0 ]; then
  if ! sudo -n true 2>/dev/null; then
    echo "Для выполнения этого скрипта требуются права администратора"
    echo "Введите пароль администратора при запросе"
  fi
fi

# Запрос OpenRouter API ключа
read -p "Введите ваш OpenRouter API ключ: " OPENROUTER_API_KEY
while [[ -z "$OPENROUTER_API_KEY" ]]; do
  echo "OpenRouter API ключ не может быть пустым"
  read -p "Введите ваш OpenRouter API ключ: " OPENROUTER_API_KEY
done

# Настройка модели по умолчанию с возможностью изменения
OPENROUTER_MODEL="meta-llama/llama-4-maverick:free"
read -p "Введите модель OpenRouter для использования (по умолчанию: ${OPENROUTER_MODEL}): " USER_MODEL
if [[ ! -z "$USER_MODEL" ]]; then
  OPENROUTER_MODEL=$USER_MODEL
fi

# Генерация безопасного пароля
generate_safe_password() {
  length=$1
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${length} | head -n 1
}

# Генерация данных для PostgreSQL
ZEP_POSTGRES_USER="zep"
ZEP_POSTGRES_PASSWORD=$(generate_safe_password 16)
ZEP_POSTGRES_DB="zep"

# Проверка наличия файла .env и добавление переменных
if [ -f ".env" ]; then
  echo "Файл .env найден, добавляем переменные Zep..."
  
  # Добавляем переменные Zep в .env файл
  cat >> .env << EOL

# Настройки Zep
ZEP_POSTGRES_USER=${ZEP_POSTGRES_USER}
ZEP_POSTGRES_PASSWORD=${ZEP_POSTGRES_PASSWORD}
ZEP_POSTGRES_DB=${ZEP_POSTGRES_DB}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
OPENROUTER_MODEL=${OPENROUTER_MODEL}
EOL

  echo "Переменные Zep добавлены в файл .env"
else
  echo "Файл .env не найден, создаем новый..."
  
  # Создаем новый .env файл с переменными Zep
  cat > .env << EOL
# Настройки Zep
ZEP_POSTGRES_USER=${ZEP_POSTGRES_USER}
ZEP_POSTGRES_PASSWORD=${ZEP_POSTGRES_PASSWORD}
ZEP_POSTGRES_DB=${ZEP_POSTGRES_DB}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
OPENROUTER_MODEL=${OPENROUTER_MODEL}
EOL

  echo "Файл .env создан с переменными Zep"
fi

# Создаем исправленный docker-compose файл с жестко заданными переменными
echo "Создаем исправленный файл docker-compose для Zep..."
cat > zep-docker-compose.yaml << EOL
version: '3'

services:
  zep:
    image: ghcr.io/getzep/zep:latest
    container_name: zep
    restart: unless-stopped
    environment:
      - ZEP_OPENAI_API_KEY=${OPENROUTER_API_KEY}
      - ZEP_OPENAI_API_BASE=https://openrouter.ai/api/v1
      - ZEP_OPENAI_EMBEDDINGS_MODEL=sentence-transformers/all-MiniLM-L6-v2
      - ZEP_OPENAI_CHAT_MODEL=${OPENROUTER_MODEL}
      - ZEP_MEMORY_STORE_POSTGRES_DSN=postgres://${ZEP_POSTGRES_USER}:${ZEP_POSTGRES_PASSWORD}@zep-postgres:5432/${ZEP_POSTGRES_DB}?sslmode=disable
      - ZEP_QDRANT_URL=http://qdrant:6333
      - ZEP_STORE_TYPE=postgres
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

echo "Файл zep-docker-compose.yaml создан"

# Остановка текущих контейнеров Zep
echo "Останавливаем текущие контейнеры Zep..."
sudo docker compose -f zep-docker-compose.yaml down

# Запуск контейнеров с новой конфигурацией
echo "Запускаем контейнеры Zep с новой конфигурацией..."
sudo docker compose -f zep-docker-compose.yaml up -d

echo "Готово! Zep должен запуститься с правильной конфигурацией."
echo "Для проверки статуса контейнеров выполните: docker compose -f zep-docker-compose.yaml ps"
echo "Для просмотра логов выполните: docker compose -f zep-docker-compose.yaml logs -f zep"
echo "Пароль PostgreSQL для Zep: ${ZEP_POSTGRES_PASSWORD}"
echo "Сохраните эту информацию в надежном месте!" 