#!/bin/bash

echo "=====> Starting complete uninstallation of Kubernetes and components .."

# Remove Helm releases
if command -v helm &> /dev/null; then
    echo "=====> Removing Ingress-Nginx via Helm .."
    helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null
    kubectl delete namespace ingress-nginx 2>/dev/null
    
    echo "=====> Removing Helm binary .."
    sudo rm -f /usr/local/bin/helm
    rm -f get_helm.sh
fi

# Reset Kubernetes cluster
echo "=====> Resetting Kubernetes cluster .."
sudo kubeadm reset --force

echo "=====> Cleaning up networking .."
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
sudo ip link delete cali0 2>/dev/null
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/calico

# Uninstall Kubernetes packages
echo "=====> Removing Kubernetes packages .."
sudo apt-mark unhold kubelet kubeadm kubectl 2>/dev/null
sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni 'kube*' 
sudo apt-get autoremove -y
sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Restore system settings
echo "=====> Re-enabling swap .."
sudo sed -i '/ swap / s/^#//g' /etc/fstab
sudo swapon -a

echo "=====> Disabling IPv4 forwarding .."
sudo rm -f /etc/sysctl.d/k8s.conf
sudo sysctl --system

# Remove local user configuration
echo "=====> Cleaning up local user config .."
rm -rf $HOME/.kube

echo "=====> Uninstallation completed."

