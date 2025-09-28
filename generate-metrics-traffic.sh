#!/bin/bash

echo "🚀 GENERATING REAL METRICS TRAFFIC"

# Function to make API calls
make_request() {
    local endpoint=$1
    local method=$2
    local data=$3
    
    echo "Making $method request to $endpoint"
    if [ "$method" = "POST" ]; then
        curl -X POST "http://localhost:5000$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data" \
            -w " -> Status: %{http_code}\n" \
            -s
    else
        curl -X GET "http://localhost:5000$endpoint" \
            -w " -> Status: %{http_code}\n" \
            -s
    fi
}

echo ""
echo "1. GENERATING API TRAFFIC..."
echo "============================"

# Generate various types of requests
make_request "/api/products" "GET"
make_request "/health" "GET" 
make_request "/health-details" "GET"
make_request "/" "GET"

# Create some products
make_request "/api/products" "POST" '{"name": "Test Product 1", "description": "Metric generation test", "price": 19.99, "stock": 10}'
make_request "/api/products" "POST" '{"name": "Test Product 2", "description": "Another test product", "price": 29.99, "stock": 5}'

# Get products again
make_request "/api/products" "GET"

# Generate some errors (404)
make_request "/api/products/9999" "GET"  # Non-existent product
make_request "/api/nonexistent" "GET"    # Non-existent endpoint

echo ""
echo "2. CHECKING METRICS AFTER TRAFFIC..."
echo "===================================="

# Wait a moment for metrics to update
sleep 2

# Check specific metrics
echo "HTTP requests metric:"
curl -s http://localhost:5000/metrics | grep "http_requests_total" | grep -v "#"

echo ""
echo "Custom product metrics:"
curl -s http://localhost:5000/metrics | grep "products_" | grep -v "#"

echo ""
echo "3. QUERYING PROMETHEUS FOR LATEST METRICS..."
echo "============================================"

# Query Prometheus for the metrics we just generated
echo "HTTP requests in Prometheus:"
curl -s "http://localhost:9090/api/v1/query?query=http_requests_total" | jq '.data.result[] | {metric: .metric, value: .value}'

echo ""
echo "4. VERIFYING METRICS IN GRAFANA..."
echo "=================================="

echo "Open Grafana and check the dashboard: http://localhost:3000"
echo "Login: admin/admin123"
echo "Check if metrics are appearing in the dashboard"

echo ""
echo "✅ METRICS GENERATION COMPLETE!"