#!/bin/bash

# K3s Deployment Script for Todo App

echo "🚀 Deploying Todo App to K3s..."

# Check if k3s is available
if ! command -v k3s &> /dev/null && ! command -v kubectl &> /dev/null; then
    echo "❌ K3s is not installed. Please run ./install-k3s.sh first."
    exit 1
fi

# Set kubectl command (k3s specific or regular kubectl)
if command -v kubectl &> /dev/null; then
    KUBECTL="kubectl"
elif command -v k3s &> /dev/null; then
    KUBECTL="sudo k3s kubectl"
else
    echo "❌ Neither kubectl nor k3s command found."
    exit 1
fi

# Check if cluster is accessible
if ! $KUBECTL cluster-info &> /dev/null; then
    echo "❌ Cannot access K3s cluster. Is K3s running?"
    echo "   Try: sudo systemctl start k3s"
    exit 1
fi

echo "✅ K3s cluster is accessible"

# Import Docker images to k3s (important for local images)
echo "📦 Importing Docker images to K3s..."

# Build Docker images first
echo "Building Docker images..."

# Build backend image
echo "Building backend image..."
cd backend
if ! docker build -t todo-backend:latest .; then
    echo "❌ Failed to build backend image"
    exit 1
fi
cd ..

# Build frontend image  
echo "Building frontend image..."
cd frontend
if ! docker build -t todo-frontend:latest .; then
    echo "❌ Failed to build frontend image"
    exit 1
fi
cd ..

# Import images to k3s
echo "Importing images to K3s..."
docker save todo-backend:latest | sudo k3s ctr images import -
docker save todo-frontend:latest | sudo k3s ctr images import -

echo "✅ Docker images imported to K3s"

# Apply Kubernetes manifests
echo "🚀 Deploying to K3s..."

# Create namespace
echo "Creating namespace..."
$KUBECTL apply -f k8s/01-namespace.yaml

# Deploy database
echo "Deploying database..."
$KUBECTL apply -f k8s/02-database.yaml

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
$KUBECTL wait --for=condition=ready pod -l app=todo-database -n todo-app --timeout=180s

# Deploy backend
echo "Deploying backend..."
$KUBECTL apply -f k8s/03-backend.yaml

# Wait for backend to be ready
echo "⏳ Waiting for backend to be ready..."
$KUBECTL wait --for=condition=ready pod -l app=todo-backend -n todo-app --timeout=120s

# Deploy frontend
echo "Deploying frontend..."
$KUBECTL apply -f k8s/04-frontend.yaml

# Wait for frontend to be ready
echo "⏳ Waiting for frontend to be ready..."
$KUBECTL wait --for=condition=ready pod -l app=todo-frontend -n todo-app --timeout=120s

# Deploy ingress
echo "Deploying ingress..."
$KUBECTL apply -f k8s/05-ingress.yaml

echo "✅ Deployment complete!"

# Show status
echo ""
echo "📋 Pod Status:"
$KUBECTL get pods -n todo-app

echo ""
echo "🌐 Services:"
$KUBECTL get services -n todo-app

echo ""
echo "🔗 Ingress:"
$KUBECTL get ingress -n todo-app

echo ""
echo "🌐 Access your Todo App:"
echo ""
echo "   Option 1 - Port Forward (Recommended):"
echo "   $KUBECTL port-forward service/todo-frontend-service 3000:3000 -n todo-app &"
echo "   Then visit: http://localhost:3000"
echo ""
echo "   Option 2 - Add to /etc/hosts:"
echo "   echo '127.0.0.1 todo-app.local' | sudo tee -a /etc/hosts"
echo "   Then visit: http://todo-app.local"
echo ""
echo "📊 Useful K3s commands:"
echo "   View logs:       $KUBECTL logs -l app=<app-name> -n todo-app"
echo "   Scale app:       $KUBECTL scale deployment <deployment-name> --replicas=2 -n todo-app"
echo "   Delete app:      $KUBECTL delete namespace todo-app"
echo "   K3s status:      sudo systemctl status k3s"
echo "   Stop K3s:        sudo systemctl stop k3s"
echo "   Start K3s:       sudo systemctl start k3s"

echo ""
echo "🎉 Todo App is now running on K3s!"
echo "   Run this to access: $KUBECTL port-forward service/todo-frontend-service 3000:3000 -n todo-app"