#!/bin/bash

echo "Запуск сервисов..."

# Проверяем наличие необходимых файлов
if [ ! -f "n8n-docker-compose.yaml" ]; then
  echo "ОШИБКА: Файл n8n-docker-compose.yaml не найден"
  exit 1
fi

if [ ! -f "flowise-docker-compose.yaml" ]; then
  echo "ОШИБКА: Файл flowise-docker-compose.yaml не найден"
  exit 1
fi

if [ ! -f ".env" ]; then
  echo "ОШИБКА: Файл .env не найден"
  exit 1
fi

# Запуск n8n и Caddy
echo "Запуск n8n и Caddy..."
sudo docker compose -f n8n-docker-compose.yaml up -d
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось запустить n8n и Caddy"
  exit 1
fi

# Подождем немного, пока создастся сеть
echo "Ожидание создания сети docker..."
sleep 5

# Проверяем, создалась ли сеть app-network
if ! sudo docker network inspect app-network &> /dev/null; then
  echo "ОШИБКА: Не удалось создать сеть app-network"
  exit 1
fi

# Запуск Flowise
echo "Запуск Flowise..."
sudo docker compose -f flowise-docker-compose.yaml up -d
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось запустить Flowise"
  exit 1
fi

# Проверка, что все контейнеры запущены
echo "Проверка запущенных контейнеров..."
sleep 5

if ! sudo docker ps | grep -q "n8n"; then
  echo "ОШИБКА: Контейнер n8n не запущен"
  exit 1
fi

if ! sudo docker ps | grep -q "caddy"; then
  echo "ОШИБКА: Контейнер caddy не запущен"
  exit 1
fi

if ! sudo docker ps | grep -q "flowise"; then
  echo "ОШИБКА: Контейнер flowise не запущен"
  exit 1
fi

echo "✅ Сервисы n8n, Flowise и Caddy успешно запущены"
exit 0 