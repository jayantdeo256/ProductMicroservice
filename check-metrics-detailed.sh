#!/bin/bash

echo "📊 DETAILED METRICS VERIFICATION"

echo ""
echo "1. CHECKING APPLICATION METRICS ENDPOINT..."
echo "============================================"

# Test the raw metrics endpoint
echo "Raw metrics output (first 50 lines):"
curl -s http://localhost:5000/metrics | head -50

echo ""
echo "2. CHECKING METRICS COUNT PROPERLY..."
echo "====================================="

# Count all metrics (including HELP and TYPE lines)
TOTAL_LINES=$(curl -s http://localhost:5000/metrics | wc -l)
echo "Total lines in metrics endpoint: $TOTAL_LINES"

# Count actual metric lines (non-comment, non-empty)
METRIC_LINES=$(curl -s http://localhost:5000/metrics | grep -E "^(http_|process_|aspnetcore_|products_)" | wc -l)
echo "Actual metric lines: $METRIC_LINES"

# Check for specific metric types
echo ""
echo "3. CHECKING SPECIFIC METRIC TYPES..."
echo "===================================="

# ASP.NET Core metrics
echo "ASP.NET Core metrics:"
curl -s http://localhost:5000/metrics | grep "aspnetcore_" | head -10

# HTTP metrics
echo ""
echo "HTTP metrics:"
curl -s http://localhost:5000/metrics | grep "http_" | head -10

# Process metrics
echo ""
echo "Process metrics:"
curl -s http://localhost:5000/metrics | grep "process_" | head -10

# Custom application metrics
echo ""
echo "Custom application metrics:"
curl -s http://localhost:5000/metrics | grep "products_" | head -10

echo ""
echo "4. GENERATING TRAFFIC TO CREATE METRICS..."
echo "=========================================="

# Generate some API traffic
echo "Generating API requests..."
for i in {1..10}; do
    echo "Request $i:"
    curl -s -o /dev/null -w "  HTTP Status: %{http_code}\n" http://localhost:5000/api/products
    curl -s -o /dev/null -w "  Health: %{http_code}\n" http://localhost:5000/health
    sleep 1
done

echo ""
echo "5. CHECKING METRICS AFTER TRAFFIC..."
echo "===================================="

# Check if custom metrics are being updated
echo "Custom metrics after traffic:"
curl -s http://localhost:5000/metrics | grep -E "(products_|http_requests_total)" | grep -v "#"

echo ""
echo "6. CHECKING PROMETHEUS FOR METRICS..."
echo "====================================="

# Query Prometheus for specific metrics
echo "Querying Prometheus for application metrics:"

# Check if metrics are in Prometheus
PROM_METRICS=$(curl -s "http://localhost:9090/api/v1/label/__name__/values" | grep -o '"values":\[.*\]' | sed 's/"values":\[//' | sed 's/\]//' | tr ',' '\n' | grep -E "(http_|process_|aspnetcore_|products_)" | head -10)

if [ -n "$PROM_METRICS" ]; then
    echo "Metrics found in Prometheus:"
    echo "$PROM_METRICS"
else
    echo "No application metrics found in Prometheus"
fi

# Query a specific metric
echo ""
echo "Querying http_requests_total:"
curl -s "http://localhost:9090/api/v1/query?query=http_requests_total" | jq . | head -20

echo ""
echo "7. REAL-TIME METRICS MONITORING..."
echo "=================================="

# Watch metrics for changes
echo "Watching metrics endpoint for 10 seconds (check for changes):"
timeout 10s bash -c 'while true; do
    curl -s http://localhost:5000/metrics | grep "http_requests_total" | head -2
    sleep 2
done'

echo ""
echo "8. GRAFANA DATA SOURCE VERIFICATION..."
echo "======================================"

# Check if Grafana can query the metrics
echo "Checking Grafana data source..."
GRAFANA_QUERY=$(curl -s -u admin:admin123 -X POST "http://localhost:3000/api/ds/query" \
    -H "Content-Type: application/json" \
    -d '{
        "queries": [
            {
                "refId": "A",
                "datasource": {
                    "type": "prometheus",
                    "uid": "eezdi4lrunapsa"
                },
                "expr": "http_requests_total",
                "format": "table",
                "intervalMs": 1000,
                "maxDataPoints": 10
            }
        ],
        "from": "now-5m",
        "to": "now"
    }' 2>/dev/null)

if echo "$GRAFANA_QUERY" | grep -q "results"; then
    echo "✅ Grafana can query Prometheus metrics"
else
    echo "❌ Grafana cannot query metrics"
fi

echo ""
echo "🎯 METRICS VERIFICATION COMPLETE!"