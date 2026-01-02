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


## Install Kubernetes packages
echo "=====> Installing kubernetes packages .."

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

echo "=====> Holding kubernetes package versions .."
# Fix package versions
sudo apt-mark hold kubelet kubeadm kubectl

echo "=====> Enabling kubelet service .."
# Enable kubelet service
sudo systemctl enable --now kubelet


echo "=====> Initializing Kubernetes cluster .."
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# Set up kubeconfig for the regular user
echo "=====> Setting up kubeconfig for the user .."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Allow scheduling pods on control-plane node (optional, for single-node clusters)
echo "=====> Allowing scheduling on control-plane node .."
kubectl taint nodes --all node-role.kubernetes.io/control-plane-


# Install calico
echo "=====> Installing Calico network plugin .."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/tigera-operator.yaml

echo "=====> Waiting for Tigera operator to be ready..."
kubectl wait --for=condition=Available deployment/tigera-operator -n tigera-operator --timeout=300s

echo "=====> Waiting for Tigera CRDs to be registered in the API server..."
# Give the operator time to create the CRDs
until kubectl get crd installations.operator.tigera.io 2>/dev/null; do
  echo "Waiting for installations CRD..."
  sleep 5
done

until kubectl get crd apiservers.operator.tigera.io 2>/dev/null; do
  echo "Waiting for apiservers CRD..."
  sleep 5
done

echo "=====> Creating Calico custom resources .."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/custom-resources.yaml

echo "=====> Waiting for Calico networking pods to reach 'Ready' state..."
# Wait for calico-system namespace to exist first
until kubectl get namespace calico-system 2>/dev/null; do
  echo "Waiting for calico-system namespace..."
  sleep 5
done

kubectl wait --for=condition=Ready pod --all -n tigera-operator --timeout=300s
kubectl wait --for=condition=Ready pod --all -n calico-system --timeout=600s

echo "=====> Verifying all nodes are Ready..."
kubectl get nodes

echo "=====> Kubernetes setup completed."

