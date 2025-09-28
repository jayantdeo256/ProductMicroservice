#!/bin/bash

echo "🐳 BUILDING AND PUSHING CONTAINERS TO ACR..."

# Get ACR name from Terraform
cd terraform
ACR_NAME=$(terraform output -raw acr_login_server)
cd ..

echo "ACR Login Server: $ACR_NAME"

# Login to ACR
echo "1. Logging into ACR..."
az acr login --name $(echo $ACR_NAME | cut -d'.' -f1)

# Build application image
echo "2. Building application image..."
docker build -t $ACR_NAME/product-service:latest -f Dockerfile.prod .

# Build PostgreSQL image (if needed, or use official)
docker pull postgres:15-alpine
docker tag postgres:15-alpine $ACR_NAME/postgres:15-alpine

# Push images to ACR
echo "3. Pushing images to ACR..."
docker push $ACR_NAME/product-service:latest
docker push $ACR_NAME/postgres:15-alpine

echo "✅ IMAGES PUSHED TO ACR:"
echo "   - $ACR_NAME/product-service:latest"
echo "   - $ACR_NAME/postgres:15-alpine"