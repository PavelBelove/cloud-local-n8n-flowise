#!/bin/bash

echo "Настройка брандмауэра..."

# Проверяем, установлен ли ufw
if command -v ufw &> /dev/null; then
  echo "UFW уже установлен, открываем необходимые порты..."
  
  # Открываем порты
  sudo ufw allow 80
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось открыть порт 80"
    exit 1
  fi
  
  sudo ufw allow 443
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось открыть порт 443"
    exit 1
  fi
  
  # Проверяем, активен ли ufw
  sudo ufw status | grep -q "Status: active"
  if [ $? -ne 0 ]; then
    echo "UFW не активен, активируем..."
    sudo ufw --force enable
    if [ $? -ne 0 ]; then
      echo "ОШИБКА: Не удалось активировать UFW"
      exit 1
    fi
  fi
  
  echo "Порты 80 и 443 открыты в брандмауэре"
else
  echo "UFW не установлен. Установка..."
  sudo apt-get install -y ufw
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось установить UFW"
    exit 1
  fi
  
  # Открываем порты
  sudo ufw allow 80
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось открыть порт 80"
    exit 1
  fi
  
  sudo ufw allow 443
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось открыть порт 443"
    exit 1
  fi
  
  # Активируем брандмауэр
  sudo ufw --force enable
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось активировать UFW"
    exit 1
  fi
  
  echo "Брандмауэр установлен и порты 80, 443 открыты"
fi

echo "✅ Брандмауэр успешно настроен"
exit 0 