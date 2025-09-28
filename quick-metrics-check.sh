#!/bin/bash

echo "📊 QUICK METRICS STATUS CHECK"

echo ""
echo "1. Application Metrics Endpoint:"
echo "--------------------------------"
curl -s http://localhost:5000/metrics | grep -E "^(http_requests_total|products_|aspnetcore_requests_total)" | head -5

echo ""
echo "2. Prometheus Scraping Status:"
echo "------------------------------"
TARGET_STATUS=$(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job=="product-service") | .health')
echo "Target health: $TARGET_STATUS"

echo ""
echo "3. Sample Metrics in Prometheus:"
echo "--------------------------------"
curl -s "http://localhost:9090/api/v1/query?query=up{job='product-service'}" | jq '.data.result[0].value'

echo ""
echo "4. Recent HTTP Requests Metric:"
echo "--------------------------------"
curl -s "http://localhost:9090/api/v1/query?query=http_requests_total" | jq '.data.result[0].value' 2>/dev/null && echo "✅ Metrics found" || echo "❌ No metrics"

echo ""
echo "🎯 QUICK CHECK COMPLETE!"