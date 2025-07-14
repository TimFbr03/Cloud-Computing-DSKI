#!/bin/bash

# K3s Port Forward Script for Todo App

echo "🔗 Setting up port forwarding for Todo App..."

# Set kubectl command (k3s specific or regular kubectl)
if command -v kubectl &> /dev/null; then
    KUBECTL="kubectl"
elif command -v k3s &> /dev/null; then
    KUBECTL="sudo k3s kubectl"
else
    echo "❌ Neither kubectl nor k3s command found."
    exit 1
fi

# Check if the app is running
if ! $KUBECTL get namespace todo-app &> /dev/null; then
    echo "❌ Todo app is not deployed. Run ./deploy-k3s.sh first."
    exit 1
fi

# Function to check if port is in use
check_port() {
    if lsof -i:$1 > /dev/null 2>&1; then
        echo "⚠️  Port $1 is already in use"
        return 1
    fi
    return 0
}

# Kill existing port forwards
echo "🧹 Stopping existing port forwards..."
pkill -f "port-forward.*todo-" 2>/dev/null || true
sleep 2

# Start port forwarding for frontend
echo "🌐 Starting frontend port forward (3000)..."
if check_port 3000; then
    $KUBECTL port-forward service/todo-frontend-service 3000:3000 -n todo-app &
    FRONTEND_PID=$!
    echo "✅ Frontend accessible at: http://localhost:3000"
else
    echo "❌ Cannot start frontend port forward - port 3000 is busy"
    exit 1
fi

# Start port forwarding for backend (optional)
echo "🔧 Starting backend port forward (3001)..."
if check_port 3001; then
    $KUBECTL port-forward service/todo-backend-service 3001:3001 -n todo-app &
    BACKEND_PID=$!
    echo "✅ Backend API accessible at: http://localhost:3001"
else
    echo "⚠️  Backend port forward skipped - port 3001 is busy"
fi

# Start port forwarding for database (optional)
echo "🗄️  Starting database port forward (5432)..."
if check_port 5432; then
    $KUBECTL port-forward service/todo-database-service 5432:5432 -n todo-app &
    DATABASE_PID=$!
    echo "✅ Database accessible at: localhost:5432"
else
    echo "⚠️  Database port forward skipped - port 5432 is busy"
fi

echo ""
echo "🎉 Port forwarding active!"
echo ""
echo "📋 Active connections:"
echo "   Frontend:  http://localhost:3000"
[[ ! -z "$BACKEND_PID" ]] && echo "   Backend:   http://localhost:3001"
[[ ! -z "$DATABASE_PID" ]] && echo "   Database:  localhost:5432"
echo ""
echo "🛑 To stop port forwarding:"
echo "   Press Ctrl+C or run: pkill -f 'port-forward.*todo-'"
echo ""
echo "📊 Monitor with:"
echo "   $KUBECTL get pods -n todo-app -w"

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Stopping port forwards..."
    [[ ! -z "$FRONTEND_PID" ]] && kill $FRONTEND_PID 2>/dev/null
    [[ ! -z "$BACKEND_PID" ]] && kill $BACKEND_PID 2>/dev/null  
    [[ ! -z "$DATABASE_PID" ]] && kill $DATABASE_PID 2>/dev/null
    exit 0
}

# Trap signals to cleanup
trap cleanup SIGINT SIGTERM

# Keep script running
echo "⏳ Keeping port forwards active... (Press Ctrl+C to stop)"
wait