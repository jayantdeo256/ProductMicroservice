#!/bin/bash

echo "🎯 COMPLETE AKS DEPLOYMENT SCRIPT"

# Phase 1: Prerequisites
echo "=== PHASE 1: PREREQUISITES ==="
./setup-prerequisites.sh

# Phase 2: AKS Infrastructure
echo "=== PHASE 2: AKS INFRASTRUCTURE ==="
./deploy-aks.sh

# Phase 3: Containerization
echo "=== PHASE 3: CONTAINERIZATION ==="
./build-and-push-acr.sh

# Phase 4: Argo CD
echo "=== PHASE 4: GITOPS WITH ARGO CD ==="
./argocd/install-argocd.sh

# Phase 5: Deploy Application
echo "=== PHASE 5: DEPLOY APPLICATION ==="
kubectl apply -f argocd/applications/product-service.yaml

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo ""
echo "🌐 ACCESS POINTS:"
echo "   - Argo CD UI: https://localhost:8080"
echo "   - Application: (Get external IP with: kubectl get svc -n product-microservice)"
echo ""
echo "📊 MONITORING:"
echo "   - Check Argo CD sync status"
echo "   - Monitor pods: kubectl get pods -n product-microservice"
echo "   - Check services: kubectl get svc -n product-microservice"