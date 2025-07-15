#!/bin/bash

# Fix Frontend Script - Rebuilds and redeploys only the frontend

echo "🔧 Fixing frontend deployment..."

# Check if k3d cluster is running
if ! k3d cluster list | grep -q "todo-app-cluster.*running"; then
    echo "❌ k3d cluster is not running"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace todo-app >/dev/null 2>&1; then
    echo "❌ todo-app namespace doesn't exist. Run ./complete-setup.sh first"
    exit 1
fi

echo "🏗️  Rebuilding frontend with nginx..."

# Rebuild frontend image
cd frontend
docker build -t todo-frontend:latest .
if [ $? -ne 0 ]; then
    echo "❌ Failed to build frontend image"
    exit 1
fi
cd ..

# Import new image to k3d
k3d image import todo-frontend:latest -c todo-app-cluster

echo "🔄 Redeploying frontend..."

# Delete existing frontend deployment
kubectl delete deployment todo-frontend -n todo-app

# Redeploy frontend with updated image
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo-frontend
  namespace: todo-app
  labels:
    app: todo-frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: todo-frontend
  template:
    metadata:
      labels:
        app: todo-frontend
    spec:
      containers:
      - name: todo-frontend
        image: todo-frontend:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 3000
        env:
        - name: REACT_APP_API_URL
          value: "http://localhost:8081"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "100m"
EOF

# Wait for frontend to be ready
echo "⏳ Waiting for frontend to be ready..."
kubectl wait --for=condition=ready pod -l app=todo-frontend -n todo-app --timeout=120s

echo "✅ Frontend redeployed successfully"

# Kill existing port forwards
sudo pkill -f "port-forward" 2>/dev/null || true
sleep 2

echo "🔗 Setting up port forwarding..."

# Start frontend port forward
kubectl port-forward service/todo-frontend-service 8080:3000 -n todo-app >/dev/null 2>&1 &

# Start backend port forward  
kubectl port-forward service/todo-backend-service 8081:3001 -n todo-app >/dev/null 2>&1 &

sleep 5

echo "🧪 Testing connectivity..."

# Test frontend
if curl -s http://localhost:8080 >/dev/null 2>&1; then
    echo "✅ Frontend is working: http://localhost:8080"
else
    echo "❌ Frontend still not responding"
    kubectl logs -l app=todo-frontend -n todo-app --tail=20
fi

# Test backend
if curl -s http://localhost:8081/health >/dev/null 2>&1; then
    echo "✅ Backend is working: http://localhost:8081/health"
else
    echo "❌ Backend not responding"
    kubectl logs -l app=todo-backend -n todo-app --tail=20
fi

echo ""
echo "🎯 Frontend fix complete!"
echo "   Frontend: http://localhost:8080"
echo "   Backend:  http://localhost:8081"
echo ""
echo "📊 Debug commands:"
echo "   Frontend logs: kubectl logs -l app=todo-frontend -n todo-app"
echo "   Backend logs:  kubectl logs -l app=todo-backend -n todo-app"
echo "   Pod status:    kubectl get pods -n todo-app"

# Try to open the frontend
if curl -s http://localhost:8080 >/dev/null 2>&1; then
    open http://localhost:8080 2>/dev/null || echo "Please open http://localhost:8080 in your browser"
fi