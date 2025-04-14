#!/bin/bash

# Check that the script is being run with sudo privileges
if [ "$EUID" -ne 0 ]; then
  if ! sudo -n true 2>/dev/null; then
    echo "Please run this script with sudo privileges"
    exit 1
  fi
fi

echo "Setting up directories for Zep..."

# Create directories for Zep
sudo mkdir -p /opt/zep/data
sudo mkdir -p /opt/zep/postgres-data
sudo mkdir -p /opt/zep/qdrant-data

# Check if n8n user exists
if id "n8n" &>/dev/null; then
  # Set permissions
  sudo chown -R n8n:n8n /opt/zep
else
  # Create n8n user if it doesn't exist
  sudo useradd -r -s /bin/false n8n
  sudo chown -R n8n:n8n /opt/zep
fi

# Set proper permissions
sudo chmod -R 755 /opt/zep

echo "✅ Zep directories successfully created"
exit 0 