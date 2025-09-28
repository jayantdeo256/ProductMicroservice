#!/bin/bash

echo "🔧 FIXING DUPLICATE CONTAINERS..."

echo "Stopping duplicate container on port 5001..."
docker stop wonderful_dubinsky 2>/dev/null && echo "✅ Stopped wonderful_dubinsky" || echo "❌ Container not found"

echo "Removing duplicate container..."
docker rm wonderful_dubinsky 2>/dev/null && echo "✅ Removed wonderful_dubinsky" || echo "❌ Container not found"

echo "Restarting docker-compose stack..."
docker-compose restart

sleep 5

echo "✅ Fixed! Now only running on port 5000"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🧪 Testing application..."
curl -s http://localhost:5000/health && echo "✅ App is healthy" || echo "❌ App health check failed"