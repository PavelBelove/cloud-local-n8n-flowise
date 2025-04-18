#!/bin/bash

# Проверка запуска от имени root
if [ "$(id -u)" != "0" ]; then
   echo "Этот скрипт должен быть запущен с правами root" 
   echo "Используйте: sudo $0"
   exit 1
fi

echo "Начинаем установку..."
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR"

# Запрос домена или использование localhost
read -p "Введите домен (или нажмите Enter для использования localhost): " DOMAIN_NAME
if [ -z "$DOMAIN_NAME" ]; then
  DOMAIN_NAME="localhost"
  echo "Используем домен: $DOMAIN_NAME"
fi

# Проверка архитектуры процессора
ARCH=$(uname -m)
echo "Определена архитектура процессора: $ARCH"
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  echo "ВНИМАНИЕ: Обнаружена ARM-архитектура. Возможно потребуются специальные образы Docker."
  read -p "Продолжить установку? (y/n): " CONTINUE
  if [ "$CONTINUE" != "y" ]; then
    echo "Установка отменена"
    exit 0
  fi
fi

# Последовательное выполнение скриптов
echo "Шаг 1: Обновление системы..."
bash setup-files/01-update-system.sh
if [ $? -ne 0 ]; then
  echo "Ошибка обновления системы"
  exit 1
fi

echo "Шаг 2: Установка Docker..."
bash setup-files/02-install-docker.sh
if [ $? -ne 0 ]; then
  echo "Ошибка установки Docker"
  exit 1
fi

echo "Шаг 3: Очистка Docker..."
bash setup-files/03-cleanup-docker.sh
if [ $? -ne 0 ]; then
  echo "Ошибка очистки Docker"
  exit 1
fi

echo "Шаг 4: Настройка директорий..."
bash setup-files/03-setup-directories.sh
if [ $? -ne 0 ]; then
  echo "Ошибка настройки директорий"
  exit 1
fi

echo "Шаг 5: Генерация секретов..."
bash setup-files/04-generate-secrets.sh
if [ $? -ne 0 ]; then
  echo "Ошибка генерации секретов"
  exit 1
fi

echo "Шаг 6: Создание шаблонов..."
bash setup-files/05-create-templates.sh "$DOMAIN_NAME"
if [ $? -ne 0 ]; then
  echo "Ошибка создания шаблонов"
  exit 1
fi

echo "Шаг 7: Настройка файрвола..."
bash setup-files/06-setup-firewall.sh
if [ $? -ne 0 ]; then
  echo "Ошибка настройки файрвола"
  exit 1
fi

# Проверка наличия сети Docker
echo "Проверка сети Docker..."
if ! sudo docker network ls | grep -q "app-network"; then
  echo "Создание сети app-network..."
  sudo docker network create app-network
  if [ $? -ne 0 ]; then
    echo "Ошибка создания сети app-network"
    exit 1
  fi
fi

echo "Шаг 8: Запуск сервисов..."
bash setup-files/07-start-services.sh
if [ $? -ne 0 ]; then
  echo "Ошибка запуска сервисов"
  exit 1
fi

echo "Шаг 9: Настройка Zep..."
bash setup-files/08-setup-zep.sh
if [ $? -ne 0 ]; then
  echo "Ошибка настройки Zep"
  exit 1
fi

# Проверка статуса контейнеров
echo "Проверка статуса контейнеров..."
if sudo docker ps -a | grep -q "Restarting\|Exit"; then
  echo "⚠️ Внимание: Некоторые контейнеры могут быть в состоянии перезапуска или завершены с ошибкой."
  echo "Проверьте логи с помощью: docker logs <имя_контейнера>"
else
  echo "✅ Все контейнеры запущены успешно!"
fi

echo "✅ Установка завершена!"
echo "Доступные сервисы:"
echo "- n8n: http://n8n.$DOMAIN_NAME"
echo "- Flowise: http://flowise.$DOMAIN_NAME"
echo "- Zep: http://zep.$DOMAIN_NAME"
echo "- Crawl4AI: http://crawl4ai.$DOMAIN_NAME или http://localhost:11235"

exit 0 