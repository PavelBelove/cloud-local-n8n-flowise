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
sudo docker stop n8n flowise zep caddy crawl4ai zep-postgres qdrant || true
sudo docker rm n8n flowise zep caddy crawl4ai zep-postgres qdrant || true

# Удаление Docker volumes
echo "Удаляем Docker volumes..."
sudo docker volume rm n8n_data caddy_data caddy_config crawl4ai_data || true

# Удаление Docker сетей
echo "Удаляем Docker сети..."
sudo docker network rm app-network || true

# Удаление созданных директорий
echo "Удаляем созданные директории..."
sudo rm -rf /opt/n8n /opt/flowise /opt/zep || true

# Удаление Docker-compose файлов
echo "Удаляем Docker-compose файлы..."
rm -f n8n-docker-compose.yaml flowise-docker-compose.yaml zep-docker-compose.yaml crawl4ai-docker-compose.yaml || true

# Удаление шаблонов
echo "Удаляем шаблоны..."
rm -f n8n-docker-compose.yaml.template flowise-docker-compose.yaml.template zep-docker-compose.yaml.template crawl4ai-docker-compose.yaml.template || true

# Удаление Caddyfile
echo "Удаляем Caddyfile..."
rm -f Caddyfile || true

# Удаление .env файла
echo "Удаляем файл .env..."
rm -f .env || true

# Очистка Docker
echo "Очищаем Docker от неиспользуемых ресурсов..."
sudo docker system prune -af

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