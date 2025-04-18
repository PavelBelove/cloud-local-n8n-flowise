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

# Main installation function
main() {
  show_progress "🚀 Starting installation of n8n, Flowise, Zep, crawl4ai, and Caddy"
  
  # Check administrator rights
  if [ "$EUID" -ne 0 ]; then
    if ! sudo -n true 2>/dev/null; then
      echo "Administrator rights are required for installation"
      echo "Please enter the administrator password when prompted"
    fi
  fi
  
  # Request user data
  echo "For installation, you need to specify a domain name and email address."
  
  # Request domain name
  read -p "Enter your domain name (e.g., example.com): " DOMAIN_NAME
  while [[ -z "$DOMAIN_NAME" || "$DOMAIN_NAME" == *"@"* ]]; do
    if [[ -z "$DOMAIN_NAME" ]]; then
      echo "Domain name cannot be empty"
    else
      echo "Invalid domain name format. Please enter a domain name, not an email address."
    fi
    read -p "Enter your domain name (e.g., example.com): " DOMAIN_NAME
  done
  
  # Request email address
  read -p "Enter your email (will be used for n8n login): " USER_EMAIL
  while [[ ! "$USER_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
    echo "Enter a valid email address"
    read -p "Enter your email (will be used for n8n login): " USER_EMAIL
  done
  
  # Request timezone
  DEFAULT_TIMEZONE=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
  read -p "Enter your timezone (default: $DEFAULT_TIMEZONE): " GENERIC_TIMEZONE
  GENERIC_TIMEZONE=${GENERIC_TIMEZONE:-$DEFAULT_TIMEZONE}
  
  # Create setup-files directory if it doesn't exist
  if [ ! -d "setup-files" ]; then
    mkdir -p setup-files
    check_success "creating setup-files directory"
  fi
  
  # Set execution permissions for all scripts
  chmod +x setup-files/*.sh 2>/dev/null || true
  
  # Step 1: System update
  show_progress "Step 1/9: System update"
  ./setup-files/01-update-system.sh
  check_success "system update"
  
  # Step 2: Docker installation
  show_progress "Step 2/9: Docker installation"
  ./setup-files/02-install-docker.sh
  check_success "Docker installation"
  
  # Step 3: Directory setup
  show_progress "Step 3/9: Directory setup"
  ./setup-files/03-setup-directories.sh
  check_success "directory setup"
  
  # Step 4: Secret key generation
  show_progress "Step 4/9: Secret key generation"
  ./setup-files/04-generate-secrets.sh "$USER_EMAIL" "$DOMAIN_NAME" "$GENERIC_TIMEZONE"
  check_success "secret key generation"
  
  # Step 5: Template creation
  show_progress "Step 5/9: Configuration file creation"
  ./setup-files/05-create-templates.sh "$DOMAIN_NAME"
  check_success "configuration file creation"
  
  # Step 6: Firewall setup
  show_progress "Step 6/9: Firewall setup"
  ./setup-files/06-setup-firewall.sh
  check_success "firewall setup"
  
  # Step 7: Zep setup
  show_progress "Step 7/9: Zep setup"
  ./setup-files/08-setup-zep.sh
  check_success "Zep setup"
  
  # Step 8: Service launch
  show_progress "Step 8/9: Service launch"
  ./setup-files/07-start-services.sh
  check_success "service launch"
  
  # Important: Load secrets from .env file as sourcing passwords.txt is unsafe
  if [ -f ".env" ]; then
    # Use export to make variables available to the current shell
    export $(grep -v '^#' .env | xargs)
  else
    echo "WARNING: .env file not found. Cannot display final credentials."
    # Set default empty values to avoid errors in echo commands below
    USER_EMAIL="N/A"
    N8N_PASSWORD="N/A"
    FLOWISE_PASSWORD="N/A"
    ZEP_ADMIN_API_KEY="N/A"
    ZEP_POSTGRES_PASSWORD="N/A"
  fi
  
  # Installation successfully completed
  show_progress "✅ Installation successfully completed!"
  
  echo "n8n is available at: https://n8n.${DOMAIN_NAME}"
  echo "Flowise is available at: https://flowise.${DOMAIN_NAME}"
  echo "Zep is available at: https://zep.${DOMAIN_NAME}"
  echo "crawl4ai is available at: https://crawl4ai.${DOMAIN_NAME}"
  echo ""
  echo "Login credentials for n8n:"
  echo "Email: ${USER_EMAIL}"
  echo "Password: ${N8N_PASSWORD:-<check the .env file>}"
  echo ""
  echo "Login credentials for Flowise:"
  echo "Username: admin"
  echo "Password: ${FLOWISE_PASSWORD:-<check the .env file>}"
  echo ""
  echo "Zep API Endpoint: https://zep.${DOMAIN_NAME}/api"
  echo "Zep Admin API Key: ${ZEP_ADMIN_API_KEY:-<check the .env file>}"
  echo "PostgreSQL Password for Zep: ${ZEP_POSTGRES_PASSWORD:-<check the .env file>}"
  echo ""
  echo "crawl4ai API Endpoint: https://crawl4ai.${DOMAIN_NAME}/api/v1/crawl/"
  echo ""
  echo "Please note that for the domain name to work, you need to configure DNS records"
  echo ""
  echo "To edit the configuration, use the following files:"
  echo "- n8n-docker-compose.yaml (n8n and Caddy configuration)"
  echo "- flowise-docker-compose.yaml (Flowise configuration)"
  echo "- zep-docker-compose.yaml (Zep, PostgreSQL, and Qdrant configuration)"
  echo "- crawl4ai-docker-compose.yaml (crawl4ai configuration)"
  echo "- .env (environment variables for all services)"
  echo "- Caddyfile (reverse proxy settings)"
  echo ""
  echo "To restart services, execute the commands:"
  echo "docker compose -f n8n-docker-compose.yaml restart"
  echo "docker compose -f flowise-docker-compose.yaml restart"
  echo "docker compose -f zep-docker-compose.yaml restart"
  echo "docker compose -f crawl4ai-docker-compose.yaml restart"
}

# Run main function
main 