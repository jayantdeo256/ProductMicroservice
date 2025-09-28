#!/bin/bash

echo "🚀 INSTALLING ARGO CD..."

# Create argocd namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD to be ready
echo "⏳ Waiting for Argo CD to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# Get Argo CD admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Port forward to access Argo CD UI
echo "🔗 Argo CD is being exposed via port-forward..."
echo "🌐 Argo CD UI: https://localhost:8080"
echo "🔑 Username: admin"
echo "🔑 Password: $ARGOCD_PASSWORD"

# Create port-forward in background
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

echo ""
echo "🎉 ARGO CD INSTALLED SUCCESSFULLY!"
echo "💡 Access the UI and change the default password"