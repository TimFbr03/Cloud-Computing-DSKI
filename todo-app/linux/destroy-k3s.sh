#!/bin/bash

# K3s Cleanup Script for Todo App

echo "🧹 Cleaning up Todo App from K3s..."

# Set kubectl command (k3s specific or regular kubectl)
if command -v kubectl &> /dev/null; then
    KUBECTL="kubectl"
elif command -v k3s &> /dev/null; then
    KUBECTL="sudo k3s kubectl"
else
    echo "❌ Neither kubectl nor k3s command found."
    exit 1
fi

# Delete the entire namespace (this removes all resources)
echo "Deleting todo-app namespace and all resources..."
$KUBECTL delete namespace todo-app

# Wait for cleanup to complete
echo "⏳ Waiting for cleanup to complete..."
$KUBECTL wait --for=delete namespace/todo-app --timeout=60s 2>/dev/null || true

# Optional: Remove Docker images
read -p "Do you want to remove Docker images as well? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing Docker images from Docker..."
    docker rmi todo-backend:latest 2>/dev/null || true
    docker rmi todo-frontend:latest 2>/dev/null || true
    
    echo "Removing images from K3s..."
    sudo k3s ctr images rm docker.io/library/todo-backend:latest 2>/dev/null || true
    sudo k3s ctr images rm docker.io/library/todo-frontend:latest 2>/dev/null || true
    echo "✅ Docker images removed"
fi

# Optional: Remove persistent data
read -p "Do you want to remove persistent data? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing persistent volumes..."
    sudo rm -rf /var/lib/rancher/k3s/storage/pvc-* 2>/dev/null || true
    echo "✅ Persistent data removed"
fi

echo "✅ Cleanup complete!"
echo ""
echo "📋 Verify cleanup:"
echo "   Namespaces: $KUBECTL get namespaces"
echo "   Pods:       $KUBECTL get pods --all-namespaces | grep todo"
echo "   K3s status: sudo systemctl status k3s"

# Optional: Uninstall K3s completely
read -p "Do you want to uninstall K3s completely? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Uninstalling K3s..."
    sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || echo "K3s uninstall script not found"
    echo "✅ K3s uninstalled"
fi#!/bin/bash

# Kubernetes Cleanup Script for Todo App

echo "🧹 Cleaning up Todo App from Kubernetes..."

# Delete the entire namespace (this removes all resources)
echo "Deleting todo-app namespace and all resources..."
kubectl delete namespace todo-app

# Wait for cleanup to complete
echo "⏳ Waiting for cleanup to complete..."
kubectl wait --for=delete namespace/todo-app --timeout=60s

# Optional: Remove Docker images
read -p "Do you want to remove Docker images as well? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing Docker images..."
    docker rmi todo-backend:latest 2>/dev/null || true
    docker rmi todo-frontend:latest 2>/dev/null || true
    echo "✅ Docker images removed"
fi

echo "✅ Cleanup complete!"
echo ""
echo "📋 Verify cleanup:"
echo "   Namespaces: kubectl get namespaces"
echo "   Pods:       kubectl get pods --all-namespaces | grep todo"