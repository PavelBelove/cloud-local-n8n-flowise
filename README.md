# Cloud-Local n8n, Flowise & Zep Setup

Automated installation script for n8n, Flowise, and Zep with reverse proxy server Caddy for secure access via HTTPS.

## Description

This repository contains scripts for automatic configuration of:

- **n8n** - a powerful open-source workflow automation platform
- **Flowise** - a tool for creating customizable AI flows
- **Zep** - memory and vector database for LLM applications
- **Caddy** - a modern web server with automatic HTTPS

The system is configured to work with your domain name and automatically obtains Let's Encrypt SSL certificates.

## Requirements

- Ubuntu 22.04 
- Domain name pointing to your server's IP address
- Server access with administrator rights (sudo)
- Open ports 80, 443
- OpenRouter API key (for Zep LLM functionality)

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/PavelBelove/cloud-local-n8n-flowise.git && cd cloud-local-n8n-flowise
   ```

2. Make the script executable:
   ```bash
   chmod +x setup.sh
   ```

3. Run the installation script:
   ```bash
   ./setup.sh
   ```

4. Follow the instructions in the terminal:
   - Enter your domain name (e.g., example.com)
   - Enter your email (will be used for n8n login and Let's Encrypt)
   - Enter your OpenRouter API key (for Zep to use external LLMs)
   - Optionally, customize the OpenRouter model (default: meta-llama/llama-4-maverick:free)

## What the installation script does

1. **System update** - updates the package list and installs necessary dependencies
2. **Docker installation** - installs Docker Engine and Docker Compose
3. **Directory setup** - creates n8n user and necessary directories
4. **Secret generation** - creates random passwords and encryption keys
5. **Configuration file creation** - generates docker-compose files and Caddyfile
6. **Firewall setup** - opens necessary ports
7. **Zep setup** - creates directories and sets permissions for Zep
8. **Service launch** - starts Docker containers

## Accessing services

After installation completes, you will be able to access services at the following URLs:

- **n8n**: https://n8n.your-domain.xxx
- **Flowise**: https://flowise.your-domain.xxx
- **Zep API**: https://zep.your-domain.xxx

Login credentials will be displayed at the end of the installation process.

## Project structure

- `setup.sh` - main installation script
- `setup-files/` - directory with helper scripts:
  - `01-update-system.sh` - system update
  - `02-install-docker.sh` - Docker installation
  - `03-setup-directories.sh` - directory and user setup
  - `04-generate-secrets.sh` - secret key generation
  - `05-create-templates.sh` - configuration file creation
  - `06-setup-firewall.sh` - firewall setup
  - `07-start-services.sh` - service launch
  - `08-setup-zep.sh` - Zep setup
- `n8n-docker-compose.yaml.template` - docker-compose template for n8n and Caddy
- `flowise-docker-compose.yaml.template` - docker-compose template for Flowise
- `zep-docker-compose.yaml.template` - docker-compose template for Zep, PostgreSQL and Qdrant

## Zep Configuration

Zep is configured with:
- PostgreSQL database for memory storage
- Qdrant vector database for embeddings storage
- Sentence Transformers embeddings model (all-MiniLM-L6-v2)
- OpenRouter for LLM API access

## Integrating Zep

### With n8n
You can use Zep in n8n via the HTTP Request nodes:
- Base URL: `https://zep.your-domain.xxx/api`
- API documentation: https://docs.getzep.com/api/

### With Flowise
You can integrate Zep in Flowise by creating custom tools or using memory components:
- API Endpoint: `https://zep.your-domain.xxx/api`
- Documentation: https://docs.getzep.com

## Managing services

### Restarting services

```bash
docker compose -f n8n-docker-compose.yaml restart
docker compose -f flowise-docker-compose.yaml restart
docker compose -f zep-docker-compose.yaml restart
```

### Stopping services

```bash
docker compose -f n8n-docker-compose.yaml down
docker compose -f flowise-docker-compose.yaml down
docker compose -f zep-docker-compose.yaml down
```

### Viewing logs

```bash
docker compose -f n8n-docker-compose.yaml logs
docker compose -f flowise-docker-compose.yaml logs
docker compose -f zep-docker-compose.yaml logs
```

## Security

- All services are accessible only via HTTPS with automatically renewed Let's Encrypt certificates
- Random passwords are created for n8n, Flowise, and PostgreSQL
- Users are created with minimal necessary privileges
- API keys are stored securely in environment variables

## Troubleshooting

- Check your domain's DNS records to ensure they point to the correct IP address
- Verify that ports 80 and 443 are open on your server
- View container logs to detect errors
- For Zep-specific issues, check the Zep logs: `docker compose -f zep-docker-compose.yaml logs zep`

## License

This project is distributed under the MIT License.

## Author

@pavelbelove