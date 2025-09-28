#!/bin/bash

echo "🐳 CONTAINER MANAGEMENT SCRIPT"

case "$1" in
    "status")
        echo "📊 CURRENT STATUS:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "🌐 ENDPOINTS:"
        echo "   - Docker Compose App: http://localhost:5000"
        echo "   - Direct Container:   http://localhost:5001"
        ;;
        
    "stop-all")
        echo "🛑 STOPPING ALL CONTAINERS..."
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        echo "✅ All containers stopped and removed"
        ;;
        
    "clean")
        echo "🧹 CLEANING EVERYTHING..."
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        docker system prune -a -f --volumes
        echo "✅ Complete cleanup done"
        ;;
        
    "start")
        echo "🚀 STARTING DOCKER COMPOSE STACK..."
        docker-compose up -d
        sleep 10
        echo "✅ Docker compose stack started"
        curl -s http://localhost:5000/health && echo "✅ App is healthy" || echo "❌ App health check failed"
        ;;
        
    "restart")
        echo "🔄 RESTARTING SERVICES..."
        docker-compose restart
        sleep 10
        curl -s http://localhost:5000/health && echo "✅ App restarted successfully" || echo "❌ App restart failed"
        ;;
        
    "logs")
        echo "📋 VIEWING LOGS..."
        docker-compose logs -f ${2:-product-service}
        ;;
        
    "test")
        echo "🧪 TESTING ALL ENDPOINTS..."
        echo "1. Health check:"
        curl -s http://localhost:5000/health | jq . || curl -s http://localhost:5000/health
        
        echo ""
        echo "2. API endpoints:"
        curl -s http://localhost:5000/api/products | jq . || curl -s http://localhost:5000/api/products
        
        echo ""
        echo "3. Metrics:"
        curl -s http://localhost:5000/metrics | grep -c "http_requests_total" | xargs echo "Metrics count:"
        
        echo ""
        echo "4. Docker status:"
        docker-compose ps
        ;;
        
    "fix-duplicate")
        echo "🔧 FIXING DUPLICATE CONTAINERS..."
        echo "Stopping duplicate container on port 5001..."
        docker stop wonderful_dubinsky 2>/dev/null || true
        docker rm wonderful_dubinsky 2>/dev/null || true
        
        echo "Restarting docker-compose stack..."
        docker-compose restart
        sleep 5
        
        echo "✅ Fixed! Only running on port 5000 now"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
        
    "monitoring")
        echo "📊 STARTING MONITORING STACK..."
        # Create monitoring directory
        mkdir -p monitoring
        
        # Create Prometheus config
        cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'product-service'
    static_configs:
      - targets: ['host.docker.internal:5000']
    metrics_path: /metrics
    scrape_interval: 10s
EOF

        # Start monitoring
        docker run -d --name prometheus -p 9090:9090 \
            -v $(pwd)/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml \
            prom/prometheus:latest
            
        docker run -d --name grafana -p 3000:3000 \
            -e GF_SECURITY_ADMIN_USER=admin \
            -e GF_SECURITY_ADMIN_PASSWORD=admin123 \
            grafana/grafana:latest
            
        echo "✅ Monitoring stack started:"
        echo "   - Prometheus: http://localhost:9090"
        echo "   - Grafana:    http://localhost:3000 (admin/admin123)"
        ;;
        
    *)
        echo "🐳 CONTAINER MANAGEMENT SCRIPT"
        echo ""
        echo "Usage: $0 {status|stop-all|clean|start|restart|logs|test|fix-duplicate|monitoring}"
        echo ""
        echo "Commands:"
        echo "  status         - Show current container status"
        echo "  stop-all       - Stop all running containers"
        echo "  clean          - Complete cleanup (containers, images, volumes)"
        echo "  start          - Start docker-compose stack"
        echo "  restart        - Restart services"
        echo "  logs [service] - View logs (default: product-service)"
        echo "  test           - Test all endpoints"
        echo "  fix-duplicate  - Fix duplicate containers on port 5001"
        echo "  monitoring     - Start Prometheus + Grafana"
        echo ""
        echo "Current status:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers running"
        ;;
esac