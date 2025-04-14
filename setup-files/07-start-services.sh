#!/bin/bash

echo "Starting services..."

# Check for required files
if [ ! -f "n8n-docker-compose.yaml" ]; then
  echo "ERROR: File n8n-docker-compose.yaml not found"
  exit 1
fi

if [ ! -f "flowise-docker-compose.yaml" ]; then
  echo "ERROR: File flowise-docker-compose.yaml not found"
  exit 1
fi

if [ ! -f "zep-docker-compose.yaml" ]; then
  echo "ERROR: File zep-docker-compose.yaml not found"
  exit 1
fi

if [ ! -f ".env" ]; then
  echo "ERROR: File .env not found"
  exit 1
fi

# Start n8n and Caddy
echo "Starting n8n and Caddy..."
sudo docker compose -f n8n-docker-compose.yaml up -d
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to start n8n and Caddy"
  exit 1
fi

# Wait a bit for the network to be created
echo "Waiting for docker network creation..."
sleep 5

# Check if app-network was created
if ! sudo docker network inspect app-network &> /dev/null; then
  echo "ERROR: Failed to create app-network"
  exit 1
fi

# Start Flowise
echo "Starting Flowise..."
sudo docker compose -f flowise-docker-compose.yaml up -d
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to start Flowise"
  exit 1
fi

# Start Zep
echo "Starting Zep services..."
sudo docker compose -f zep-docker-compose.yaml up -d
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to start Zep services"
  exit 1
fi

# Check that all containers are running
echo "Checking running containers..."
sleep 5

if ! sudo docker ps | grep -q "n8n"; then
  echo "ERROR: Container n8n is not running"
  exit 1
fi

if ! sudo docker ps | grep -q "caddy"; then
  echo "ERROR: Container caddy is not running"
  exit 1
fi

if ! sudo docker ps | grep -q "flowise"; then
  echo "ERROR: Container flowise is not running"
  exit 1
fi

if ! sudo docker ps | grep -q "zep"; then
  echo "ERROR: Container zep is not running"
  exit 1
fi

if ! sudo docker ps | grep -q "zep-postgres"; then
  echo "ERROR: Container zep-postgres is not running"
  exit 1
fi

if ! sudo docker ps | grep -q "qdrant"; then
  echo "ERROR: Container qdrant is not running"
  exit 1
fi

echo "✅ Services n8n, Flowise, Zep and Caddy successfully started"
exit 0 