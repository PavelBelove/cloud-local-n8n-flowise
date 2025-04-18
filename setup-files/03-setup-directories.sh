#!/bin/bash

echo "Setting up directories and users..."

# Creating n8n user if it doesn't exist
if ! id "n8n" &>/dev/null; then
  echo "Creating n8n user..."
  sudo adduser --disabled-password --gecos "" n8n
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create n8n user"
    exit 1
  fi
  
  # Generate random password
  N8N_PASSWORD=$(openssl rand -base64 12)
  echo "n8n:$N8N_PASSWORD" | sudo chpasswd
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to set password for n8n user"
    exit 1
  fi
  
  echo "✅ Created n8n user with password: $N8N_PASSWORD"
  echo "⚠️ IMPORTANT: Write down this password, you will need it for working with Docker!"
  
  sudo usermod -aG docker n8n
  if [ $? -ne 0 ]; then
    echo "WARNING: Failed to add n8n user to docker group"
    # Not exiting as this is not a critical error
  fi
else
  echo "User n8n already exists"
  
  # If user exists but password needs to be reset
  read -p "Do you want to reset the password for n8n user? (y/n): " reset_password
  if [ "$reset_password" = "y" ]; then
    N8N_PASSWORD=$(openssl rand -base64 12)
    echo "n8n:$N8N_PASSWORD" | sudo chpasswd
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to reset password for n8n user"
    else
      echo "✅ Password for n8n user has been reset: $N8N_PASSWORD"
      echo "⚠️ IMPORTANT: Write down this password, you will need it for working with Docker!"
    fi
  fi
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