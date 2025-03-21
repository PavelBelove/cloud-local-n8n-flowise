#!/bin/bash

# Получаем переменные из основного скрипта через аргументы
USER_EMAIL=$1
DOMAIN_NAME=$2

if [ -z "$USER_EMAIL" ] || [ -z "$DOMAIN_NAME" ]; then
  echo "ОШИБКА: Не указан email или имя домена"
  echo "Использование: $0 user@example.com example.com"
  exit 1
fi

echo "Генерация секретных ключей и паролей..."

# Функция для генерации случайных строк
generate_random_string() {
  length=$1
  cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*()-_=+' | fold -w ${length} | head -n 1
}

# Генерация ключей и паролей
N8N_ENCRYPTION_KEY=$(generate_random_string 40)
if [ -z "$N8N_ENCRYPTION_KEY" ]; then
  echo "ОШИБКА: Не удалось сгенерировать ключ шифрования для n8n"
  exit 1
fi

N8N_USER_MANAGEMENT_JWT_SECRET=$(generate_random_string 40)
if [ -z "$N8N_USER_MANAGEMENT_JWT_SECRET" ]; then
  echo "ОШИБКА: Не удалось сгенерировать JWT секрет для n8n"
  exit 1
fi

N8N_PASSWORD=$(generate_random_string 16)
if [ -z "$N8N_PASSWORD" ]; then
  echo "ОШИБКА: Не удалось сгенерировать пароль для n8n"
  exit 1
fi

FLOWISE_PASSWORD=$(generate_random_string 16)
if [ -z "$FLOWISE_PASSWORD" ]; then
  echo "ОШИБКА: Не удалось сгенерировать пароль для Flowise"
  exit 1
fi

# Запись значений в файл .env
cat > .env << EOL
# Настройки для n8n
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
N8N_USER_MANAGEMENT_JWT_SECRET=$N8N_USER_MANAGEMENT_JWT_SECRET
N8N_DEFAULT_USER_EMAIL=$USER_EMAIL
N8N_DEFAULT_USER_PASSWORD=$N8N_PASSWORD

# Настройки для Flowise
FLOWISE_USERNAME=admin
FLOWISE_PASSWORD=$FLOWISE_PASSWORD

# Настройки домена
DOMAIN_NAME=$DOMAIN_NAME
EOL

if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось создать файл .env"
  exit 1
fi

echo "Сгенерированы секретные ключи и сохранены в файл .env"
echo "Пароль для n8n: $N8N_PASSWORD"
echo "Пароль для Flowise: $FLOWISE_PASSWORD"

# Сохраняем пароли для дальнейшего использования
echo "N8N_PASSWORD=$N8N_PASSWORD" > ./setup-files/passwords.txt
echo "FLOWISE_PASSWORD=$FLOWISE_PASSWORD" >> ./setup-files/passwords.txt

echo "✅ Секретные ключи и пароли успешно сгенерированы"
exit 0 