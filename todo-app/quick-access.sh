#!/bin/bash

# Quick Access Script for Todo App

echo "🔗 Setting up access to Todo App..."

# Check if app is running
if ! kubectl get namespace todo-app &>/dev/null; then
    echo "❌ Todo app is not deployed. Run ./complete-setup.sh first."
    exit 1
fi

# Check pod status
echo "📋 Current pod status:"
kubectl get pods -n todo-app

# Kill any existing port forwards
echo "🛑 Stopping existing port forwards..."
sudo pkill -f "port-forward.*todo" 2>/dev/null || true
sleep 2

# Function to check if port is available
check_port() {
    if lsof -i:$1 &>/dev/null; then
        echo "⚠️  Port $1 is busy"
        return 1
    fi
    return 0
}

echo ""
echo "🌐 Setting up access..."

# Try direct access first
if curl -s http://localhost:3000 &>/dev/null; then
    echo "✅ Direct access available!"
    echo "   Frontend: http://localhost:3000"
    echo "   Backend:  http://localhost:3001"
    open http://localhost:3000
else
    echo "🔄 Setting up port forwarding..."
    
    # Port forward frontend
    if check_port 8080; then
        echo "📡 Starting frontend port forward on port 8080..."
        kubectl port-forward service/todo-frontend-service 8080:3000 -n todo-app &
        FRONTEND_PID=$!
        sleep 3
        
        if curl -s http://localhost:8080 &>/dev/null; then
            echo "✅ Frontend accessible at: http://localhost:8080"
            open http://localhost:8080
        else
            echo "❌ Frontend port forward failed"
        fi
    else
        echo "❌ Port 8080 is busy, trying 9000..."
        kubectl port-forward service/todo-frontend-service 9000:3000 -n todo-app &
        FRONTEND_PID=$!
        echo "✅ Frontend accessible at: http://localhost:9000"
        open http://localhost:9000
    fi
    
    # Port forward backend
    if check_port 8081; then
        echo "📡 Starting backend port forward on port 8081..."
        kubectl port-forward service/todo-backend-service 8081:3001 -n todo-app &
        BACKEND_PID=$!
        echo "✅ Backend accessible at: http://localhost:8081"
    fi
fi

echo ""
echo "📊 Application Info:"
kubectl get services -n todo-app

echo ""
echo "🛑 To stop port forwards:"
echo "   sudo pkill -f 'port-forward'"
echo ""
echo "📋 Useful commands:"
echo "   App status:  kubectl get pods -n todo-app"
echo "   View logs:   kubectl logs -l app=todo-frontend -n todo-app"
echo "   Scale app:   kubectl scale deployment todo-frontend --replicas=2 -n todo-app"./quick-access.sh