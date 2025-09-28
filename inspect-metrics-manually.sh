#!/bin/bash

echo "🔍 MANUAL METRICS INSPECTION"

echo ""
echo "1. DIRECT METRICS ENDPOINT:"
echo "============================"
curl -s http://localhost:5000/metrics

echo ""
echo "2. PROMETHEUS TARGET STATUS:"
echo "============================"
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job == "product-service")'

echo ""
echo "3. AVAILABLE METRICS IN PROMETHEUS:"
echo "==================================="
curl -s "http://localhost:9090/api/v1/label/__name__/values" | jq '.data[]' | grep -i "http\|process\|aspnetcore" | head -20

echo ""
echo "4. QUERY SPECIFIC METRICS:"
echo "==========================="

# Check various metrics
for metric in "up" "http_requests_total" "process_cpu_seconds_total" "aspnetcore_requests_total"; do
    echo "Metric: $metric"
    curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq '.data.result[] | .metric, .value' 2>/dev/null || echo "  No data"
    echo "---"
done