#!/bin/bash

echo "=====> Running script for setting up docker .."

echo "=====> Setting up Docker apt repository .."
# Setup Docker apt repository
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "=====> Adding Docker apt repository .."
# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

echo "=====> Creating docker directories .."
sudo mkdir -p /etc/docker
sudo mkdir -p /mnt/k8s/docker

echo "=====> Creating docker configuration file .."

sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "data-root": "/mnt/k8s/docker"
}
EOF

echo "=====> Installing docker packages .."
# Install Docker Engine, CLI, and Containerd
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=====> Holding docker package versions .."
# Fix package versions
sudo apt-mark hold docker-ce docker-ce-cli containerd.io

echo "=====> Creating containerd data directory .."
sudo mkdir -p /mnt/k8s/containerd

echo "=====> Configuring containerd .."
# Update containerd configuration to use systemd cgroup driver
# Generate default config
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Update root path to /mnt/k8s/containerd
sudo sed -i 's|root = "/var/lib/containerd"|root = "/mnt/k8s/containerd"|' /etc/containerd/config.toml

# Enable SystemdCgroup under runc options
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

echo "=====> Restarting containerd .."
# Restart containerd
sudo systemctl restart containerd

echo "=====> Cleaning up .."
# Clean up
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

echo "=====> Adding user to docker group .."
sudo usermod -aG docker $USER

# Use sg to run the remaining verification steps
sg docker -c '
    echo "=====> Verifying docker installation .."
    docker version
    echo "=====> Docker setup script completed."
'

