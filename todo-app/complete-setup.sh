#!/bin/bash

# Complete Todo App Setup Script for macOS - ROBUST VERSION

echo "🚀 Complete Todo App Setup for macOS..."

# Enable strict error handling
set -e  # Exit on any command failure
set -u  # Exit on undefined variables

# Function to check command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait with timeout
wait_for_condition() {
    local description="$1"
    local command="$2"
    local timeout="${3:-120}"
    local interval="${4:-5}"
    
    echo "⏳ Waiting for: $description (timeout: ${timeout}s)"
    
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if eval "$command" >/dev/null 2>&1; then
            echo "✅ $description - Ready!"
            return 0
        fi
        echo "   ... still waiting ($elapsed/${timeout}s)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo "❌ Timeout waiting for: $description"
    return 1
}

# Function to check if resource exists
resource_exists() {
    kubectl get "$1" "$2" -n "${3:-default}" >/dev/null 2>&1
}

echo "🧹 Step 1: Complete Cleanup"
echo "Removing any existing resources..."

# Kill any existing port forwards
sudo pkill -f "port-forward" 2>/dev/null || true

# Delete Kubernetes resources
if kubectl get namespace todo-app >/dev/null 2>&1; then
    echo "Deleting existing todo-app namespace..."
    kubectl delete namespace todo-app --force --grace-period=0 2>/dev/null || true
    
    # Wait for namespace to be fully deleted
    echo "⏳ Waiting for namespace deletion..."
    while kubectl get namespace todo-app >/dev/null 2>&1; do
        echo "   ... namespace still exists, waiting..."
        sleep 2
    done
    echo "✅ Namespace deleted"
fi

# Delete k3d cluster
if k3d cluster list | grep -q "todo-app-cluster"; then
    echo "Deleting existing k3d cluster..."
    k3d cluster delete todo-app-cluster || true
    echo "✅ K3d cluster deleted"
fi

# Remove Docker images
echo "Cleaning Docker images..."
docker rmi todo-backend:latest 2>/dev/null || true
docker rmi todo-frontend:latest 2>/dev/null || true
docker rmi postgres:15-alpine 2>/dev/null || true

# Clean Docker system
docker container prune -f >/dev/null 2>&1 || true
docker volume prune -f >/dev/null 2>&1 || true

echo "✅ Cleanup complete!"

echo ""
echo "📦 Step 2: Installing Dependencies"

# Check Docker
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi
echo "✅ Docker is running"

# Install k3d
if ! command_exists k3d; then
    echo "Installing k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    
    if ! command_exists k3d; then
        echo "k3d installation failed. Trying Homebrew..."
        if command_exists brew; then
            brew install k3d
        else
            echo "❌ Please install k3d manually or install Homebrew first"
            exit 1
        fi
    fi
fi

# Verify k3d installation
if ! command_exists k3d; then
    echo "❌ k3d installation failed"
    exit 1
fi
echo "✅ k3d is installed: $(k3d version | head -1)"

# Install kubectl
if ! command_exists kubectl; then
    echo "Installing kubectl..."
    if command_exists brew; then
        brew install kubectl
    else
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi
fi

# Verify kubectl installation
if ! command_exists kubectl; then
    echo "❌ kubectl installation failed"
    exit 1
fi
echo "✅ kubectl is installed"

echo ""
echo "🏗️  Step 3: Creating k3d Cluster"

# Create k3d cluster
echo "Creating k3d cluster 'todo-app-cluster'..."
if ! k3d cluster create todo-app-cluster \
    --port "3000:30000@loadbalancer" \
    --port "3001:30001@loadbalancer" \
    --port "8080:80@loadbalancer" \
    --agents 1 \
    --wait; then
    echo "❌ Failed to create k3d cluster"
    exit 1
fi

echo "✅ k3d cluster created successfully"

# Wait for cluster to be fully ready
wait_for_condition "cluster to be accessible" "kubectl cluster-info" 60 5

# Verify cluster
echo "📋 Cluster status:"
kubectl get nodes
k3d cluster list

echo ""
echo "📁 Step 4: Ensuring Kubernetes Manifests Exist"

# Create k8s directory if it doesn't exist
mkdir -p k8s

# Create namespace manifest
cat > k8s/01-namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: todo-app
  labels:
    name: todo-app
EOF

# Verify all required k8s files exist
required_files=("01-namespace.yaml" "02-database.yaml" "03-backend.yaml" "04-frontend.yaml")
for file in "${required_files[@]}"; do
    if [[ ! -f "k8s/$file" ]]; then
        echo "❌ Missing k8s manifest: k8s/$file"
        echo "Please ensure all Kubernetes manifest files are in the k8s/ directory"
        exit 1
    fi
done
echo "✅ All Kubernetes manifests exist"

echo ""
echo "📦 Step 5: Building Docker Images"

# Build backend
echo "Building backend image..."
cd backend
if [[ ! -f "package.json" ]]; then
    echo "❌ backend/package.json not found"
    exit 1
fi

if ! docker build -t todo-backend:latest .; then
    echo "❌ Failed to build backend image"
    exit 1
fi
cd ..

# Build frontend
echo "Building frontend image..."
cd frontend
if [[ ! -f "package.json" ]]; then
    echo "❌ frontend/package.json not found"
    exit 1
fi

if ! docker build -t todo-frontend:latest .; then
    echo "❌ Failed to build frontend image"
    exit 1
fi
cd ..

echo "✅ Docker images built successfully"

# Verify images exist
if ! docker images | grep -q "todo-backend.*latest"; then
    echo "❌ Backend image not found"
    exit 1
fi

if ! docker images | grep -q "todo-frontend.*latest"; then
    echo "❌ Frontend image not found"
    exit 1
fi

echo ""
echo "📥 Step 6: Importing Images to k3d"

# Import images
if ! k3d image import todo-backend:latest -c todo-app-cluster; then
    echo "❌ Failed to import backend image"
    exit 1
fi

if ! k3d image import todo-frontend:latest -c todo-app-cluster; then
    echo "❌ Failed to import frontend image"
    exit 1
fi

echo "✅ Images imported to k3d cluster"

echo ""
echo "🚀 Step 7: Deploying to Kubernetes"

# Deploy applications step by step with verification
echo "Creating namespace..."
if ! kubectl apply -f k8s/01-namespace.yaml; then
    echo "❌ Failed to create namespace"
    exit 1
fi

# Verify namespace exists
wait_for_condition "namespace to be active" "kubectl get namespace todo-app" 30 2

echo "Deploying database..."
if ! kubectl apply -f k8s/02-database.yaml; then
    echo "❌ Failed to deploy database"
    exit 1
fi

echo "Waiting for database to be ready..."
wait_for_condition "database pod to be ready" "kubectl wait --for=condition=ready pod -l app=todo-database -n todo-app --timeout=10s" 180 10

echo "Deploying backend..."
if ! kubectl apply -f k8s/03-backend.yaml; then
    echo "❌ Failed to deploy backend"
    exit 1
fi

echo "Waiting for backend to be ready..."
wait_for_condition "backend pod to be ready" "kubectl wait --for=condition=ready pod -l app=todo-backend -n todo-app --timeout=10s" 120 10

echo "Deploying frontend..."
if ! kubectl apply -f k8s/04-frontend.yaml; then
    echo "❌ Failed to deploy frontend"
    exit 1
fi

echo "Waiting for frontend to be ready..."
wait_for_condition "frontend pod to be ready" "kubectl wait --for=condition=ready pod -l app=todo-frontend -n todo-app --timeout=10s" 120 10

echo ""
echo "🔗 Step 8: Creating Access Services"

# Create NodePort services
echo "Creating NodePort services..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: todo-frontend-nodeport
  namespace: todo-app
spec:
  type: NodePort
  selector:
    app: todo-frontend
  ports:
  - port: 3000
    targetPort: 3000
    nodePort: 30000
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: todo-backend-nodeport
  namespace: todo-app
spec:
  type: NodePort
  selector:
    app: todo-backend
  ports:
  - port: 3001
    targetPort: 3001
    nodePort: 30001
EOF

echo "✅ NodePort services created"

echo ""
echo "🎉 Deployment Complete!"
echo ""
echo "📋 Application Status:"
kubectl get pods -n todo-app
echo ""
kubectl get services -n todo-app

echo ""
echo "🔍 Final Verification..."

# Verify all pods are running
all_pods_ready=true
for app in todo-database todo-backend todo-frontend; do
    if ! kubectl get pods -l app=$app -n todo-app | grep -q "Running"; then
        echo "⚠️  $app is not running properly"
        all_pods_ready=false
    fi
done

if $all_pods_ready; then
    echo "✅ All pods are running successfully"
else
    echo "❌ Some pods are not running. Check with: kubectl get pods -n todo-app"
    exit 1
fi

echo ""
echo "🌐 Setting up Access..."

# Test connectivity and setup access
echo "Testing connectivity..."
if curl -s --connect-timeout 5 http://localhost:3000 >/dev/null 2>&1; then
    echo "✅ Frontend is accessible at http://localhost:3000"
    open http://localhost:3000 2>/dev/null || echo "Please open http://localhost:3000 in your browser"
else
    echo "⚠️  Direct access not available, setting up port forwarding..."
    
    # Start port forwarding in background
    kubectl port-forward service/todo-frontend-service 8080:3000 -n todo-app >/dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    
    # Wait a moment for port forward to establish
    sleep 5
    
    if curl -s --connect-timeout 5 http://localhost:8080 >/dev/null 2>&1; then
        echo "✅ Frontend accessible via port forwarding at http://localhost:8080"
        open http://localhost:8080 2>/dev/null || echo "Please open http://localhost:8080 in your browser"
    else
        echo "⚠️  Port forwarding setup failed. Try manually:"
        echo "   kubectl port-forward service/todo-frontend-service 8080:3000 -n todo-app"
    fi
fi

echo ""
echo "🎯 Success! Your 3-pod Todo App is running:"
echo "   📊 Check status: kubectl get pods -n todo-app"
echo "   📋 View logs:    kubectl logs -l app=todo-frontend -n todo-app"
echo "   🔧 Port forward: kubectl port-forward service/todo-frontend-service 8080:3000 -n todo-app"
echo "   🧹 Clean up:     ./destroy-all.sh"
echo ""
echo "✨ Enjoy your Todo App!"