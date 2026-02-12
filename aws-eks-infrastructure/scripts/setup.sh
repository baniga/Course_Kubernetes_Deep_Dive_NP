#!/bin/bash
set -e

echo "========================================"
echo "EKS Infrastructure Setup Script"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI not found. Please install AWS CLI.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI found${NC}"

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform not found. Please install Terraform >= 1.5.0${NC}"
    exit 1
fi
TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
echo -e "${GREEN}✓ Terraform found (version: $TERRAFORM_VERSION)${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}⚠ kubectl not found. Installing...${NC}"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    echo -e "${GREEN}✓ kubectl installed${NC}"
else
    echo -e "${GREEN}✓ kubectl found${NC}"
fi

# Check helm
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}⚠ helm not found. Installing...${NC}"
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm get_helm.sh
    echo -e "${GREEN}✓ helm installed${NC}"
else
    echo -e "${GREEN}✓ helm found${NC}"
fi

# Check AWS credentials
echo ""
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}AWS credentials not configured. Please configure AWS CLI.${NC}"
    echo "Run: aws configure"
    exit 1
fi
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
echo -e "${GREEN}✓ AWS credentials configured${NC}"
echo "  Account: $AWS_ACCOUNT"
echo "  User: $AWS_USER"

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform" || exit 1

# Check if terraform.tfvars exists
echo ""
if [ ! -f terraform.tfvars ]; then
    echo -e "${YELLOW}terraform.tfvars not found. Creating from example...${NC}"
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${GREEN}✓ terraform.tfvars created${NC}"
    echo -e "${YELLOW}⚠ Please edit terraform.tfvars with your configuration before proceeding!${NC}"
    echo ""
    read -p "Press enter to open terraform.tfvars in your default editor..." 
    ${EDITOR:-vi} terraform.tfvars
fi

# Terraform init
echo ""
echo "Initializing Terraform..."
terraform init

# Terraform validate
echo ""
echo "Validating Terraform configuration..."
terraform validate

# Terraform plan
echo ""
echo "Creating Terraform plan..."
terraform plan -out=tfplan

# Confirm deployment
echo ""
echo -e "${YELLOW}========================================"
echo "Ready to deploy EKS infrastructure"
echo "========================================${NC}"
echo ""
read -p "Do you want to proceed with deployment? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Terraform apply
echo ""
echo "Deploying infrastructure..."
terraform apply tfplan

# Get outputs
echo ""
echo -e "${GREEN}========================================"
echo "Deployment Complete!"
echo "========================================${NC}"
echo ""
terraform output

# Configure kubectl
echo ""
CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION=$(terraform output -raw region)
echo "Configuring kubectl..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

# Verify cluster access
echo ""
echo "Verifying cluster access..."
kubectl cluster-info
kubectl get nodes

echo ""
echo -e "${GREEN}========================================"
echo "Setup Complete!"
echo "========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Review the cluster: kubectl get all --all-namespaces"
echo "2. Deploy applications: kubectl apply -f your-app.yaml"
echo "3. Install AWS Load Balancer Controller (optional)"
echo "4. Install monitoring tools (Prometheus, Grafana)"
echo ""
echo "Useful commands:"
echo "  kubectl get nodes"
echo "  kubectl get pods --all-namespaces"
echo "  kubectl get svc --all-namespaces"
echo ""
