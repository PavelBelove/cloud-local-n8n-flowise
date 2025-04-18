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

# Create Zep template if it doesn't exist
if [ ! -f "zep-docker-compose.yaml.template" ]; then
  echo "Creating template zep-docker-compose.yaml.template..."
  cat > zep-docker-compose.yaml.template << EOL
version: '3'

services:
  zep:
    image: ghcr.io/getzep/zep:latest
    container_name: zep
    restart: unless-stopped
    environment:
      # Store configuration
      - ZEP_STORE_TYPE=postgres # Use postgres for memory and metadata
      - ZEP_MEMORY_STORE_POSTGRES_DSN=postgres://\${ZEP_POSTGRES_USER}:\${ZEP_POSTGRES_PASSWORD}@zep-postgres:5432/\${ZEP_POSTGRES_DB}?sslmode=disable
      - ZEP_DOCUMENT_STORE_TYPE=qdrant # Use qdrant for document embeddings
      - ZEP_QDRANT_URL=http://qdrant:6333

      # LLM configuration (using OpenRouter)
      - ZEP_OPENAI_API_KEY=\${OPENROUTER_API_KEY}
      - ZEP_OPENAI_API_BASE=https://openrouter.ai/api/v1
      - ZEP_OPENAI_CHAT_MODEL=\${OPENROUTER_MODEL}

      # Embeddings configuration (using built-in Sentence Transformers)
      - ZEP_OPENAI_EMBEDDINGS_MODEL=sentence-transformers/all-MiniLM-L6-v2

      # Authentication
      - ZEP_AUTH_REQUIRED=true
      - ZEP_ADMIN_API_KEY=\${ZEP_ADMIN_API_KEY}
    mem_limit: 512m
    cpus: 0.5
    volumes:
      - /opt/zep/data:/data
    networks:
      - app-network

  zep-postgres:
    image: postgres:15
    container_name: zep-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=\${ZEP_POSTGRES_USER}
      - POSTGRES_PASSWORD=\${ZEP_POSTGRES_PASSWORD}
      - POSTGRES_DB=\${ZEP_POSTGRES_DB}
    mem_limit: 512m
    cpus: 0.5
    volumes:
      - /opt/zep/postgres-data:/var/lib/postgresql/data
    networks:
      - app-network

  qdrant:
    image: qdrant/qdrant:latest
    container_name: qdrant
    restart: unless-stopped
    mem_limit: 1g
    cpus: 0.5
    volumes:
      - /opt/zep/qdrant-data:/qdrant/storage
    networks:
      - app-network

networks:
  app-network:
    external: true
EOL
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create file zep-docker-compose.yaml.template"
    exit 1
  fi
else
  echo "Template zep-docker-compose.yaml.template already exists"
fi

# Create Crawl4AI template if it doesn't exist
if [ ! -f "crawl4ai-docker-compose.yaml.template" ]; then
  echo "Creating template crawl4ai-docker-compose.yaml.template..."
  cat > crawl4ai-docker-compose.yaml.template << EOL
version: '3'

services:
  crawl4ai:
    image: unclecode/crawl4ai:basic
    container_name: crawl4ai
    restart: unless-stopped
    ports:
      - "11235:11235"
    networks:
      - app-network

networks:
  app-network:
    external: true
EOL
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create file crawl4ai-docker-compose.yaml.template"
    exit 1
  fi
else
  echo "Template crawl4ai-docker-compose.yaml.template already exists"
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

cp zep-docker-compose.yaml.template zep-docker-compose.yaml
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to copy zep-docker-compose.yaml.template to working file"
  exit 1
fi

# Copy Crawl4AI template to working file
cp crawl4ai-docker-compose.yaml.template crawl4ai-docker-compose.yaml
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to copy crawl4ai-docker-compose.yaml.template to working file"
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

zep.${DOMAIN_NAME} {
    reverse_proxy zep:8000
}

crawl4ai.${DOMAIN_NAME} {\
    reverse_proxy crawl4ai:11235\
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