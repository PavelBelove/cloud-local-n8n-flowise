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
  
  # Step 1: Create Zep directories
  show_progress "Step 1/5: Setting up Zep directories"
  
  # Create directories for Zep
  sudo mkdir -p /opt/zep/data
  sudo mkdir -p /opt/zep/postgres-data
  sudo mkdir -p /opt/zep/qdrant-data
  
  # Check if n8n user exists and set permissions
  if id "n8n" &>/dev/null; then
    sudo chown -R n8n:n8n /opt/zep
  else
    # Attempt to create n8n user if needed (might exist from previous setup)
    if ! sudo useradd -r -s /bin/false n8n 2>/dev/null; then
       echo "User n8n already exists or could not be created. Assuming user exists."
    fi
    sudo chown -R n8n:n8n /opt/zep
  fi
  
  # Set proper permissions
  sudo chmod -R 755 /opt/zep
  check_success "setting up directories"
  
  # Step 2: Create docker-compose file
  show_progress "Step 2/5: Creating Zep docker-compose file"
  
  # Create Zep docker-compose file without variable substitution (using quoted EOL)
  echo "Creating zep-docker-compose.yaml..."
  cat > zep-docker-compose.yaml << 'EOL'
version: '3'

services:
  zep:
    image: ghcr.io/getzep/zep:latest
    container_name: zep
    restart: unless-stopped
    environment:
      - ZEP_OPENAI_API_KEY=${OPENROUTER_API_KEY} # Read from .env.zep
      - ZEP_OPENAI_API_BASE=https://openrouter.ai/api/v1
      - ZEP_OPENAI_EMBEDDINGS_MODEL=sentence-transformers/all-MiniLM-L6-v2
      - ZEP_OPENAI_CHAT_MODEL=${OPENROUTER_MODEL} # Read from .env.zep
      - ZEP_MEMORY_STORE_POSTGRES_DSN=postgres://${ZEP_POSTGRES_USER}:${ZEP_POSTGRES_PASSWORD}@zep-postgres:5432/${ZEP_POSTGRES_DB}?sslmode=disable # Read from .env.zep
      - ZEP_QDRANT_URL=http://qdrant:6333
      - ZEP_STORE_TYPE=postgres # Explicitly set store type
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
      - POSTGRES_USER=${ZEP_POSTGRES_USER} # Read from .env.zep
      - POSTGRES_PASSWORD=${ZEP_POSTGRES_PASSWORD} # Read from .env.zep
      - POSTGRES_DB=${ZEP_POSTGRES_DB} # Read from .env.zep
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
  
  # Step 3: Create .env file for Zep compose
  show_progress "Step 3/5: Creating environment file for Zep"
  echo "Creating .env.zep file..."
  # Use printf to avoid issues with special characters in passwords/keys
  printf "OPENROUTER_API_KEY=%s
" "$OPENROUTER_API_KEY" > .env.zep
  printf "OPENROUTER_MODEL=%s
" "$OPENROUTER_MODEL" >> .env.zep
  printf "ZEP_POSTGRES_USER=%s
" "$ZEP_POSTGRES_USER" >> .env.zep
  printf "ZEP_POSTGRES_PASSWORD=%s
" "$ZEP_POSTGRES_PASSWORD" >> .env.zep
  printf "ZEP_POSTGRES_DB=%s
" "$ZEP_POSTGRES_DB" >> .env.zep
  check_success "creating .env.zep file"
  
  # Step 4: Update Caddyfile
  show_progress "Step 4/5: Updating Caddy configuration"
  
  CADDYFILE_PATH="/opt/n8n/Caddyfile" # Assuming Caddyfile is managed by n8n setup
  
  # Backup original Caddyfile
  if [ -f "$CADDYFILE_PATH" ]; then
    sudo cp "$CADDYFILE_PATH" "${CADDYFILE_PATH}.bak.$(date +%F_%T)"
    echo "Original Caddyfile backed up to ${CADDYFILE_PATH}.bak.*"
  else
    echo "Warning: Caddyfile not found at $CADDYFILE_PATH. A new one will be created for Zep."
  fi
  
  # Add Zep to Caddyfile idempotently
  ZEP_CADDY_ENTRY="zep.${DOMAIN_NAME} {\n    reverse_proxy zep:8000\n}"
  if [ -f "$CADDYFILE_PATH" ] && grep -q "zep.${DOMAIN_NAME}" "$CADDYFILE_PATH"; then
      echo "Zep entry already exists in Caddyfile."
  else
      echo "Adding Zep entry to Caddyfile..."
      # Append with a preceding newline if the file exists and doesn't end with a newline
      [ -f "$CADDYFILE_PATH" ] && [ -n "$(tail -c1 "$CADDYFILE_PATH")" ] && printf '\n' | sudo tee -a "$CADDYFILE_PATH" > /dev/null
      # Append the entry
      printf "\n%s\n" "$ZEP_CADDY_ENTRY" | sudo tee -a "$CADDYFILE_PATH" > /dev/null
      check_success "updating Caddyfile"
  fi
  
  # Step 5: Start Zep services
  show_progress "Step 5/5: Starting Zep services"
  
  # Check if app-network exists, create if not
  if ! sudo docker network inspect app-network &> /dev/null; then
    echo "Creating app-network..."
    # Assuming n8n setup created this, but check just in case
    if ! sudo docker network create app-network; then
       echo "Warning: Failed to create app-network. Assuming it exists or will be created by another service."
    else
       check_success "creating app-network"
    fi
  fi
  
  # Start Zep using the specific env file
  echo "Starting Zep services..."
  sudo docker compose --env-file .env.zep -f zep-docker-compose.yaml up -d
  check_success "starting Zep services"
  
  # Restart Caddy to apply changes if it's running
  if sudo docker ps --format '{{.Names}}' | grep -q "^caddy$"; then
    echo "Restarting Caddy to apply new configuration..."
    sudo docker restart caddy
    check_success "restarting Caddy"
  else
    echo "Caddy container not found or not running. Skipping Caddy restart."
  fi
  
  # Save password information
  echo "ZEP_POSTGRES_PASSWORD="$ZEP_POSTGRES_PASSWORD"" > ./zep-passwords.txt
  
  # Installation successfully completed
  show_progress "✅ Zep installation successfully completed!"
  
  echo "Zep should be available at: https://zep.${DOMAIN_NAME}"
  echo "Zep API Endpoint: https://zep.${DOMAIN_NAME}/api"
  echo "PostgreSQL Password for Zep: ${ZEP_POSTGRES_PASSWORD}"
  echo ""
  echo "Please note that for the domain name to work, you need to configure DNS records"
  echo "pointing to the IP address of this server. It might take a few minutes for Caddy"
  echo "to obtain the SSL certificate."
  echo ""
  echo "You can manage Zep services with these commands:"
  echo "- Start: docker compose --env-file .env.zep -f zep-docker-compose.yaml up -d"
  echo "- Stop: docker compose -f zep-docker-compose.yaml down"
  echo "- Restart: docker compose -f zep-docker-compose.yaml restart"
  echo "- View logs: docker compose -f zep-docker-compose.yaml logs -f"
  echo ""
  echo "Password information is saved in ./zep-passwords.txt"
  echo "Environment variables for compose are in ./.env.zep"
}

# Run main function
main 