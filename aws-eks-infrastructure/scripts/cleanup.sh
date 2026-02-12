#!/bin/bash
set -e

echo "========================================"
echo "EKS Infrastructure Cleanup Script"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

cd "$(dirname "$0")/../terraform" || exit 1

# Warning
echo -e "${RED}========================================"
echo "WARNING: DESTRUCTIVE ACTION"
echo "========================================${NC}"
echo ""
echo "This will destroy ALL resources created by Terraform:"
echo "  - EKS Cluster"
echo "  - Worker Nodes"
echo "  - VPC and Subnets"
echo "  - Security Groups"
echo "  - NAT Gateways"
echo "  - Load Balancers"
echo "  - All associated resources"
echo ""
echo -e "${YELLOW}This action cannot be undone!${NC}"
echo ""

# Confirm destruction
read -p "Are you sure you want to destroy all resources? Type 'yes' to confirm: " -r
echo
if [[ ! $REPLY == "yes" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Second confirmation
read -p "Are you REALLY sure? Type 'destroy' to confirm: " -r
echo
if [[ ! $REPLY == "destroy" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Get cluster details before destruction
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
AWS_REGION=$(terraform output -raw region 2>/dev/null || echo "")

# Delete Kubernetes services with LoadBalancers (they create AWS resources)
if [ -n "$CLUSTER_NAME" ] && [ -n "$AWS_REGION" ]; then
    echo ""
    echo "Checking for LoadBalancer services..."
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" 2>/dev/null || true
    
    LB_SERVICES=$(kubectl get svc --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace)/\(.metadata.name)"' || echo "")
    
    if [ -n "$LB_SERVICES" ]; then
        echo "Deleting LoadBalancer services..."
        for SVC in $LB_SERVICES; do
            NAMESPACE=$(echo "$SVC" | cut -d'/' -f1)
            NAME=$(echo "$SVC" | cut -d'/' -f2)
            echo "  Deleting service $NAME in namespace $NAMESPACE..."
            kubectl delete svc "$NAME" -n "$NAMESPACE" --wait=true 2>/dev/null || true
        done
        echo "Waiting for LoadBalancers to be deleted..."
        sleep 30
    fi
fi

# Terraform destroy
echo ""
echo "Destroying Terraform resources..."
terraform destroy -auto-approve

echo ""
echo -e "${YELLOW}========================================"
echo "Cleanup Complete!"
echo "========================================${NC}"
echo ""
echo "All infrastructure has been destroyed."
echo ""
