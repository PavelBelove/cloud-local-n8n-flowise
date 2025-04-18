#!/bin/bash

# Get variables from the main script via arguments
USER_EMAIL=$1
DOMAIN_NAME=$2
GENERIC_TIMEZONE=$3

if [ -z "$USER_EMAIL" ] || [ -z "$DOMAIN_NAME" ]; then
  echo "ERROR: Email or domain name not specified"
  echo "Usage: $0 user@example.com example.com [timezone]"
  exit 1
fi

if [ -z "$GENERIC_TIMEZONE" ]; then
  GENERIC_TIMEZONE="UTC"
fi

echo "Generating secret keys and passwords..."

# Function to generate random strings
generate_random_string() {
  length=$1
  cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*()-_=+' | fold -w ${length} | head -n 1
}

# Function to generate safe passwords (no special bash characters)
generate_safe_password() {
  length=$1
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${length} | head -n 1
}

# Generating keys and passwords
N8N_ENCRYPTION_KEY=$(generate_random_string 40)
if [ -z "$N8N_ENCRYPTION_KEY" ]; then
  echo "ERROR: Failed to generate encryption key for n8n"
  exit 1
fi

N8N_USER_MANAGEMENT_JWT_SECRET=$(generate_random_string 40)
if [ -z "$N8N_USER_MANAGEMENT_JWT_SECRET" ]; then
  echo "ERROR: Failed to generate JWT secret for n8n"
  exit 1
fi

# Use safer password generation function (alphanumeric only)
N8N_PASSWORD=$(generate_safe_password 16)
if [ -z "$N8N_PASSWORD" ]; then
  echo "ERROR: Failed to generate password for n8n"
  exit 1
fi

FLOWISE_PASSWORD=$(generate_safe_password 16)
if [ -z "$FLOWISE_PASSWORD" ]; then
  echo "ERROR: Failed to generate password for Flowise"
  exit 1
fi

# Generating Zep database secrets
ZEP_POSTGRES_USER="zep"
ZEP_POSTGRES_PASSWORD=$(generate_safe_password 16)
if [ -z "$ZEP_POSTGRES_PASSWORD" ]; then
  echo "ERROR: Failed to generate password for Zep PostgreSQL"
  exit 1
fi
ZEP_POSTGRES_DB="zep"

# Generate Zep Admin API Key
ZEP_ADMIN_API_KEY=$(generate_random_string 40)
if [ -z "$ZEP_ADMIN_API_KEY" ]; then
  echo "ERROR: Failed to generate admin API key for Zep"
  exit 1
fi

# Request OpenRouter API key
read -p "Enter your OpenRouter API key: " OPENROUTER_API_KEY
while [[ -z "$OPENROUTER_API_KEY" ]]; do
  echo "OpenRouter API key cannot be empty"
  read -p "Enter your OpenRouter API key: " OPENROUTER_API_KEY
done

# Default model setting with option to change
OPENROUTER_MODEL="meta-llama/llama-4-maverick:free"
read -p "Enter OpenRouter model to use (default: ${OPENROUTER_MODEL}): " USER_MODEL
if [[ ! -z "$USER_MODEL" ]]; then
  OPENROUTER_MODEL=$USER_MODEL
fi

# Writing values to .env file
cat > .env << EOL
# Settings for n8n
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
N8N_USER_MANAGEMENT_JWT_SECRET=$N8N_USER_MANAGEMENT_JWT_SECRET
N8N_DEFAULT_USER_EMAIL=$USER_EMAIL
N8N_DEFAULT_USER_PASSWORD=$N8N_PASSWORD

# n8n host configuration
SUBDOMAIN=n8n
GENERIC_TIMEZONE=$GENERIC_TIMEZONE

# Settings for Flowise
FLOWISE_USERNAME=admin
FLOWISE_PASSWORD=$FLOWISE_PASSWORD

# Domain settings
DOMAIN_NAME=$DOMAIN_NAME

# Zep database settings
ZEP_POSTGRES_USER=$ZEP_POSTGRES_USER
ZEP_POSTGRES_PASSWORD=$ZEP_POSTGRES_PASSWORD
ZEP_POSTGRES_DB=$ZEP_POSTGRES_DB

# OpenRouter settings
OPENROUTER_API_KEY=$OPENROUTER_API_KEY
OPENROUTER_MODEL=$OPENROUTER_MODEL

# Zep Admin API Key
ZEP_ADMIN_API_KEY=$ZEP_ADMIN_API_KEY
EOL

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to create .env file"
  exit 1
fi

echo "Secret keys generated and saved to .env file"
echo "Password for n8n: $N8N_PASSWORD"
echo "Password for Flowise: $FLOWISE_PASSWORD"
echo "Password for Zep PostgreSQL: $ZEP_POSTGRES_PASSWORD"
echo "Admin API Key for Zep: $ZEP_ADMIN_API_KEY"

# Save passwords for future use - using quotes to properly handle special characters
echo "N8N_PASSWORD=\\"$N8N_PASSWORD\\"" > ./setup-files/passwords.txt
echo "FLOWISE_PASSWORD=\\"$FLOWISE_PASSWORD\\"" >> ./setup-files/passwords.txt
echo "ZEP_POSTGRES_PASSWORD=\\"$ZEP_POSTGRES_PASSWORD\\"" >> ./setup-files/passwords.txt
echo "ZEP_ADMIN_API_KEY=\\"$ZEP_ADMIN_API_KEY\\"" >> ./setup-files/passwords.txt

echo "✅ Secret keys and passwords successfully generated"
exit 0 