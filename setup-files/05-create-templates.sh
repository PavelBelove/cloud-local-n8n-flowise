#!/bin/bash

# Get variables from the main script via arguments
DOMAIN_NAME=$1

if [ -z "$DOMAIN_NAME" ]; then
  echo "ERROR: Domain name not specified"
  echo "Usage: $0 example.com"
  exit 1
fi

echo "Creating templates and configuration files..."

# Check for template files and create them
if [ ! -f "n8n-docker-compose.yaml.template" ]; then
  echo "Creating template n8n-docker-compose.yaml.template..."
  cat > n8n-docker-compose.yaml.template << EOL
version: '3'

volumes:
  n8n_data:
    external: true
  caddy_data:
    external: true
  caddy_config:

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    environment:
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY}
      - N8N_USER_MANAGEMENT_DISABLED=false
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_PERSONALIZATION_ENABLED=false
      - N8N_USER_MANAGEMENT_JWT_SECRET=\${N8N_USER_MANAGEMENT_JWT_SECRET}
      - N8N_DEFAULT_USER_EMAIL=\${N8N_DEFAULT_USER_EMAIL}
      - N8N_DEFAULT_USER_PASSWORD=\${N8N_DEFAULT_USER_PASSWORD}
      - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
    volumes:
      - n8n_data:/home/node/.n8n
      - /opt/n8n/files:/files
    networks:
      - app-network

  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    ports:
      - 80:80
      - 443:443
    volumes:
      - /opt/n8n/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - app-network

networks:
  app-network:
    name: app-network
    driver: bridge
EOL
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create file n8n-docker-compose.yaml.template"
    exit 1
  fi
else
  echo "Template n8n-docker-compose.yaml.template already exists"
fi

if [ ! -f "flowise-docker-compose.yaml.template" ]; then
  echo "Creating template flowise-docker-compose.yaml.template..."
  cat > flowise-docker-compose.yaml.template << EOL
version: '3'

services:
  flowise:
    image: flowiseai/flowise
    restart: unless-stopped
    container_name: flowise
    environment:
      - PORT=3001
      - FLOWISE_USERNAME=\${FLOWISE_USERNAME}
      - FLOWISE_PASSWORD=\${FLOWISE_PASSWORD}
    volumes:
      - /opt/flowise:/root/.flowise
    networks:
      - app-network

networks:
  app-network:
    external: true
EOL
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create file flowise-docker-compose.yaml.template"
    exit 1
  fi
else
  echo "Template flowise-docker-compose.yaml.template already exists"
fi

# Copy templates to working files
cp n8n-docker-compose.yaml.template n8n-docker-compose.yaml
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to copy n8n-docker-compose.yaml.template to working file"
  exit 1
fi

cp flowise-docker-compose.yaml.template flowise-docker-compose.yaml
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to copy flowise-docker-compose.yaml.template to working file"
  exit 1
fi

# Create Caddyfile
echo "Creating Caddyfile..."
cat > Caddyfile << EOL
n8n.${DOMAIN_NAME} {
    reverse_proxy n8n:5678
}

flowise.${DOMAIN_NAME} {
    reverse_proxy flowise:3001
}
EOL
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to create Caddyfile"
  exit 1
fi

# Copy file to working directory
sudo cp Caddyfile /opt/n8n/
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to copy Caddyfile to /opt/n8n/"
  exit 1
fi

echo "✅ Templates and configuration files successfully created"
exit 0 