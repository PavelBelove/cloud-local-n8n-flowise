#!/bin/bash

echo "Installing Docker and Docker Compose..."

# Setting environment variables to prevent interactive prompts
export DEBIAN_FRONTEND=noninteractive

# Configuring debconf for automatic service restart
echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
sudo bash -c "cat > /etc/apt/apt.conf.d/70debconf << EOF
Dpkg::Options {
   \"--force-confdef\";
   \"--force-confold\";
}
EOF"

# apt options for automatic confirmation and preventing prompts
APT_OPTIONS="-o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef -y"

# Check if Docker is installed
if ! [ -x "$(command -v docker)" ]; then
  echo "Docker is not installed. Installing Docker..."
  
  # Update system
  sudo DEBIAN_FRONTEND=noninteractive apt-get -qq update
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to update package list"
    exit 1
  fi
  
  # Install required packages
  sudo DEBIAN_FRONTEND=noninteractive apt-get -qq install -y ca-certificates curl gnupg lsb-release $APT_OPTIONS
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install required packages"
    exit 1
  fi
  
  # Create directory for keys
  sudo install -m 0755 -d /etc/apt/keyrings
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create directory for keys"
    exit 1
  fi
  
  # Download Docker GPG key
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to download Docker GPG key"
    exit 1
  fi
  
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  
  # Add Docker repository
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to add Docker repository"
    exit 1
  fi
  
  # Update packages
  sudo DEBIAN_FRONTEND=noninteractive apt-get -qq update
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to update package list after adding Docker repository"
    exit 1
  fi
  
  # Install Docker
  sudo DEBIAN_FRONTEND=noninteractive apt-get -qq install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin $APT_OPTIONS
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install Docker"
    exit 1
  fi
  
  # Add current user to docker group
  sudo usermod -aG docker $USER
  if [ $? -ne 0 ]; then
    echo "WARNING: Failed to add user to the docker group. You may need root privileges to run docker."
  fi
  
  echo "Docker successfully installed"
else
  echo "Docker is already installed"
fi

# Check if Docker is working
docker --version
if [ $? -ne 0 ]; then
  echo "ERROR: Docker is installed but not working correctly"
  exit 1
fi

echo "✅ Docker and Docker Compose successfully installed and running"
exit 0