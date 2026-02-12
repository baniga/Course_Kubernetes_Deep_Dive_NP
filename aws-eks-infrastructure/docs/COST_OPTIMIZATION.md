# Cost Optimization Guide

This guide explains the cost optimization strategies implemented in this infrastructure and additional measures you can take.

## Current Cost Breakdown

### Monthly Costs (us-east-1)

| Resource | Configuration | Monthly Cost |
|----------|---------------|--------------|
| EKS Control Plane | 1 cluster | $73.00 |
| EC2 Instances | 2x t3.medium (on-demand) | $60.74 |
| NAT Gateway | 1x NAT Gateway | $32.85 |
| EBS Storage | 100 GB (2x 50GB) | $10.00 |
| Data Transfer | ~100 GB/month | $10-20 |
| VPC Endpoints | 2x interface endpoints | $14.60 |
| **Estimated Total** | | **~$190-200/month** |

### Cost Optimization Features Enabled

#### 1. Single NAT Gateway
- **Savings**: $65-70/month vs. 3 NAT Gateways
- **Trade-off**: Single point of failure for internet access
- **Recommendation**: Use 3 NAT Gateways for production HA

```hcl
single_nat_gateway = true  # Set to false for HA
```

#### 2. VPC Endpoints
- **Savings**: Eliminates data transfer charges for S3, ECR
- **Cost**: $7.30/endpoint/month + $0.01/GB processed
- **Break-even**: ~1TB data transfer/month

Current endpoints:
- S3 (Gateway endpoint - FREE)
- ECR API (Interface endpoint - $7.30/month)
- ECR DKR (Interface endpoint - $7.30/month)

#### 3. Log Retention
- **Control plane logs**: 7 days
- **VPC Flow Logs**: 7 days
- **Savings**: Reduces CloudWatch Logs storage costs

#### 4. Cluster Autoscaler
- Automatically scales nodes based on demand
- Removes nodes when not needed
- Can reduce costs by 30-50% for variable workloads

#### 5. Optional Spot Instances
- **Savings**: Up to 90% vs. on-demand
- **Trade-off**: Can be interrupted with 2-minute notice
- **Use case**: Stateless, fault-tolerant workloads

```hcl
enable_spot_instances = true
```

## Additional Cost Optimization Strategies

### 1. Right-Sizing Instances

#### Current: t3.medium
- 2 vCPU, 4 GB RAM
- $0.0416/hour = $30.37/month

#### Alternative Options

| Instance Type | vCPU | RAM | Price/hour | Monthly | Use Case |
|---------------|------|-----|------------|---------|----------|
| t3.small | 2 | 2 GB | $0.0208 | $15.18 | Light workloads |
| t3.medium | 2 | 4 GB | $0.0416 | $30.37 | General purpose |
| t3a.medium | 2 | 4 GB | $0.0374 | $27.30 | 10% cheaper AMD |
| t3.large | 2 | 8 GB | $0.0832 | $60.74 | Memory intensive |

**Savings**: Switch to t3a.medium saves ~$6/month per instance

### 2. Reserved Instances / Savings Plans

#### 1-Year Commitment
- **All Upfront**: 40% savings
- **Partial Upfront**: 35% savings
- **No Upfront**: 30% savings

**Example**: 2x t3.medium with 1-year no upfront
- Current: $60.74/month
- With Savings Plan: $42.52/month
- **Savings**: $18.22/month ($218/year)

#### 3-Year Commitment
- **Savings**: Up to 65%
- **Example**: $60.74 → $21.26/month

### 3. Spot Instances Strategy

#### Mixed Instance Policy
```hcl
node_group_desired_size = 2  # On-demand for critical workloads
enable_spot_instances = true
spot_instance_types = ["t3.medium", "t3a.medium", "t2.medium"]
```

**Savings**: If 50% workload on Spot at 70% discount:
- Current: $60.74/month (2 instances)
- With Spot: $30.37 (on-demand) + $9.11 (spot) = $39.48
- **Savings**: $21.26/month

### 4. Node Scheduling Optimization

#### Cluster Autoscaler Configuration
```yaml
--scale-down-delay-after-add=10m
--scale-down-unneeded-time=10m
--skip-nodes-with-local-storage=false
```

#### Pod Priority Classes
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 100
globalDefault: false
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000
globalDefault: false
```

### 5. Schedule Non-Production Workloads

#### Stop Dev/Test Clusters at Night
```bash
# Stop at 7 PM
aws eks update-nodegroup-config \
  --cluster-name dev-cluster \
  --nodegroup-name main \
  --scaling-config minSize=0,maxSize=0,desiredSize=0

# Start at 8 AM
aws eks update-nodegroup-config \
  --cluster-name dev-cluster \
  --nodegroup-name main \
  --scaling-config minSize=2,maxSize=5,desiredSize=2
```

**Savings**: 65% for dev/test environments (12 hours/day, 5 days/week)

### 6. Storage Optimization

#### EBS Volume Types

| Type | IOPS | Throughput | Price/GB/month |
|------|------|------------|----------------|
| gp3 | 3,000-16,000 | 125-1,000 MB/s | $0.08 |
| gp2 | 3-16,000 | 250 MB/s max | $0.10 |
| io2 | 64,000 max | 1,000 MB/s max | $0.125 + IOPS |

**Recommendation**: Use gp3 (20% cheaper than gp2)

#### EBS Snapshots
- Incremental snapshots to S3
- Lifecycle policies to delete old snapshots
- Snapshot pricing: $0.05/GB/month

### 7. Data Transfer Optimization

#### Reduce Costs
1. **Use VPC Endpoints** (already implemented)
2. **CloudFront CDN** for static assets
3. **Keep traffic within same AZ** when possible
4. **Use S3 Transfer Acceleration** for large uploads

#### Data Transfer Pricing
- Within same AZ: FREE
- Between AZs: $0.01/GB
- Internet outbound: $0.09/GB (first 10 TB)

### 8. Monitoring & Alerting

#### Cost Anomaly Detection
```bash
aws ce create-anomaly-monitor \
  --anomaly-monitor Name=EKS-Cost-Monitor,MonitorType=DIMENSIONAL \
  --tags Key=Project,Value=EKS
```

#### Budget Alerts
```bash
aws budgets create-budget \
  --account-id 123456789012 \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

#### CloudWatch Billing Alarm
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name eks-cost-alert \
  --alarm-description "Alert when EKS costs exceed $250" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --evaluation-periods 1 \
  --threshold 250 \
  --comparison-operator GreaterThanThreshold
```

## Cost Optimization Checklist

### Immediate Actions (0-1 week)
- [ ] Enable Cluster Autoscaler
- [ ] Set up cost allocation tags
- [ ] Configure log retention policies
- [ ] Review and right-size node instances
- [ ] Enable Spot instances for dev/test

### Short-term Actions (1-4 weeks)
- [ ] Analyze workload patterns
- [ ] Implement pod resource limits
- [ ] Set up budget alerts
- [ ] Review EBS volume usage
- [ ] Configure PV reclaim policies

### Medium-term Actions (1-3 months)
- [ ] Purchase Savings Plans / Reserved Instances
- [ ] Implement workload scheduling
- [ ] Set up automated start/stop for non-prod
- [ ] Optimize container images
- [ ] Review data transfer patterns

### Long-term Actions (3-12 months)
- [ ] Migrate to Fargate for specific workloads
- [ ] Consider multi-region optimization
- [ ] Implement FinOps practices
- [ ] Regular cost reviews
- [ ] Continuous optimization

## Cost Monitoring Tools

### AWS Native
- **AWS Cost Explorer**: Visualize spending
- **AWS Budgets**: Set spending limits
- **AWS Cost Anomaly Detection**: ML-based alerts
- **Cost Allocation Tags**: Track by team/project

### Third-party Tools
- **Kubecost**: Kubernetes-native cost monitoring
- **CloudHealth**: Multi-cloud cost management
- **Cloudability**: FinOps platform
- **Datadog**: Infrastructure monitoring + costs

### Install Kubecost (Free)
```bash
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost --create-namespace \
  --set kubecostToken="aGVsbUBrdWJlY29zdC5jb20=xm343yadf98"
```

## Estimated Savings Summary

| Strategy | Monthly Savings | Implementation |
|----------|----------------|----------------|
| t3a.medium vs t3.medium | $6/instance | Easy |
| 1-year Savings Plan | $18/month | Medium |
| 50% Spot instances | $21/month | Medium |
| Single NAT Gateway | Already done | ✓ |
| VPC Endpoints | Already done | ✓ |
| Log retention (7 days) | Already done | ✓ |
| Dev/Test scheduling | 65% of dev costs | Medium |
| Cluster Autoscaler | 30-50% variable | Already done |
| **Total Potential Savings** | **$80-120/month** | |

## Annual Cost Projection

### Current Configuration
- **Monthly**: ~$190-200
- **Annual**: ~$2,280-2,400

### Optimized Configuration
- **Monthly**: ~$110-120
- **Annual**: ~$1,320-1,440
- **Savings**: ~$960-1,080/year (40-45%)

## Multi-Environment Strategy

### Production
- High availability (3 NAT Gateways)
- Reserved Instances
- Minimal Spot usage
- Full monitoring
- **Cost**: $300-350/month

### Staging
- Single NAT Gateway
- Mix of on-demand and Spot
- Reduced monitoring
- **Cost**: $150-180/month

### Development
- Single NAT Gateway
- Mostly Spot instances
- Scheduled (12h/day, 5 days/week)
- **Cost**: $50-70/month

**Total**: $500-600/month for 3 environments

## Cost Optimization Best Practices

1. **Tag Everything**: Use consistent tagging for cost allocation
2. **Monitor Continuously**: Review costs weekly
3. **Right-size Regularly**: Review every month
4. **Use Automation**: Automate start/stop schedules
5. **Leverage Spot**: Use Spot for non-critical workloads
6. **Commit When Stable**: Purchase Savings Plans after 3 months
7. **Clean Up**: Delete unused resources immediately
8. **Optimize Images**: Smaller images = faster deployments = less cost
9. **Use Limits**: Set resource limits on all pods
10. **Review IAM**: Prevent unauthorized resource creation

## Questions?

For cost-related questions, contact:
- FinOps Team: finops@example.com
- Cloud Architect: cloudarch@example.com
