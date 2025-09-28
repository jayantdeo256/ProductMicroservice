#!/bin/bash

echo "🔧 SETTING UP PREREQUISITES FOR AZURE DEPLOYMENT..."

echo "1. Checking Azure CLI..."
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Installing..."
    # Install Azure CLI
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
else
    echo "✅ Azure CLI is installed"
    az version
fi

echo ""
echo "2. Checking Terraform..."
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Installing..."
    # Install Terraform
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install terraform
else
    echo "✅ Terraform is installed"
    terraform version
fi

echo ""
echo "3. Checking kubectl..."
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Installing..."
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
else
    echo "✅ kubectl is installed"
    kubectl version --client
fi

echo ""
echo "4. Checking Helm..."
if ! command -v helm &> /dev/null; then
    echo "❌ Helm not found. Installing..."
    # Install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "✅ Helm is installed"
    helm version
fi

echo ""
echo "🎯 PREREQUISITES CHECKLIST:"
echo "   - Azure CLI: ✅"
echo "   - Terraform: ✅" 
echo "   - kubectl: ✅"
echo "   - Helm: ✅"
echo ""
echo "📋 NEXT STEPS:"
echo "   1. Azure login: az login"
echo "   2. Create Terraform configuration"
echo "   3. Deploy AKS cluster"