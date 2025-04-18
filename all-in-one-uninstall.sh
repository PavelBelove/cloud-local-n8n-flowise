#!/bin/bash

# Проверка запуска от имени root
if [ "$(id -u)" != "0" ]; then
   echo "Этот скрипт должен быть запущен с правами root" 
   echo "Используйте: sudo $0"
   exit 1
fi

echo "Начинаем удаление всех компонентов..."
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$SCRIPT_DIR"

# Запрос подтверждения перед удалением
read -p "Вы уверены, что хотите удалить все компоненты? Это действие невозможно отменить (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
  echo "Удаление отменено"
  exit 0
fi

# Запрос подтверждения перед удалением папки проекта
read -p "Удалить папку проекта после очистки? (y/n): " REMOVE_DIR
if [ "$REMOVE_DIR" != "y" ]; then
  echo "Папка проекта не будет удалена"
fi

# Остановка и удаление всех контейнеров
echo "Останавливаем и удаляем контейнеры..."
docker stop n8n flowise zep caddy crawl4ai postgres zep-postgres qdrant 2>/dev/null || true
docker rm n8n flowise zep caddy crawl4ai postgres zep-postgres qdrant 2>/dev/null || true

# Удаление Docker volumes
echo "Удаляем Docker volumes..."
docker volume rm n8n_data caddy_data caddy_config postgres_data 2>/dev/null || true

# Удаление Docker сетей
echo "Удаляем Docker сети..."
docker network rm app-network 2>/dev/null || true

# Удаление созданных директорий
echo "Удаляем созданные директории..."
rm -rf /opt/n8n /opt/flowise /opt/zep 2>/dev/null || true

# Удаление файлов
echo "Удаляем файлы..."
rm -f n8n-docker-compose.yaml flowise-docker-compose.yaml zep-docker-compose.yaml crawl4ai-docker-compose.yaml 2>/dev/null || true
rm -f .env 2>/dev/null || true

# Очистка Docker
echo "Очищаем Docker..."
docker system prune -af

# Удаление папки проекта, если запрошено
if [ "$REMOVE_DIR" == "y" ]; then
  echo "Удаляем папку проекта..."
  cd "$PARENT_DIR"
  rm -rf "$SCRIPT_DIR"
  echo "✅ Удаление успешно завершено! Папка проекта удалена."
else
  echo "✅ Удаление успешно завершено! Папка проекта сохранена."
fi

exit 0 