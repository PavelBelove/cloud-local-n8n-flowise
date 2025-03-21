#!/bin/bash

echo "Настройка директорий и пользователей..."

# Создание пользователя n8n, если он не существует
if ! id "n8n" &>/dev/null; then
  echo "Создание пользователя n8n..."
  sudo adduser --disabled-password --gecos "" n8n
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось создать пользователя n8n"
    exit 1
  fi
  
  # Генерация случайного пароля
  N8N_PASSWORD=$(openssl rand -base64 12)
  echo "n8n:$N8N_PASSWORD" | sudo chpasswd
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось установить пароль для пользователя n8n"
    exit 1
  fi
  
  echo "✅ Создан пользователь n8n с паролем: $N8N_PASSWORD"
  echo "⚠️ ВАЖНО: Запишите этот пароль, он вам понадобится для работы с Docker!"
  
  sudo usermod -aG docker n8n
  if [ $? -ne 0 ]; then
    echo "ПРЕДУПРЕЖДЕНИЕ: Не удалось добавить пользователя n8n в группу docker"
    # Не выходим, так как это не критическая ошибка
  fi
else
  echo "Пользователь n8n уже существует"
  
  # Если пользователь существует, но нужно сбросить пароль
  read -p "Хотите сбросить пароль для пользователя n8n? (y/n): " reset_password
  if [ "$reset_password" = "y" ]; then
    N8N_PASSWORD=$(openssl rand -base64 12)
    echo "n8n:$N8N_PASSWORD" | sudo chpasswd
    if [ $? -ne 0 ]; then
      echo "ОШИБКА: Не удалось сбросить пароль для пользователя n8n"
    else
      echo "✅ Пароль для пользователя n8n сброшен: $N8N_PASSWORD"
      echo "⚠️ ВАЖНО: Запишите этот пароль, он вам понадобится для работы с Docker!"
    fi
  fi
fi

# Создание необходимых директорий
echo "Создание директорий..."
sudo mkdir -p /opt/n8n
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось создать директорию /opt/n8n"
  exit 1
fi

sudo mkdir -p /opt/n8n/files
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось создать директорию /opt/n8n/files"
  exit 1
fi

sudo mkdir -p /opt/flowise
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось создать директорию /opt/flowise"
  exit 1
fi

# Установка прав
sudo chown -R n8n:n8n /opt/n8n
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось изменить владельца директории /opt/n8n"
  exit 1
fi

sudo chown -R n8n:n8n /opt/flowise
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось изменить владельца директории /opt/flowise"
  exit 1
fi

# Создание docker volumes
echo "Создание Docker volumes..."
sudo docker volume create n8n_data
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось создать Docker volume n8n_data"
  exit 1
fi

sudo docker volume create caddy_data
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось создать Docker volume caddy_data"
  exit 1
fi

echo "✅ Директории и пользователи успешно настроены"
exit 0 