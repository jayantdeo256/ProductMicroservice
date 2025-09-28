#!/bin/bash

echo "🚀 DEPLOYING AKS CLUSTER WITH TERRAFORM..."

# Check if user is logged into Azure
echo "1. Checking Azure login..."
az account show > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Not logged into Azure. Please run: az login"
    exit 1
fi
echo "✅ Logged into Azure"

# Get Azure subscription info
echo "2. Getting subscription information..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "   Subscription: $SUBSCRIPTION_ID"
echo "   Tenant: $TENANT_ID"

# Create service principal for Terraform
echo "3. Creating service principal for Terraform..."
SP_NAME="product-microservice-tf"
SP_JSON=$(az ad sp create-for-rbac --name $SP_NAME --role Contributor --scopes /subscriptions/$SUBSCRIPTION_ID --sdk-auth)
if [ $? -ne 0 ]; then
    echo "❌ Failed to create service principal"
    exit 1
fi

# Extract credentials from service principal
CLIENT_ID=$(echo $SP_JSON | jq -r .clientId)
CLIENT_SECRET=$(echo $SP_JSON | jq -r .clientSecret)

echo "✅ Service principal created: $CLIENT_ID"

# Initialize Terraform
echo "4. Initializing Terraform..."
cd terraform
terraform init

# Create Terraform variables file
cat > terraform.tfvars << EOF
client_id     = "$CLIENT_ID"
client_secret = "$CLIENT_SECRET"
tenant_id     = "$TENANT_ID"
subscription_id = "$SUBSCRIPTION_ID"
EOF

# Plan the deployment
echo "5. Planning Terraform deployment..."
terraform plan -out=plan.out

# Apply the deployment
echo "6. Applying Terraform configuration..."
terraform apply -auto-approve plan.out

# Get outputs
echo "7. Getting cluster credentials..."
az aks get-credentials --resource-group $(terraform output -raw resource_group_name) --name $(terraform output -raw aks_cluster_name) --overwrite-existing

# Verify cluster access
echo "8. Verifying cluster access..."
kubectl cluster-info
kubectl get nodes

echo ""
echo "🎉 AKS CLUSTER DEPLOYED SUCCESSFULLY!"
echo ""
echo "📊 CLUSTER INFORMATION:"
echo "   - Resource Group: $(terraform output -raw resource_group_name)"
echo "   - AKS Cluster: $(terraform output -raw aks_cluster_name)"
echo "   - ACR: $(terraform output -raw acr_login_server)"
echo "   - Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo ""
echo "🔧 NEXT STEPS:"
echo "   1. Push container images to ACR"
echo "   2. Install Argo CD"
echo "   3. Deploy applications"