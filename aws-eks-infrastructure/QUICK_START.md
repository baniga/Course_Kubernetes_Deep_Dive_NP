# AWS EKS Infrastructure - Quick Start 🚀

**Deploy a production-ready Kubernetes cluster in 30 minutes!**

## What You Get

✅ **Secure** - Private subnets, KMS encryption, IRSA, Security Groups  
✅ **Scalable** - Multi-AZ, auto-scaling, 2-100+ nodes  
✅ **Cost-Optimized** - ~$190/month with optimization options  
✅ **Production-Ready** - HA, monitoring, logging, backups  

## Prerequisites

- AWS Account
- AWS CLI configured
- Terraform >= 1.5.0

## Deploy in 4 Steps

### 1️⃣ Configure
```bash
cd aws-eks-infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit: Set your AWS region and cluster name
```

### 2️⃣ Deploy
```bash
cd ../scripts
./setup.sh
```

### 3️⃣ Verify
```bash
kubectl get nodes
kubectl get pods -A
```

### 4️⃣ Deploy Your App
```bash
kubectl apply -f ../docs/examples/deployment-example.yaml
```

## Cost Breakdown

| Component | Monthly Cost |
|-----------|--------------|
| EKS Cluster | $73 |
| 2x t3.medium | $61 |
| NAT Gateway | $33 |
| Storage & Network | $20-30 |
| **Total** | **~$190-200** |

**Optimization potential**: Down to $110-120/month

## Architecture

```
Internet → ALB → Kubernetes Service → Pods
             ↓              ↓
        Public Subnet  Private Subnet
             ↓              ↓
        NAT Gateway    Worker Nodes (3 AZs)
             ↓
        EKS Control Plane (AWS Managed)
```

## Key Features

### Security 🔒
- Private subnets for all nodes
- KMS encryption for secrets
- VPC Flow Logs
- Security Groups & NACLs
- No SSH access by default

### Cost Optimization 💰
- Single NAT Gateway (configurable)
- VPC Endpoints (free S3/ECR access)
- Cluster Autoscaler
- Spot instance support
- Efficient log retention

### High Availability 🌐
- 3 Availability Zones
- Multi-AZ control plane
- Auto Scaling Groups
- Health checks
- Pod disruption budgets

## Documentation

📖 [README](README.md) - Full overview  
🏗️ [ARCHITECTURE](docs/ARCHITECTURE.md) - Design details  
🔒 [SECURITY](docs/SECURITY.md) - Security guide  
💰 [COST_OPTIMIZATION](docs/COST_OPTIMIZATION.md) - Save money  
📚 [DEPLOYMENT_GUIDE](docs/DEPLOYMENT_GUIDE.md) - Step-by-step  

## Common Commands

```bash
# View cluster info
kubectl cluster-info
kubectl get nodes
kubectl top nodes

# Deploy example app
kubectl apply -f docs/examples/deployment-example.yaml
kubectl get svc -n demo-app

# Scale deployment
kubectl scale deployment nginx-deployment -n demo-app --replicas=5

# View logs
kubectl logs -n kube-system deployment/cluster-autoscaler

# Clean up
./scripts/cleanup.sh
```

## Troubleshooting

**Nodes not joining?**
- Check security groups
- Verify VPC DNS settings
- Review CloudWatch logs

**High costs?**
- Enable Cluster Autoscaler
- Use Spot instances
- Review [Cost Optimization Guide](docs/COST_OPTIMIZATION.md)

**Need help?**
- Check [Deployment Guide](docs/DEPLOYMENT_GUIDE.md)
- Review [Security Guide](docs/SECURITY.md)
- Open an issue

## Next Steps

1. ✅ Deploy the infrastructure
2. 📊 Install monitoring (Prometheus/Grafana)
3. 🔐 Configure network policies
4. 🚀 Deploy your applications
5. 💰 Optimize costs

## Support

- 📧 Issues: GitHub Issues
- 📖 Docs: `/docs` directory
- 🌐 AWS Support: AWS Console

---

**Ready to deploy?** Run `./scripts/setup.sh` and you'll have a production EKS cluster in 30 minutes! 🎉
