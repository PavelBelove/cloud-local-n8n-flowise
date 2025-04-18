#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR/.."

# Остановка и удаление контейнеров
echo "Останавливаем и удаляем контейнеры..."
sudo docker stop n8n flowise zep caddy crawl4ai || true
sudo docker rm n8n flowise zep caddy crawl4ai || true

# Удаление неиспользуемых образов и сетей
echo "Удаляем неиспользуемые образы и сети..."
sudo docker system prune -f

echo "Очистка Docker завершена" 