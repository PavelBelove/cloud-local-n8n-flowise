#!/bin/bash

echo "Setting up directories and users..."

# Create or update n8n user
if ! id "n8n" &>/dev/null; then
  echo "Creating n8n user..."
  sudo adduser --system --group --no-create-home --disabled-password --gecos "" n8n
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create n8n user"
    exit 1
  fi
else
  echo "User n8n already exists. Ensuring group membership..."
fi

# Ensure user is in the docker group
sudo usermod -aG docker n8n
if [ $? -ne 0 ]; then
  echo "WARNING: Failed to add n8n user to docker group. Docker commands might require sudo."
  # Not exiting as this might not be critical depending on setup
fi

# Set/Reset password for n8n user (we don't actually need this password for services, but useful for potential sudo/login)
N8N_SYSTEM_PASSWORD=$(openssl rand -base64 12)
echo "n8n:$N8N_SYSTEM_PASSWORD" | sudo chpasswd
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to set password for n8n system user"
  # Not exiting, as the password isn't strictly needed for docker service operation
else
  echo "Password for n8n *system* user set to: $N8N_SYSTEM_PASSWORD"
  echo "(This system password is not used for n8n application login)"
fi

# Creating necessary directories
echo "Creating directories..."
sudo mkdir -p /opt/n8n
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to create directory /opt/n8n"
  exit 1
fi

sudo mkdir -p /opt/n8n/files
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to create directory /opt/n8n/files"
  exit 1
fi

sudo mkdir -p /opt/flowise
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to create directory /opt/flowise"
  exit 1
fi

# Create directory for crawl4ai cache
sudo mkdir -p /opt/crawl4ai/cache
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to create directory /opt/crawl4ai/cache"
  exit 1
fi

# Setting permissions
sudo chown -R n8n:n8n /opt/n8n
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to change owner of directory /opt/n8n"
  exit 1
fi

sudo chown -R n8n:n8n /opt/flowise
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to change owner of directory /opt/flowise"
  exit 1
fi

sudo chown -R n8n:n8n /opt/crawl4ai
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to change owner of directory /opt/crawl4ai"
  exit 1
fi

# Creating docker volumes
echo "Creating Docker volumes..."
sudo docker volume create n8n_data
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to create Docker volume n8n_data"
  exit 1
fi

sudo docker volume create caddy_data
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to create Docker volume caddy_data"
  exit 1
fi

echo "✅ Directories and users successfully configured"
exit 0 