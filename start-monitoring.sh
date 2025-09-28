#!/bin/bash

echo "🚀 STARTING MONITORING STACK..."

# Check if monitoring containers are already running
if docker ps | grep -q "prometheus\|grafana\|alertmanager"; then
    echo "📊 Monitoring stack already running"
    docker ps | grep -E "prometheus|grafana|alertmanager"
else
    echo "🔧 Starting monitoring stack..."
    
    # Create monitoring directory if it doesn't exist
    mkdir -p monitoring
    
    # Create Prometheus configuration
    cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'product-service'
    static_configs:
      - targets: ['host.docker.internal:5000']
    metrics_path: /metrics
    scrape_interval: 10s

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

    # Start monitoring services
    docker run -d --name prometheus -p 9090:9090 \
        -v $(pwd)/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml \
        prom/prometheus:latest

    docker run -d --name grafana -p 3000:3000 \
        -e GF_SECURITY_ADMIN_USER=admin \
        -e GF_SECURITY_ADMIN_PASSWORD=admin123 \
        grafana/grafana:latest

    docker run -d --name alertmanager -p 9093:9093 \
        prom/alertmanager:latest

    echo "⏳ Waiting for monitoring stack to start..."
    sleep 15
fi

echo "✅ Monitoring stack started!"
echo ""
echo "🌐 URLs:"
echo "   - Prometheus: http://localhost:9090"
echo "   - Grafana: http://localhost:3000"
echo "   - Alertmanager: http://localhost:9093"