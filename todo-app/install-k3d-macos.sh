#!/bin/bash

# K3d Installation Script for macOS (K3s in Docker)

echo "🚀 Installing K3d (K3s in Docker) for macOS..."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  This script is designed for macOS. For Linux, use install-k3s.sh"
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker Desktop first."
    echo "   1. Open Docker Desktop"
    echo "   2. Wait for it to start completely"
    echo "   3. Run this script again"
    exit 1
fi

echo "✅ Docker is running"

# Check if k3d is already installed
if command -v k3d &> /dev/null; then
    echo "✅ k3d is already installed"
    k3d version
else
    echo "📦 Installing k3d..."
    
    # Install k3d using curl
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    
    # Check if installation was successful
    if command -v k3d &> /dev/null; then
        echo "✅ k3d installed successfully!"
        k3d version
    else
        echo "❌ k3d installation failed. Trying alternative method..."
        
        # Alternative: Install via Homebrew if available
        if command -v brew &> /dev/null; then
            echo "📦 Installing k3d via Homebrew..."
            brew install k3d
        else
            echo "❌ Please install k3d manually:"
            echo "   1. Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            echo "   2. Run: brew install k3d"
            exit 1
        fi
    fi
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "📦 Installing kubectl..."
    
    if command -v brew &> /dev/null; then
        brew install kubectl
    else
        # Install kubectl directly
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi
    
    if command -v kubectl &> /dev/null; then
        echo "✅ kubectl installed successfully!"
    else
        echo "❌ kubectl installation failed"
        exit 1
    fi
else
    echo "✅ kubectl is already installed"
fi

# Create k3d cluster
CLUSTER_NAME="todo-app-cluster"

# Check if cluster already exists
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "✅ K3d cluster '$CLUSTER_NAME' already exists"
else
    echo "🏗️  Creating k3d cluster '$CLUSTER_NAME'..."
    
    # Create cluster with port mappings for easy access
    k3d cluster create $CLUSTER_NAME \
        --port "3000:30000@loadbalancer" \
        --port "3001:30001@loadbalancer" \
        --port "80:80@loadbalancer" \
        --agents 1 \
        --wait
    
    if [ $? -eq 0 ]; then
        echo "✅ K3d cluster created successfully!"
    else
        echo "❌ Failed to create k3d cluster"
        exit 1
    fi
fi

# Set kubeconfig context
echo "🔧 Setting up kubectl context..."
k3d kubeconfig merge $CLUSTER_NAME --kubeconfig-switch-context

# Verify cluster is running
echo "🔍 Verifying cluster..."
if kubectl cluster-info &> /dev/null; then
    echo "✅ Cluster is accessible!"
    kubectl get nodes
else
    echo "❌ Cannot access cluster"
    exit 1
fi

# Install NGINX Ingress Controller
echo "📦 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for ingress controller to be ready
echo "⏳ Waiting for NGINX Ingress Controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo "✅ K3d setup complete!"
echo ""
echo "📋 Cluster Information:"
echo "   Cluster name: $CLUSTER_NAME"
echo "   Context: k3d-$CLUSTER_NAME"
echo "   Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo ""
echo "🌐 Port Mappings:"
echo "   Frontend: localhost:3000 → cluster:30000"
echo "   Backend:  localhost:3001 → cluster:30001"
echo "   HTTP:     localhost:80 → cluster:80"
echo ""
echo "📊 Useful commands:"
echo "   Cluster status: k3d cluster list"
echo "   Start cluster:  k3d cluster start $CLUSTER_NAME"
echo "   Stop cluster:   k3d cluster stop $CLUSTER_NAME"
echo "   Delete cluster: k3d cluster delete $CLUSTER_NAME"
echo ""
echo "🚀 Ready to deploy Todo App!"
echo "   Run: ./deploy-k3d.sh"