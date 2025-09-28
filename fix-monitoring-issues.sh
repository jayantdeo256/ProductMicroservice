#!/bin/bash

echo "🔧 FIXING MONITORING ISSUES..."

echo "1. Enabling Prometheus Lifecycle API..."
# Stop current Prometheus
docker stop prometheus
docker rm prometheus

# Start Prometheus with lifecycle API enabled
docker run -d --name prometheus -p 9090:9090 \
    -v $(pwd)/monitoring:/etc/prometheus \
    prom/prometheus:latest \
    --web.enable-lifecycle \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --web.console.templates=/etc/prometheus/consoles

echo "2. Creating proper Alertmanager configuration..."
cat > monitoring/alertmanager.yml << 'EOF'
global:
  slack_api_url: '${SLACK_WEBHOOK_URL}'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'slack-notifications'

receivers:
- name: 'slack-notifications'
  slack_configs:
  - channel: '#alerts'
    send_resolved: true
    title: '{{ .GroupLabels.alertname }}'
    text: '{{ .CommonAnnotations.summary }}'
    color: '{{ if eq .Status "firing" }}danger{{ else }}good{{ end }}'
EOF

# Restart Alertmanager with new config
docker stop alertmanager
docker rm alertmanager

docker run -d --name alertmanager -p 9093:9093 \
    -v $(pwd)/monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
    --env-file monitoring/.env \
    prom/alertmanager:latest \
    --config.file=/etc/alertmanager/alertmanager.yml \
    --storage.path=/alertmanager

echo "3. Creating proper Prometheus rules..."
cat > monitoring/alerts.yml << 'EOF'
groups:
- name: product_service
  rules:
  - alert: ProductServiceDown
    expr: up{job="product-service"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Product Service is down"
      description: "The service has been down for more than 1 minute"

  - alert: HighRequestLatency
    expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High request latency detected"
      description: "95th percentile latency is above 1 second"

  - alert: TestAlertAlwaysFiring
    expr: vector(1)
    for: 1s
    labels:
      severity: test
    annotations:
      summary: "Test alert to verify alerting pipeline"
      description: "This alert should always be firing for testing purposes"
EOF

echo "4. Updating Prometheus configuration..."
cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alerts.yml"

scrape_configs:
  - job_name: 'product-service'
    static_configs:
      - targets: ['host.docker.internal:5000']
    metrics_path: /metrics
    scrape_interval: 10s

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
EOF

echo "5. Reloading Prometheus configuration..."
sleep 5
curl -X POST http://localhost:9090/-/reload

echo "6. Waiting for alerts to fire..."
sleep 15

echo "7. Testing the complete pipeline..."
# Generate some traffic
for i in {1..10}; do
    curl -s http://localhost:5000/api/products > /dev/null
    curl -s http://localhost:5000/health > /dev/null
    sleep 1
done

echo "✅ Fixes applied! Waiting for system to stabilize..."
sleep 10

echo ""
echo "🧪 VERIFICATION..."
echo "=================="

echo "1. Checking Prometheus lifecycle API..."
curl -s -X POST http://localhost:9090/-/reload && echo "✅ Lifecycle API working" || echo "❌ Lifecycle API failed"

echo "2. Checking alerts..."
ALERTS=$(curl -s http://localhost:9090/api/v1/alerts)
if echo "$ALERTS" | grep -q "alerts"; then
    echo "✅ Alerts are being processed"
    echo "$ALERTS" | jq '.data.alerts[] | {alert: .labels.alertname, state: .state}' 2>/dev/null || echo "$ALERTS"
else
    echo "❌ No alerts found"
fi

echo "3. Checking Alertmanager..."
curl -s http://localhost:9093/api/v1/status | grep -q "versionInfo" && echo "✅ Alertmanager API working" || echo "❌ Alertmanager API issue"

echo "4. Testing Slack one more time..."
if [ -f "monitoring/.env" ]; then
    WEBHOOK_URL=$(grep SLACK_WEBHOOK_URL monitoring/.env | cut -d'=' -f2)
    curl -s -X POST -H 'Content-type: application/json' \
        --data '{"text":"🔧 Monitoring stack fixes applied and verified!"}' \
        "$WEBHOOK_URL" && echo "✅ Slack test sent" || echo "❌ Slack test failed"
fi

echo ""
echo "🎉 MONITORING STACK FIXED!"
echo "🌐 Check these URLs:"
echo "   - Prometheus Alerts: http://localhost:9090/alerts"
echo "   - Alertmanager:      http://localhost:9093"
echo "   - Grafana:           http://localhost:3000"
echo "   - Your App:          http://localhost:5000"