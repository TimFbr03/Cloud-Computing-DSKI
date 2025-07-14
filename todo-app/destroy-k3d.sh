#!/bin/bash

# Complete Destruction Script

echo "💥 Destroying Todo App completely..."

echo "🛑 Stopping any port forwards..."
sudo pkill -f "port-forward" 2>/dev/null || true
sudo pkill -f "kubectl.*todo" 2>/dev/null || true

echo "🗑️  Deleting Kubernetes namespace..."
kubectl delete namespace todo-app --force --grace-period=0 2>/dev/null || true

echo "🏗️  Destroying k3d cluster..."
k3d cluster delete todo-app-cluster 2>/dev/null || true

echo "🐳 Removing Docker images..."
docker rmi todo-backend:latest 2>/dev/null || true
docker rmi todo-frontend:latest 2>/dev/null || true
docker rmi postgres:15-alpine 2>/dev/null || true

echo "🧹 Cleaning Docker system..."
docker container prune -f
docker volume prune -f
docker network prune -f

echo "✅ Complete destruction finished!"
echo ""
echo "🔄 To redeploy from scratch:"
echo "   ./complete-setup.sh"