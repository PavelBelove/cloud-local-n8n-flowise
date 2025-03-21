#!/bin/bash

echo "Установка Docker и Docker Compose..."

# Опции apt для автоматического подтверждения и предотвращения запросов
APT_OPTIONS="-o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef -y"

# Проверяем, установлен ли Docker
if ! [ -x "$(command -v docker)" ]; then
  echo "Docker не установлен. Установка Docker..."
  
  # Обновление системы
  sudo apt-get update
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось обновить список пакетов"
    exit 1
  fi
  
  # Установка необходимых пакетов
  sudo apt-get install -y ca-certificates curl gnupg lsb-release $APT_OPTIONS
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось установить необходимые пакеты"
    exit 1
  fi
  
  # Создание директории для ключей
  sudo install -m 0755 -d /etc/apt/keyrings
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось создать директорию для ключей"
    exit 1
  fi
  
  # Загрузка GPG ключа Docker
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось загрузить GPG ключ Docker"
    exit 1
  fi
  
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  
  # Добавление репозитория Docker
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось добавить репозиторий Docker"
    exit 1
  fi
  
  # Обновление пакетов
  sudo apt-get update
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось обновить список пакетов после добавления репозитория Docker"
    exit 1
  fi
  
  # Установка Docker
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin $APT_OPTIONS
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось установить Docker"
    exit 1
  fi
  
  # Добавление текущего пользователя в группу docker
  sudo usermod -aG docker $USER
  if [ $? -ne 0 ]; then
    echo "ПРЕДУПРЕЖДЕНИЕ: Не удалось добавить пользователя в группу docker. Возможно потребуются права root для запуска docker."
  fi
  
  echo "Docker успешно установлен"
else
  echo "Docker уже установлен"
fi

# Проверка работы Docker
docker --version
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Docker установлен, но не работает корректно"
  exit 1
fi

echo "✅ Docker и Docker Compose успешно установлены и работают"
exit 0 