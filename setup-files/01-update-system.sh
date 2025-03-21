#!/bin/bash

echo "Обновление системы..."
# Установка переменной окружения для предотвращения интерактивных запросов
export DEBIAN_FRONTEND=noninteractive
# Опции apt для автоматического подтверждения и предотвращения запросов
APT_OPTIONS="-o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef -y"

sudo apt-get update
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось обновить список пакетов"
  exit 1
fi

sudo apt-get upgrade $APT_OPTIONS
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось обновить пакеты"
  exit 1
fi

sudo apt-get autoremove $APT_OPTIONS
sudo apt-get clean

echo "✅ Система успешно обновлена"
exit 0 