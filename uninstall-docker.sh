#!/bin/bash

echo "=====> Uninstalling Docker .."

echo "=====> Removing docker packages .."
sudo apt-mark unhold docker-ce docker-ce-cli containerd.io 2>/dev/null
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
sudo apt-get autoremove -y

echo "=====> Removing docker directories and configuration .."
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /mnt/k8s/docker
sudo rm -rf /mnt/k8s/containerd
sudo rm -rf /etc/docker

echo "=====> Removing docker repository .."
sudo rm -f /etc/apt/sources.list.d/docker.sources
sudo rm -f /etc/apt/keyrings/docker.asc

echo "=====> Removing user from docker group .."
sudo gpasswd -d $USER docker 2>/dev/null

echo "=====> Docker uninstallation completed."

