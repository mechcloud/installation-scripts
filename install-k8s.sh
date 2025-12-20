#!/bin/bash

echo "=====> Running script for setting up kubernetes .."

echo "=====> Enabling IPv4 forwarding .."
# On each node, create the config file
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.ipv4.ip_forward = 1
EOF

# Apply immediately
sudo sysctl --system

# Disable swap (required for Kubernetes)
echo "=====> Disabling swap .."
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a


echo "=====> Creating docker configuration file .."

mkdir -p /etc/docker
touch /etc/docker/daemon.json
cat > /etc/docker/daemon.json <<EOF
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

# Install docker
source ./install-docker.sh

# Fix package versions
sudo apt-mark hold docker-ce docker-ce-cli containerd.io

echo "=====> Configuring containerd .."
# Update containerd configuration to use systemd cgroup driver
# Generate default config
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Update root path to /mnt/k8s/containerd
sudo sed -i 's|root = "/var/lib/containerd"|root = "/mnt/k8s/containerd"|' /etc/containerd/config.toml

# Enable SystemdCgroup under runc options
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd

## Install Kubernetes components
echo "=====> Installing kubernetes binaries .."

sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable --now kubelet

echo "=====> Initializing Kubernetes cluster .."
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# Set up kubeconfig for the regular user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Allow scheduling pods on control-plane node (optional, for single-node clusters)
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Install calico
echo "=====> Installing Calico network plugin .."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/custom-resources.yaml

echo "=====> Kubernetes setup completed."

watch kubectl get pods --all-namespaces


## Install helm (optional)
echo "=====> Installing Helm .."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
echo "=====> Helm installation completed."


## Install ingress-nginx using helm (optional)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

echo "=====> Installing ingress-nginx using Helm .."
helm -n ingress-nginx upgrade -i ingress-nginx --create-namespace ingress-nginx/ingress-nginx


echo "=====> Script completed."