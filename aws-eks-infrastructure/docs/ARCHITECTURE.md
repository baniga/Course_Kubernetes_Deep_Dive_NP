# Architecture Overview

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                               │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                           │ │
│  │                                                                 │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │              Availability Zone A                          │ │ │
│  │  │  ┌────────────────┐    ┌────────────────┐               │ │ │
│  │  │  │ Public Subnet  │    │ Private Subnet │               │ │ │
│  │  │  │  10.0.1.0/24   │    │  10.0.11.0/24  │               │ │ │
│  │  │  │                │    │  ┌──────────┐  │               │ │ │
│  │  │  │  [NAT GW]      │◄───┼──│  Node 1  │  │               │ │ │
│  │  │  │  [ALB]         │    │  └──────────┘  │               │ │ │
│  │  │  └────────────────┘    └────────────────┘               │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  │                                                                 │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │              Availability Zone B                          │ │ │
│  │  │  ┌────────────────┐    ┌────────────────┐               │ │ │
│  │  │  │ Public Subnet  │    │ Private Subnet │               │ │ │
│  │  │  │  10.0.2.0/24   │    │  10.0.12.0/24  │               │ │ │
│  │  │  │                │    │  ┌──────────┐  │               │ │ │
│  │  │  │                │    │  │  Node 2  │  │               │ │ │
│  │  │  │                │    │  └──────────┘  │               │ │ │
│  │  │  └────────────────┘    └────────────────┘               │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  │                                                                 │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │              Availability Zone C                          │ │ │
│  │  │  ┌────────────────┐    ┌────────────────┐               │ │ │
│  │  │  │ Public Subnet  │    │ Private Subnet │               │ │ │
│  │  │  │  10.0.3.0/24   │    │  10.0.13.0/24  │               │ │ │
│  │  │  └────────────────┘    └────────────────┘               │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  │                                                                 │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │                   EKS Control Plane                       │ │ │
│  │  │            (AWS Managed, Multi-AZ)                        │ │ │
│  │  │   ┌──────────┐  ┌──────────┐  ┌──────────┐              │ │ │
│  │  │   │ API Srv  │  │ etcd     │  │ Scheduler│              │ │ │
│  │  │   └──────────┘  └──────────┘  └──────────┘              │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  │                                                                 │ │
│  │  ┌──────────────────────────────────────────────────────────┐ │ │
│  │  │                   VPC Endpoints                           │ │ │
│  │  │   • S3 (Gateway)                                          │ │ │
│  │  │   • ECR API (Interface)                                   │ │ │
│  │  │   • ECR DKR (Interface)                                   │ │ │
│  │  └──────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                    Security Layer                            │  │
│  │  • KMS Encryption    • Security Groups   • Network ACLs     │  │
│  │  • IAM Roles/IRSA    • VPC Flow Logs     • CloudWatch       │  │
│  └─────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────┘
```

## Component Details

### VPC Architecture

#### Network Design
- **CIDR Block**: 10.0.0.0/16 (65,536 IPs)
- **Subnets**: 6 subnets across 3 AZs
  - 3 Public subnets (256 IPs each)
  - 3 Private subnets (256 IPs each)

#### Routing
- **Public Subnets**: Route to Internet Gateway
- **Private Subnets**: Route to NAT Gateway
- **Cost Optimization**: Single NAT Gateway (can be configured for HA)

### EKS Cluster

#### Control Plane
- **Managed by AWS**: High availability across multiple AZs
- **Kubernetes Version**: 1.28 (configurable)
- **API Endpoint**: Public + Private (configurable)
- **Encryption**: KMS encryption for secrets

#### Worker Nodes
- **Managed Node Groups**: Auto Scaling Groups managed by EKS
- **Instance Types**: t3.medium (2 vCPU, 4 GB RAM)
- **Scaling**: 2-5 nodes (configurable)
- **Storage**: 50 GB gp3 EBS volumes per node
- **Distribution**: Spread across all AZs

#### Add-ons
- **VPC CNI**: Pod networking
- **CoreDNS**: DNS resolution
- **kube-proxy**: Network proxy
- **EBS CSI Driver**: Persistent volume support
- **Cluster Autoscaler**: Automatic node scaling

### Security Architecture

#### Network Security Layers

**Layer 1: Network ACLs**
- Stateless firewall at subnet level
- Allow HTTP/HTTPS inbound to public subnets
- Allow all traffic within VPC

**Layer 2: Security Groups**
- Stateful firewall at instance level
- Cluster security group: API server access
- Node security group: Worker node traffic
- VPC endpoint security group: Private endpoint access

**Layer 3: Kubernetes Network Policies**
- Pod-to-pod communication control
- Namespace isolation
- Ingress/Egress rules

#### Identity and Access Management

**AWS IAM**
- Cluster Role: EKS control plane permissions
- Node Role: Worker node permissions
- Service-specific roles: Autoscaler, Load Balancer Controller

**IRSA (IAM Roles for Service Accounts)**
- Pod-level IAM permissions
- No shared credentials
- Automatic token rotation

**Kubernetes RBAC**
- Role-based access control
- Service accounts for applications
- Cluster roles and role bindings

#### Data Protection

**Encryption at Rest**
- EKS secrets: AWS KMS encryption
- EBS volumes: Encrypted by default
- S3 state: Server-side encryption

**Encryption in Transit**
- TLS for all API communication
- HTTPS for external traffic
- VPC encryption options available

### High Availability

#### Multi-AZ Design
- Resources distributed across 3 AZs
- Control plane automatically distributed
- Worker nodes spread across AZs
- Pod anti-affinity for critical workloads

#### Failure Scenarios

**AZ Failure**
- Control plane: No impact (AWS manages HA)
- Worker nodes: Remaining nodes in other AZs continue
- Cluster Autoscaler: Launches nodes in healthy AZs

**Node Failure**
- Kubernetes reschedules pods to healthy nodes
- Auto Scaling Group replaces failed node
- Health checks detect and remediate

**NAT Gateway Failure**
- Single NAT: Private subnet internet access lost
- Multi-NAT: Only affected AZ loses access
- Recommendation: Use 3 NAT Gateways for production

### Scalability

#### Horizontal Scaling

**Pod Level (HPA)**
- Metrics-based autoscaling
- CPU and memory metrics
- Custom metrics support
- Scale: 1-100+ pods per deployment

**Node Level (Cluster Autoscaler)**
- Automatic node provisioning
- Removes underutilized nodes
- Respects pod disruption budgets
- Scale: 2-100+ nodes per cluster

#### Vertical Scaling
- Adjust pod resource requests/limits
- Resize EBS volumes (online)
- Change node instance types
- Vertical Pod Autoscaler (optional)

### Monitoring and Logging

#### CloudWatch Integration
- Control plane logs (5 types)
- VPC Flow Logs
- Container Insights (optional)
- Custom metrics

#### Kubernetes Native
- Metrics Server for HPA
- kubectl top commands
- Cluster Autoscaler logs
- Application logs

### Cost Optimization

#### Built-in Optimizations
1. **Single NAT Gateway**: Save $65/month
2. **VPC Endpoints**: Reduce data transfer costs
3. **Cluster Autoscaler**: Scale down unused nodes
4. **Log retention**: 7 days (reduce storage)
5. **t3.medium instances**: Burstable performance

#### Additional Options
1. **Spot Instances**: Up to 90% savings
2. **Reserved Instances**: Up to 65% savings
3. **Right-sizing**: Match resources to workload
4. **Scheduled scaling**: Stop dev/test off-hours

## Traffic Flow

### Inbound Traffic (Internet → Pod)
```
Internet → Route53 → ALB → Service → Pod
         [Public Subnet]   [Private Subnet]
```

### Outbound Traffic (Pod → Internet)
```
Pod → NAT Gateway → Internet Gateway → Internet
    [Private Subnet]  [Public Subnet]
```

### Internal Traffic (Pod → Pod)
```
Pod A → VPC CNI → Pod B
      [Same or different node]
```

### Pod → AWS Service
```
Pod → VPC Endpoint → AWS Service (S3, ECR)
    [No internet gateway needed]
```

## Infrastructure as Code

### Terraform Modules
- **versions.tf**: Provider versions and backend
- **variables.tf**: Input variables
- **vpc.tf**: VPC, subnets, routing
- **security.tf**: Security groups, NACLs, KMS
- **iam.tf**: IAM roles and policies
- **eks.tf**: EKS cluster and node groups
- **outputs.tf**: Output values

### State Management
- **Backend**: S3 + DynamoDB (optional)
- **State Locking**: DynamoDB table
- **Encryption**: Server-side encryption
- **Versioning**: Enabled for rollback

## Deployment Strategies

### Blue-Green Deployment
1. Create new node group (green)
2. Cordon old nodes (blue)
3. Drain old nodes
4. Delete old node group

### Rolling Update
1. Update node group configuration
2. Kubernetes gradually replaces nodes
3. Respects pod disruption budgets
4. Zero downtime deployment

### Canary Deployment
1. Deploy new version to subset of pods
2. Monitor metrics and errors
3. Gradually increase traffic
4. Rollback if issues detected

## Compliance and Governance

### Security Standards
- CIS Kubernetes Benchmark
- AWS Well-Architected Framework
- PCI DSS compliance ready
- HIPAA compliance ready

### Audit and Compliance
- CloudTrail: All API calls logged
- EKS audit logs: Kubernetes API audit
- VPC Flow Logs: Network traffic audit
- AWS Config: Resource compliance

### Disaster Recovery
- **RTO**: < 1 hour (redeploy from Terraform)
- **RPO**: Depends on backup strategy
- **Multi-Region**: Can be configured
- **Backup**: Velero for Kubernetes resources

## Best Practices Implemented

### Security ✓
- Private subnets for workers
- KMS encryption enabled
- IRSA for pod permissions
- Security groups with least privilege
- Network ACLs for defense in depth
- VPC Flow Logs enabled

### High Availability ✓
- Multi-AZ deployment
- Auto Scaling Groups
- Health checks configured
- Pod anti-affinity rules
- Pod disruption budgets

### Scalability ✓
- Cluster Autoscaler enabled
- HPA support configured
- Resource limits defined
- Multi-instance type support

### Cost Optimization ✓
- Single NAT Gateway (dev/test)
- VPC Endpoints for S3/ECR
- Spot instance support
- Efficient log retention
- Right-sized instances

### Operational Excellence ✓
- Infrastructure as Code
- GitOps ready
- CI/CD pipeline template
- Comprehensive documentation
- Monitoring and logging

## Future Enhancements

### Potential Additions
- [ ] Service Mesh (Istio/Linkerd)
- [ ] GitOps (ArgoCD/Flux)
- [ ] Secrets Management (External Secrets Operator)
- [ ] Advanced Monitoring (Prometheus/Grafana)
- [ ] Log Aggregation (ELK/Loki)
- [ ] Backup Solution (Velero)
- [ ] Multi-cluster setup
- [ ] Multi-region failover

### Scalability Enhancements
- [ ] Karpenter (advanced autoscaling)
- [ ] Fargate profiles
- [ ] GPU node groups
- [ ] ARM-based nodes (Graviton)

## References

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
