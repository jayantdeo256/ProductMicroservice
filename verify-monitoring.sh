#!/bin/bash

echo "🔍 COMPLETE MONITORING STACK VERIFICATION"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

echo ""
echo "📊 STEP 1: CHECKING APPLICATION METRICS..."
echo "==========================================="

# Test if application is exposing metrics
echo "1. Testing metrics endpoint..."
curl -s http://localhost:5000/metrics > /dev/null
print_status $? "Metrics endpoint accessible"

# Check if Prometheus metrics are present
echo "2. Checking for Prometheus metrics..."
METRICS_COUNT=$(curl -s http://localhost:5000/metrics | grep -c "^[^#]" | head -20)
if [ $METRICS_COUNT -gt 5 ]; then
    echo -e "${GREEN}✅ Found $METRICS_COUNT metrics${NC}"
else
    echo -e "${RED}❌ Only $METRICS_COUNT metrics found${NC}"
fi

# Check specific metrics
echo "3. Checking specific metrics..."
curl -s http://localhost:5000/metrics | grep -E "(http_requests_total|products_created_total|request_duration_seconds)" | head -5

echo ""
echo "📈 STEP 2: CHECKING PROMETHEUS..."
echo "=================================="

# Check if Prometheus is running
echo "1. Checking Prometheus status..."
curl -s http://localhost:9090/-/healthy > /dev/null
print_status $? "Prometheus health check"

# Check Prometheus targets
echo "2. Checking Prometheus targets..."
TARGETS=$(curl -s http://localhost:9090/api/v1/targets)
if echo "$TARGETS" | grep -q "product-service"; then
    echo -e "${GREEN}✅ Product service target found${NC}"
    
    # Check target health
    TARGET_HEALTH=$(echo "$TARGETS" | grep -A 10 "product-service" | grep '"health":"up"' || echo "down")
    if [ "$TARGET_HEALTH" = "down" ]; then
        echo -e "${RED}❌ Product service target is DOWN${NC}"
    else
        echo -e "${GREEN}✅ Product service target is UP${NC}"
    fi
else
    echo -e "${RED}❌ Product service target not found${NC}"
fi

# Check if metrics are being scraped
echo "3. Checking scraped metrics in Prometheus..."
curl -s "http://localhost:9090/api/v1/query?query=up" | grep -q "product-service" && \
echo -e "${GREEN}✅ Metrics are being scraped${NC}" || echo -e "${RED}❌ No metrics found in Prometheus${NC}"

echo ""
echo "📊 STEP 3: CHECKING GRAFANA..."
echo "================================"

# Check if Grafana is running
echo "1. Checking Grafana status..."
curl -s http://localhost:3000 > /dev/null
print_status $? "Grafana accessible"

# Try to check Grafana health (API requires auth)
echo "2. Testing Grafana API..."
GRAFANA_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "http://admin:admin123@localhost:3000/api/health")
if [ "$GRAFANA_HEALTH" = "200" ]; then
    echo -e "${GREEN}✅ Grafana API healthy${NC}"
else
    echo -e "${YELLOW}⚠️  Grafana API returned HTTP $GRAFANA_HEALTH (might need login)${NC}"
fi

echo ""
echo "🚨 STEP 4: CHECKING ALERTMANAGER..."
echo "===================================="

# Check if Alertmanager is running
echo "1. Checking Alertmanager status..."
curl -s http://localhost:9093/-/healthy > /dev/null
print_status $? "Alertmanager health check"

# Check Alertmanager configuration
echo "2. Checking Alertmanager config..."
ALERTMANAGER_CONFIG=$(curl -s http://localhost:9093/api/v1/status)
if echo "$ALERTMANAGER_CONFIG" | grep -q "config"; then
    echo -e "${GREEN}✅ Alertmanager configured${NC}"
else
    echo -e "${YELLOW}⚠️  Alertmanager configuration not checked (API might be different)${NC}"
fi

echo ""
echo "🔔 STEP 5: TESTING ALERTING PIPELINE..."
echo "========================================"

# Generate some traffic to trigger metrics
echo "1. Generating test traffic..."
for i in {1..5}; do
    curl -s http://localhost:5000/api/products > /dev/null
    curl -s http://localhost:5000/health > /dev/null
    sleep 1
done
echo -e "${GREEN}✅ Test traffic generated${NC}"

# Check if alerts would fire (simulate by checking metrics)
echo "2. Checking alert conditions..."
# Query for high error rate (should be 0 in healthy state)
ERROR_RATE=$(curl -s "http://localhost:9090/api/v1/query?query=rate(http_requests_total{code=~'5..'}[5m])" | grep -c "value")
if [ "$ERROR_RATE" -eq 0 ]; then
    echo -e "${GREEN}✅ No error rate alerts (system healthy)${NC}"
else
    echo -e "${YELLOW}⚠️  Error rate detected: $ERROR_RATE${NC}"
fi

echo ""
echo "💬 STEP 6: CHECKING SLACK INTEGRATION..."
echo "========================================="

# Check if Slack webhook is configured
echo "1. Checking Slack configuration..."
if [ -f "monitoring/.env" ]; then
    if grep -q "SLACK_WEBHOOK_URL" monitoring/.env; then
        echo -e "${GREEN}✅ Slack webhook configured in .env${NC}"
        WEBHOOK_URL=$(grep "SLACK_WEBHOOK_URL" monitoring/.env | cut -d '=' -f2)
        if [[ $WEBHOOK_URL == *"hooks.slack.com"* ]]; then
            echo -e "${GREEN}✅ Valid Slack webhook URL format${NC}"
        else
            echo -e "${YELLOW}⚠️  Slack webhook URL format may be invalid${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No Slack webhook found in .env${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No .env file found${NC}"
fi

# Test Slack webhook (if configured)
echo "2. Testing Slack webhook..."
if [ ! -z "$WEBHOOK_URL" ] && [[ $WEBHOOK_URL == *"hooks.slack.com"* ]]; then
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H 'Content-type: application/json' \
        --data '{"text":"🧪 Test alert from monitoring verification script"}' "$WEBHOOK_URL")
    
    if [ "$RESPONSE" = "200" ]; then
        echo -e "${GREEN}✅ Slack webhook test successful!${NC}"
    else
        echo -e "${RED}❌ Slack webhook test failed (HTTP $RESPONSE)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Slack webhook not configured for testing${NC}"
fi

echo ""
echo "🎯 STEP 7: CREATING TEST ALERTS..."
echo "==================================="

# Create a test alert file for Prometheus
echo "1. Creating test alert rules..."
cat > monitoring/test-alerts.yml << 'EOF'
groups:
- name: test_alerts
  rules:
  - alert: TestAlertVerified
    expr: 1
    for: 1s
    labels:
      severity: test
      service: product-service
    annotations:
      summary: "Monitoring verification test alert"
      description: "This is a test alert to verify the monitoring stack is working"
EOF

# Reload Prometheus configuration
echo "2. Reloading Prometheus configuration..."
curl -s -X POST http://localhost:9090/-/reload
echo -e "${GREEN}✅ Prometheus configuration reloaded${NC}"

# Wait for alert to fire
echo "3. Waiting for test alert..."
sleep 10

# Check if alert is firing
echo "4. Checking for test alerts..."
ALERTS=$(curl -s "http://localhost:9090/api/v1/alerts")
if echo "$ALERTS" | grep -q "TestAlertVerified"; then
    echo -e "${GREEN}✅ Test alert is FIRING${NC}"
else
    echo -e "${YELLOW}⚠️  Test alert not found (check Prometheus rules)${NC}"
fi

echo ""
echo "📋 STEP 8: FINAL VERIFICATION REPORT..."
echo "========================================"

# Summary check
echo "1. Application Metrics:"
curl -s http://localhost:5000/metrics > /dev/null && \
echo -e "   ${GREEN}✅ Exposing metrics${NC}" || echo -e "   ${RED}❌ Metrics endpoint down${NC}"

echo "2. Prometheus:"
curl -s http://localhost:9090/-/healthy > /dev/null && \
echo -e "   ${GREEN}✅ Running and healthy${NC}" || echo -e "   ${RED}❌ Prometheus down${NC}"

echo "3. Grafana:"
curl -s http://localhost:3000 > /dev/null && \
echo -e "   ${GREEN}✅ Accessible${NC}" || echo -e "   ${RED}❌ Grafana down${NC}"

echo "4. Alertmanager:"
curl -s http://localhost:9093/-/healthy > /dev/null && \
echo -e "   ${GREEN}✅ Running and healthy${NC}" || echo -e "   ${RED}❌ Alertmanager down${NC}"

echo "5. Slack Integration:"
if [ ! -z "$WEBHOOK_URL" ] && [[ $WEBHOOK_URL == *"hooks.slack.com"* ]]; then
    echo -e "   ${GREEN}✅ Webhook configured${NC}"
else
    echo -e "   ${YELLOW}⚠️  Not configured${NC}"
fi

echo ""
echo "🎉 VERIFICATION COMPLETE!"
echo "=========================="
echo ""
echo "🌐 ACCESS URLs:"
echo "   - Application:    http://localhost:5000"
echo "   - Swagger:        http://localhost:5000/swagger"
echo "   - Prometheus:     http://localhost:9090"
echo "   - Grafana:        http://localhost:3000 (admin/admin123)"
echo "   - Alertmanager:   http://localhost:9093"
echo ""
echo "📊 NEXT STEPS:"
echo "   1. Open Grafana and add Prometheus datasource: http://localhost:3000"
echo "   2. Import dashboard or create one"
echo "   3. Test real alerts by stopping the application"
echo "   4. Verify Slack notifications (if configured)"