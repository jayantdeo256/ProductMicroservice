#!/bin/bash

echo "🚨 TESTING ALERTING PIPELINE..."

# Create a test alert that will definitely fire
cat > monitoring/test-alert.yml << 'EOF'
groups:
- name: test_alerts
  rules:
  - alert: ServiceHealthTest
    expr: up{job="product-service"} == 1
    for: 1m
    labels:
      severity: warning
      service: product-service
    annotations:
      summary: "Service health test alert"
      description: "This is a test alert to verify the alerting pipeline is working"
EOF

# Update Prometheus configuration to include test alert
cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

rule_files:
  - "test-alert.yml"

scrape_configs:
  - job_name: 'product-service'
    static_configs:
      - targets: ['host.docker.internal:5000']
    metrics_path: /metrics
    scrape_interval: 10s
EOF

# Reload Prometheus
curl -s -X POST http://localhost:9090/-/reload
echo "✅ Test alert configured"

echo "⏳ Waiting for alert to fire..."
sleep 60

# Check if alert is firing
echo "🔍 Checking alert status..."
ALERTS=$(curl -s "http://localhost:9090/api/v1/alerts")
if echo "$ALERTS" | grep -q "ServiceHealthTest"; then
    echo "✅ Test alert is FIRING"
    echo "$ALERTS" | grep -A 5 -B 5 "ServiceHealthTest"
else
    echo "❌ Test alert not firing"
    echo "Available alerts:"
    echo "$ALERTS"
fi

echo ""
echo "💡 To test Slack notifications, ensure your webhook is configured in monitoring/.env"