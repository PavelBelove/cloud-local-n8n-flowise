#!/bin/bash

# Function to check successful command execution
check_success() {
  if [ $? -ne 0 ]; then
    echo "❌ Error executing $1"
    echo "Installation aborted. Please fix the errors and try again."
    exit 1
  fi
}

# Function to display progress
show_progress() {
  echo ""
  echo "========================================================"
  echo "   $1"
  echo "========================================================"
  echo ""
}

# Function to generate safe passwords (no special bash characters)
generate_safe_password() {
  length=$1
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${length} | head -n 1
}

# Main installation function
main() {
  show_progress "🚀 Starting installation of Zep"
  
  # Check administrator rights
  if [ "$EUID" -ne 0 ]; then
    if ! sudo -n true 2>/dev/null; then
      echo "Administrator rights are required for installation"
      echo "Please enter the administrator password when prompted"
    fi
  fi
  
  # Request domain name
  read -p "Enter your domain name (e.g., example.com): " DOMAIN_NAME
  while [[ -z "$DOMAIN_NAME" ]]; do
    echo "Domain name cannot be empty"
    read -p "Enter your domain name (e.g., example.com): " DOMAIN_NAME
  done
  
  # Generate Zep database secrets
  ZEP_POSTGRES_USER="zep"
  ZEP_POSTGRES_PASSWORD=$(generate_safe_password 16)
  ZEP_POSTGRES_DB="zep"
  
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
  
  # Create setup-files directory if it doesn't exist
  if [ ! -d "setup-files" ]; then
    mkdir -p setup-files
    check_success "creating setup-files directory"
  fi
  
  # Step 1: Create Zep directories
  show_progress "Step 1/4: Setting up Zep directories"
  
  # Create directories for Zep
  sudo mkdir -p /opt/zep/data
  sudo mkdir -p /opt/zep/postgres-data
  sudo mkdir -p /opt/zep/qdrant-data
  
  # Check if n8n user exists and set permissions
  if id "n8n" &>/dev/null; then
    sudo chown -R n8n:n8n /opt/zep
  else
    sudo useradd -r -s /bin/false n8n
    sudo chown -R n8n:n8n /opt/zep
  fi
  
  # Set proper permissions
  sudo chmod -R 755 /opt/zep
  check_success "setting up directories"
  
  # Step 2: Create template files
  show_progress "Step 2/4: Creating configuration files"
  
  # Create Zep docker-compose file
  echo "Creating zep-docker-compose.yaml..."
  cat > zep-docker-compose.yaml << EOL
version: '3'

services:
  zep:
    image: ghcr.io/getzep/zep:latest
    container_name: zep
    restart: unless-stopped
    environment:
      - ZEP_STORE_TYPE=postgres
      - ZEP_MEMORY_STORE_TYPE=postgres
      - ZEP_MEMORY_STORE_POSTGRES_DSN=postgres://${ZEP_POSTGRES_USER}:${ZEP_POSTGRES_PASSWORD}@zep-postgres:5432/${ZEP_POSTGRES_DB}?sslmode=disable
      - ZEP_VECTOR_STORE_TYPE=qdrant
      - ZEP_VECTOR_STORE_QDRANT_URL=http://qdrant:6333
      - ZEP_OPENAI_API_KEY=${OPENROUTER_API_KEY}
      - ZEP_OPENAI_API_BASE=https://openrouter.ai/api/v1
      - ZEP_OPENAI_EMBEDDINGS_MODEL=sentence-transformers/all-MiniLM-L6-v2
      - ZEP_OPENAI_CHAT_MODEL=${OPENROUTER_MODEL}
      - ZEP_SERVER_BASE_URL=https://zep.${DOMAIN_NAME}
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
      - POSTGRES_USER=${ZEP_POSTGRES_USER}
      - POSTGRES_PASSWORD=${ZEP_POSTGRES_PASSWORD}
      - POSTGRES_DB=${ZEP_POSTGRES_DB}
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
  check_success "creating zep-docker-compose.yaml"
  
  # Step 3: Update Caddyfile
  show_progress "Step 3/4: Updating Caddy configuration"
  
  # Backup original Caddyfile
  if [ -f "/opt/n8n/Caddyfile" ]; then
    sudo cp /opt/n8n/Caddyfile /opt/n8n/Caddyfile.bak
    echo "Original Caddyfile backed up to /opt/n8n/Caddyfile.bak"
  fi
  
  # Add Zep to Caddyfile
  if [ -f "/opt/n8n/Caddyfile" ]; then
    if ! grep -q "zep.${DOMAIN_NAME}" "/opt/n8n/Caddyfile"; then
      echo "Adding Zep to Caddyfile..."
      sudo bash -c "cat >> /opt/n8n/Caddyfile << EOL

zep.${DOMAIN_NAME} {
    reverse_proxy zep:8000
}
EOL"
      check_success "updating Caddyfile"
    else
      echo "Zep entry already exists in Caddyfile"
    fi
  else
    echo "Creating new Caddyfile..."
    sudo bash -c "cat > /opt/n8n/Caddyfile << EOL
zep.${DOMAIN_NAME} {
    reverse_proxy zep:8000
}
EOL"
    check_success "creating Caddyfile"
  fi
  
  # Step 4: Start Zep services
  show_progress "Step 4/4: Starting Zep services"
  
  # Check if app-network exists, create if not
  if ! sudo docker network inspect app-network &> /dev/null; then
    echo "Creating app-network..."
    sudo docker network create app-network
    check_success "creating app-network"
  fi
  
  # Start Zep
  echo "Starting Zep services..."
  sudo docker compose -f zep-docker-compose.yaml up -d
  check_success "starting Zep services"
  
  # Restart Caddy to apply changes
  if sudo docker ps | grep -q "caddy"; then
    echo "Restarting Caddy to apply new configuration..."
    sudo docker restart caddy
    check_success "restarting Caddy"
  fi
  
  # Save password information
  cat > ./zep-passwords.txt << EOL
ZEP_POSTGRES_USER="${ZEP_POSTGRES_USER}"
ZEP_POSTGRES_PASSWORD="${ZEP_POSTGRES_PASSWORD}"
ZEP_POSTGRES_DB="${ZEP_POSTGRES_DB}"
OPENROUTER_API_KEY="${OPENROUTER_API_KEY}"
OPENROUTER_MODEL="${OPENROUTER_MODEL}"
DOMAIN_NAME="${DOMAIN_NAME}"
EOL
  
  # Installation successfully completed
  show_progress "✅ Zep installation successfully completed!"
  
  echo "Zep is available at: https://zep.${DOMAIN_NAME}"
  echo "Zep API Endpoint: https://zep.${DOMAIN_NAME}/api"
  echo "PostgreSQL Password for Zep: ${ZEP_POSTGRES_PASSWORD}"
  echo ""
  echo "Please note that for the domain name to work, you need to configure DNS records"
  echo "pointing to the IP address of this server."
  echo ""
  echo "You can manage Zep services with these commands:"
  echo "- Start: docker compose -f zep-docker-compose.yaml up -d"
  echo "- Stop: docker compose -f zep-docker-compose.yaml down"
  echo "- Restart: docker compose -f zep-docker-compose.yaml restart"
  echo "- View logs: docker compose -f zep-docker-compose.yaml logs"
  echo ""
  echo "All configuration information is saved in ./zep-passwords.txt"
}

# Run main function
main 