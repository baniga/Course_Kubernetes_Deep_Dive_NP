# Deployment Guide

Complete step-by-step guide to deploy your EKS infrastructure.

## Prerequisites

### Required Tools
- AWS CLI v2.x
- Terraform >= 1.5.0
- kubectl >= 1.28
- helm >= 3.0
- jq (for JSON parsing)

### AWS Account Requirements
- AWS Account with appropriate permissions
- IAM user with administrator access (or specific EKS permissions)
- AWS CLI configured with credentials

## Step-by-Step Deployment

### Step 1: Prepare Your Environment

#### 1.1 Clone the Repository
```bash
git clone <repository-url>
cd aws-eks-infrastructure
```

#### 1.2 Configure AWS Credentials
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
# Enter your default output format (json)
```

#### 1.3 Verify AWS Access
```bash
aws sts get-caller-identity
```

### Step 2: Configure Terraform Variables

#### 2.1 Copy Example Configuration
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

#### 2.2 Edit terraform.tfvars
```bash
# Use your preferred editor
vi terraform.tfvars
# or
nano terraform.tfvars
```

#### 2.3 Essential Variables to Configure

**Required:**
```hcl
aws_region   = "us-east-1"          # Your AWS region
cluster_name = "my-production-eks"   # Unique cluster name
```

**Security (Highly Recommended):**
```hcl
# Restrict API access to your IP
cluster_endpoint_public_access_cidrs = ["YOUR_IP_ADDRESS/32"]

# Example:
cluster_endpoint_public_access_cidrs = ["203.0.113.42/32"]
```

**Optional (for cost optimization):**
```hcl
# Enable spot instances for non-production
enable_spot_instances = true

# Reduce node count for dev/test
node_group_min_size     = 1
node_group_max_size     = 3
node_group_desired_size = 1
```

### Step 3: Initialize Terraform

```bash
cd terraform
terraform init
```

**Expected Output:**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...

Terraform has been successfully initialized!
```

### Step 4: Review the Plan

```bash
terraform plan -out=tfplan
```

**Review the output carefully:**
- Number of resources to be created
- Estimated costs
- Security configurations
- Network topology

### Step 5: Deploy Infrastructure

#### 5.1 Apply Terraform Configuration
```bash
terraform apply tfplan
```

This will create:
- VPC with public and private subnets
- Internet Gateway and NAT Gateway
- Security Groups
- EKS Cluster (takes ~15-20 minutes)
- EKS Node Groups
- IAM Roles and Policies
- CloudWatch Log Groups
- VPC Endpoints

**Expected Duration:** 20-30 minutes

#### 5.2 Save Outputs
```bash
terraform output > ../outputs.txt
```

### Step 6: Configure kubectl

#### 6.1 Update kubeconfig
```bash
aws eks update-kubeconfig \
  --region $(terraform output -raw region) \
  --name $(terraform output -raw cluster_name)
```

#### 6.2 Verify Cluster Access
```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

**Expected Output:**
```
NAME                                       STATUS   ROLES    AGE   VERSION
ip-10-0-11-xxx.ec2.internal               Ready    <none>   5m    v1.28.x
ip-10-0-12-xxx.ec2.internal               Ready    <none>   5m    v1.28.x
```

### Step 7: Post-Deployment Configuration

#### 7.1 Verify EKS Add-ons
```bash
kubectl get pods -n kube-system
```

You should see:
- coredns pods
- kube-proxy pods
- vpc-cni pods
- ebs-csi-controller pods

#### 7.2 Verify Cluster Autoscaler
```bash
kubectl get deployment cluster-autoscaler -n kube-system
kubectl logs -n kube-system deployment/cluster-autoscaler
```

#### 7.3 Test Node Scaling
```bash
# Create test deployment
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scale-test
spec:
  replicas: 10
  selector:
    matchLabels:
      app: scale-test
  template:
    metadata:
      labels:
        app: scale-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
EOF

# Watch nodes scale up
kubectl get nodes -w
```

### Step 8: Deploy Sample Application

#### 8.1 Deploy Example App
```bash
kubectl apply -f ../docs/examples/deployment-example.yaml
```

#### 8.2 Check Deployment Status
```bash
kubectl get all -n demo-app
```

#### 8.3 Get LoadBalancer URL
```bash
kubectl get svc -n demo-app nginx-service
```

Wait for EXTERNAL-IP to be assigned, then test:
```bash
curl http://<EXTERNAL-IP>
```

### Step 9: Set Up Monitoring (Optional)

#### 9.1 Install Metrics Server
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

#### 9.2 Verify Metrics
```bash
kubectl top nodes
kubectl top pods -A
```

#### 9.3 Install Kubernetes Dashboard (Optional)
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

### Step 10: Configure Security

#### 10.1 Apply Network Policies
```bash
kubectl apply -f ../docs/examples/network-policy-example.yaml
```

#### 10.2 Create RBAC Policies
```bash
# Example: Create read-only user
kubectl create serviceaccount readonly-user -n default
kubectl create clusterrolebinding readonly-user \
  --clusterrole=view \
  --serviceaccount=default:readonly-user
```

#### 10.3 Enable Pod Security Standards
```bash
kubectl label namespace demo-app \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

## Verification Checklist

After deployment, verify:

- [ ] Cluster is running: `kubectl cluster-info`
- [ ] All nodes are Ready: `kubectl get nodes`
- [ ] All system pods are running: `kubectl get pods -A`
- [ ] Cluster Autoscaler is working: `kubectl logs -n kube-system deployment/cluster-autoscaler`
- [ ] EBS CSI Driver is installed: `kubectl get pods -n kube-system | grep ebs-csi`
- [ ] Can create LoadBalancer service: Deploy example app
- [ ] Can create persistent volumes: Deploy storage example
- [ ] API endpoint is accessible from your IP
- [ ] CloudWatch logs are being collected

## Common Issues and Solutions

### Issue 1: Nodes Not Joining Cluster

**Symptoms:** Nodes show in EC2 but not in `kubectl get nodes`

**Solutions:**
1. Check security groups allow traffic
2. Verify VPC DNS settings are enabled
3. Check node IAM role has correct policies
4. Review CloudWatch logs: `/aws/eks/<cluster-name>/cluster`

### Issue 2: Unable to Pull Container Images

**Symptoms:** ImagePullBackOff errors

**Solutions:**
1. Verify VPC endpoints for ECR are created
2. Check NAT Gateway is routing correctly
3. Verify node IAM role has ECR permissions
4. Check security group allows outbound HTTPS

### Issue 3: Load Balancer Not Creating

**Symptoms:** Service stuck in Pending state

**Solutions:**
1. Verify public subnets are tagged correctly
2. Check IAM role has ELB permissions
3. Install AWS Load Balancer Controller (see below)
4. Review service annotations

### Issue 4: High Costs

**Symptoms:** AWS bill higher than expected

**Solutions:**
1. Enable Cluster Autoscaler
2. Set resource limits on pods
3. Use Spot instances
4. Review [Cost Optimization Guide](COST_OPTIMIZATION.md)
5. Delete unused LoadBalancers

## Advanced Configuration

### Install AWS Load Balancer Controller

```bash
# Add IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.2/docs/install/iam_policy.json
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Install controller
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$(terraform output -raw cluster_name) \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw aws_load_balancer_controller_role_arn)
```

### Enable Container Insights

```bash
# In terraform.tfvars
enable_container_insights = true

# Apply changes
terraform apply
```

### Configure Private Cluster

```bash
# In terraform.tfvars
cluster_endpoint_public_access = false
cluster_endpoint_private_access = true

# Apply changes
terraform apply
```

**Note:** You'll need VPN or Direct Connect to access the cluster.

## Maintenance

### Upgrade Kubernetes Version

1. Update `cluster_version` in terraform.tfvars
2. Run `terraform plan` to review changes
3. Run `terraform apply`
4. Update node groups (will cause rolling update)

### Update Node Group

1. Modify node configuration in terraform.tfvars
2. Run `terraform apply`
3. Nodes will be replaced with new configuration

### Backup and Disaster Recovery

#### Backup Terraform State
```bash
# If using S3 backend
aws s3 cp s3://your-bucket/terraform.tfstate ./backup/
```

#### Export Kubernetes Resources
```bash
# Backup all resources
kubectl get all --all-namespaces -o yaml > k8s-backup.yaml
```

#### Snapshot EBS Volumes
```bash
# Automated via AWS Backup (configure separately)
aws backup create-backup-plan --cli-input-json file://backup-plan.json
```

## Cleanup

To destroy all resources:

```bash
# Use cleanup script
cd ../scripts
./cleanup.sh

# Or manually
cd ../terraform
terraform destroy
```

**Warning:** This will delete all resources and cannot be undone!

## Support and Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## Getting Help

1. Check [GitHub Issues](../../issues)
2. Review AWS CloudWatch Logs
3. Check EKS cluster logs: `aws eks describe-cluster --name <cluster-name>`
4. Review security group rules
5. Verify IAM permissions

For production issues, engage AWS Support.
