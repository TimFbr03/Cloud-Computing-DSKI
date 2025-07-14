#!/bin/bash

# Auto-Deploy Script - Only deploys the app (assumes k3d cluster exists)

echo "🚀 Auto-deploying Todo App to existing k3d cluster..."

# Enable strict error handling
set -e

# Check if k3d cluster exists and is running
if ! k3d cluster list | grep -q "todo-app-cluster.*running"; then
    echo "❌ k3d cluster 'todo-app-cluster' is not running"
    echo "   Start it with: k3d cluster start todo-app-cluster"
    echo "   Or create it with: ./complete-setup.sh"
    exit 1
fi

# Check if kubectl is connected
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Cannot connect to cluster. Fixing..."
    k3d kubeconfig merge todo-app-cluster --kubeconfig-switch-context
fi

echo "✅ Connected to k3d cluster"

# Function to wait for resource
wait_for_resource() {
    local resource_type="$1"
    local selector="$2" 
    local namespace="$3"
    local timeout="${4:-120}"
    
    echo "⏳ Waiting for $resource_type to be ready..."
    if ! kubectl wait --for=condition=ready "$resource_type" -l "$selector" -n "$namespace" --timeout="${timeout}s"; then
        echo "❌ Timeout waiting for $resource_type"
        kubectl get pods -n "$namespace"
        kubectl describe pods -l "$selector" -n "$namespace"
        exit 1
    fi
    echo "✅ $resource_type is ready"
}

# Clean up existing deployment
echo "🧹 Cleaning existing deployment..."
kubectl delete namespace todo-app --force --grace-period=0 2>/dev/null || true

# Wait for namespace to be fully deleted
while kubectl get namespace todo-app >/dev/null 2>&1; do
    echo "   ... waiting for namespace deletion"
    sleep 2
done

# Build and import images
echo "📦 Building and importing Docker images..."

cd backend
docker build -t todo-backend:latest . >/dev/null 2>&1
cd ..

cd frontend  
docker build -t todo-frontend:latest . >/dev/null 2>&1
cd ..

k3d image import todo-backend:latest -c todo-app-cluster >/dev/null 2>&1
k3d image import todo-frontend:latest -c todo-app-cluster >/dev/null 2>&1

echo "✅ Images built and imported"

# Deploy everything with embedded manifests
echo "🚀 Deploying application..."

# Create namespace
kubectl create namespace todo-app

# Deploy database
echo "📊 Deploying database..."
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-init
  namespace: todo-app
data:
  init.sql: |
    CREATE TABLE IF NOT EXISTS todos (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        completed BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX IF NOT EXISTS idx_todos_created_at ON todos(created_at);
    CREATE INDEX IF NOT EXISTS idx_todos_completed ON todos(completed);
    INSERT INTO todos (title, description) VALUES
        ('Setup K3d environment', 'Deploy the todo app on K3d cluster'),
        ('Create database schema', 'Design and implement the PostgreSQL database structure'),
        ('Build REST API', 'Develop the backend API with Node.js and Express'),
        ('Design frontend UI', 'Create a responsive React frontend for the todo app');
    UPDATE todos SET completed = TRUE WHERE title = 'Setup K3d environment';
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: todo-app
type: Opaque
data:
  POSTGRES_USER: dG9kb3VzZXI=
  POSTGRES_PASSWORD: dG9kb3Bhc3M=
  POSTGRES_DB: dG9kb2FwcA==
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: todo-app
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo-database
  namespace: todo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: todo-database
  template:
    metadata:
      labels:
        app: todo-database
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          valueFrom: {secretKeyRef: {name: postgres-secret, key: POSTGRES_DB}}
        - name: POSTGRES_USER
          valueFrom: {secretKeyRef: {name: postgres-secret, key: POSTGRES_USER}}
        - name: POSTGRES_PASSWORD
          valueFrom: {secretKeyRef: {name: postgres-secret, key: POSTGRES_PASSWORD}}
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: postgres-init
          mountPath: /docker-entrypoint-initdb.d
        resources:
          requests: {memory: "128Mi", cpu: "100m"}
          limits: {memory: "512Mi", cpu: "500m"}
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
      - name: postgres-init
        configMap:
          name: postgres-init
---
apiVersion: v1
kind: Service
metadata:
  name: todo-database-service
  namespace: todo-app
spec:
  selector:
    app: todo-database
  ports:
  - port: 5432
    targetPort: 5432
EOF

wait_for_resource "pod" "app=todo-database" "todo-app" 180

# Deploy backend
echo "🔧 Deploying backend..."
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: todo-app
data:
  DATABASE_URL: "postgresql://todouser:todopass@todo-database-service:5432/todoapp"
  PORT: "3001"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo-backend
  namespace: todo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: todo-backend
  template:
    metadata:
      labels:
        app: todo-backend
    spec:
      containers:
      - name: todo-backend
        image: todo-backend:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 3001
        env:
        - name: DATABASE_URL
          valueFrom: {configMapKeyRef: {name: backend-config, key: DATABASE_URL}}
        - name: PORT
          valueFrom: {configMapKeyRef: {name: backend-config, key: PORT}}
        livenessProbe:
          httpGet: {path: /health, port: 3001}
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet: {path: /health, port: 3001}
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          requests: {memory: "64Mi", cpu: "50m"}
          limits: {memory: "256Mi", cpu: "200m"}
---
apiVersion: v1
kind: Service
metadata:
  name: todo-backend-service
  namespace: todo-app
spec:
  selector:
    app: todo-backend
  ports:
  - port: 3001
    targetPort: 3001
EOF

wait_for_resource "pod" "app=todo-backend" "todo-app" 120

# Deploy frontend
echo "🌐 Deploying frontend..."
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
  namespace: todo-app
data:
  REACT_APP_API_URL: "http://localhost:3001"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo-frontend
  namespace: todo-app
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
          valueFrom: {configMapKeyRef: {name: frontend-config, key: REACT_APP_API_URL}}
        livenessProbe:
          httpGet: {path: /, port: 3000}
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet: {path: /, port: 3000}
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          requests: {memory: "64Mi", cpu: "50m"}
          limits: {memory: "256Mi", cpu: "100m"}
---
apiVersion: v1
kind: Service
metadata:
  name: todo-frontend-service
  namespace: todo-app
spec:
  selector:
    app: todo-frontend
  ports:
  - port: 3000
    targetPort: 3000
---
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
---
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

wait_for_resource "pod" "app=todo-frontend" "todo-app" 120

echo ""
echo "🎉 Deployment Complete!"
kubectl get pods -n todo-app

echo ""
echo "🔗 Setting up access..."

# Kill any existing port forwards
sudo pkill -f "port-forward.*todo" 2>/dev/null || true
sleep 2

# Start port forwarding in background
kubectl port-forward service/todo-frontend-service 8080:3000 -n todo-app >/dev/null 2>&1 &
PORT_FORWARD_PID=$!

sleep 5

if curl -s http://localhost:8080 >/dev/null 2>&1; then
    echo "✅ Todo App is accessible at: http://localhost:8080"
    open http://localhost:8080 2>/dev/null || echo "Please open http://localhost:8080 in your browser"
else
    echo "⚠️  Port forwarding setup failed. Try manually:"
    echo "   kubectl port-forward service/todo-frontend-service 8080:3000 -n todo-app"
fi

echo ""
echo "🎯 Auto-deployment successful!"
echo "   📊 Status: kubectl get pods -n todo-app"
echo "   📋 Logs:   kubectl logs -l app=todo-frontend -n todo-app"
echo "   🔧 Access: kubectl port-forward service/todo-frontend-service 8080:3000 -n todo-app"
echo "   🧹 Clean:  ./destroy-all.sh"
echo ""
echo "✨ Your 3-pod Todo App is ready!"