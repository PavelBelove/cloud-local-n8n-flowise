#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR/.."

# Установка переменных окружения
source .env

# Запуск Crawl4AI через Docker Compose
echo "Запускаем Crawl4AI..."
sudo docker compose -f crawl4ai-docker-compose.yaml up -d

echo "Crawl4AI запущен и доступен по адресу: http://localhost:11235" 