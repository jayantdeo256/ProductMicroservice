#!/bin/bash

echo "📊 SETTING UP GRAFANA DASHBOARD..."

# Wait for Grafana to be ready
until curl -s http://localhost:3000/api/health > /dev/null; do
    echo "⏳ Waiting for Grafana to be ready..."
    sleep 5
done

# Add Prometheus datasource
curl -s -X POST "http://admin:admin123@localhost:3000/api/datasources" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://host.docker.internal:9090",
        "access": "proxy",
        "isDefault": true
    }' && echo "✅ Prometheus datasource added"

# Create a simple dashboard
DASHBOARD_JSON='{
  "dashboard": {
    "id": null,
    "title": "Product Service Monitoring",
    "tags": ["microservice", "product"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Service Health",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"product-service\"}",
            "legendFormat": "Status",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "HTTP Requests",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "Requests",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      }
    ],
    "time": {"from": "now-6h", "to": "now"}
  },
  "folderId": 0,
  "overwrite": false
}'

# Import dashboard
curl -s -X POST "http://admin:admin123@localhost:3000/api/dashboards/db" \
    -H "Content-Type: application/json" \
    -d "$DASHBOARD_JSON" && echo "✅ Dashboard created"

echo ""
echo "🎉 Grafana setup complete!"
echo "🌐 Open http://localhost:3000 and login with admin/admin123"
echo "📊 Dashboard should be available"