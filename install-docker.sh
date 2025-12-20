#!/bin/bash

echo "=====> Running script for setting up docker .."

# Setup Docker apt repository
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

# Install Docker Engine, CLI, and Containerd
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Clean up
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

# Add ubuntu user to docker group (optional, for non-root access)
sudo usermod -aG docker $USER
newgrp docker

# Verify Docker is running
docker version

echo "=====> Docker setup script completed."