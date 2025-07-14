#!/bin/bash

# K3s Installation Script for Todo App

echo "🚀 Installing K3s for Todo App..."

# Check if k3s is already installed
if command -v k3s &> /dev/null; then
    echo "✅ K3s is already installed"
    k3s --version
else
    echo "📦 Installing K3s..."
    
    # Install k3s with embedded registry and traefik disabled (we'll use our own ingress)
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik --write-kubeconfig-mode 644" sh -
    
    # Wait for k3s to be ready
    echo "⏳ Waiting for K3s to be ready..."
    sleep 10
    
    # Check if k3s is running
    if sudo k3s kubectl get nodes; then
        echo "✅ K3s installed successfully!"
    else
        echo "❌ K3s installation failed"
        exit 1
    fi
fi

# Setup kubectl to work with k3s
echo "🔧 Setting up kubectl for K3s..."

# Copy k3s kubeconfig to standard location
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config 2>/dev/null || {
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
}

# Fix permissions
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

# Test kubectl
if kubectl get nodes; then
    echo "✅ kubectl configured successfully!"
else
    echo "⚠️  Using k3s kubectl instead..."
    alias kubectl="sudo k3s kubectl"
    echo "alias kubectl=\"sudo k3s kubectl\"" >> ~/.bashrc
fi

# Install NGINX Ingress Controller for k3s
echo "📦 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for ingress controller to be ready
echo "⏳ Waiting for NGINX Ingress Controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo "✅ K3s setup complete!"
echo ""
echo "📋 K3s Information:"
echo "   Version: $(k3s --version | head -1)"
echo "   Config:  ~/.kube/config"
echo "   Status:  $(kubectl get nodes --no-headers | awk '{print $2}')"
echo ""
echo "🚀 Ready to deploy Todo App!"
echo "   Run: ./deploy-k3s.sh"