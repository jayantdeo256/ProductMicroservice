#!/bin/bash

echo "🔍 CHECKING CURRENT STATUS..."

echo "🐳 DOCKER CONTAINERS:"
docker ps

echo ""
echo "🧪 TESTING ENDPOINTS:"

# Test the main application (port 5000 from docker-compose)
echo "1. Testing docker-compose app (port 5000):"
curl -s http://localhost:5000/health && echo "✅ HEALTHY" || echo "❌ UNHEALTHY"

echo "2. Testing direct container (port 5001):"
curl -s http://localhost:5001/health && echo "✅ HEALTHY" || echo "❌ UNHEALTHY"

echo ""
echo "📊 CHECKING LOGS:"
docker logs productmicroservice_product-service_1 --tail 5

echo ""
echo "🔗 NETWORKING:"
docker network ls
docker inspect productmicroservice_default | grep -A 10 "Containers"