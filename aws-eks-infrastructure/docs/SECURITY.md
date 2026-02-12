# Security Best Practices

This document outlines the security measures implemented in this EKS infrastructure.

## Network Security

### VPC Isolation
- **Private Subnets**: Worker nodes run in private subnets with no direct internet access
- **Public Subnets**: Only load balancers and NAT gateways in public subnets
- **Multi-AZ**: Resources distributed across 3 availability zones

### Network Segmentation
```
10.0.0.0/16 (VPC)
├── 10.0.1.0/24  - Public Subnet AZ-A
├── 10.0.2.0/24  - Public Subnet AZ-B
├── 10.0.3.0/24  - Public Subnet AZ-C
├── 10.0.11.0/24 - Private Subnet AZ-A (Worker Nodes)
├── 10.0.12.0/24 - Private Subnet AZ-B (Worker Nodes)
└── 10.0.13.0/24 - Private Subnet AZ-C (Worker Nodes)
```

### Security Groups
- **Cluster Security Group**: Controls access to EKS control plane
- **Node Security Group**: Controls traffic to/from worker nodes
- **VPC Endpoint Security Group**: Controls access to VPC endpoints

### Network ACLs
- **Defense in Depth**: Additional layer beyond security groups
- **Public Subnet ACL**: Allows HTTP/HTTPS inbound, all outbound
- **Private Subnet ACL**: Allows VPC traffic, ephemeral ports for responses

### VPC Flow Logs
- All network traffic logged to CloudWatch
- Retention: 7 days (configurable)
- Useful for security audits and troubleshooting

## Access Control

### IAM Best Practices
- **Least Privilege**: All roles follow principle of least privilege
- **IRSA Enabled**: IAM Roles for Service Accounts for pod-level permissions
- **No Root Access**: No SSH keys configured by default
- **SSM Access**: Use AWS Systems Manager Session Manager instead of SSH

### EKS API Access
- **Private Endpoint**: Enabled by default
- **Public Endpoint**: Restricted by CIDR blocks (configure in tfvars)
- **RBAC**: Kubernetes RBAC enabled by default

### Authentication & Authorization
- AWS IAM Authenticator for cluster access
- Kubernetes RBAC for resource authorization
- Service Accounts with IRSA for pod permissions

## Data Protection

### Encryption at Rest
- **EKS Secrets**: Encrypted with KMS
- **EBS Volumes**: Encrypted by default
- **S3 Backend**: State file encryption enabled
- **Key Rotation**: KMS keys have automatic rotation enabled

### Encryption in Transit
- **TLS**: All API communication uses TLS
- **Inter-node**: CNI encryption available (can be enabled)
- **Load Balancers**: Support for TLS termination

## Monitoring & Logging

### Control Plane Logging
All EKS control plane logs enabled:
- API Server logs
- Audit logs
- Authenticator logs
- Controller Manager logs
- Scheduler logs

### Retention
- Control plane logs: 7 days
- VPC Flow Logs: 7 days
- Can be increased based on compliance requirements

## Compliance Features

### Audit Trail
- CloudTrail integration (AWS account level)
- EKS audit logs
- VPC Flow Logs
- All API calls logged

### Pod Security
- Pod Security Standards enforced
- Security contexts required
- Privileged containers blocked by default
- Host network access restricted

## Security Checklist

### Pre-Deployment
- [ ] Review and restrict `cluster_endpoint_public_access_cidrs`
- [ ] Configure `allowed_ssh_cidr_blocks` (or leave empty)
- [ ] Set up AWS Organizations SCPs
- [ ] Enable AWS GuardDuty
- [ ] Enable AWS Security Hub
- [ ] Configure AWS Config rules

### Post-Deployment
- [ ] Review IAM roles and policies
- [ ] Configure Pod Security Policies
- [ ] Install network policies (Calico/Cilium)
- [ ] Set up AWS WAF for load balancers
- [ ] Configure AWS Shield for DDoS protection
- [ ] Install security scanning tools (Falco, Trivy)
- [ ] Set up vulnerability scanning
- [ ] Configure SIEM integration

### Ongoing
- [ ] Regular security patches
- [ ] Review CloudWatch logs
- [ ] Monitor VPC Flow Logs
- [ ] Rotate credentials
- [ ] Update Kubernetes version
- [ ] Review RBAC permissions
- [ ] Audit pod security contexts

## Hardening Recommendations

### 1. Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

### 2. Pod Security Policy
```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
  readOnlyRootFilesystem: false
```

### 3. Restrict Public Access
Update `terraform.tfvars`:
```hcl
cluster_endpoint_public_access_cidrs = ["YOUR_IP/32"]
```

### 4. Enable GuardDuty
```bash
aws guardduty create-detector --enable --region us-east-1
```

### 5. Private Cluster (No Public Access)
```hcl
cluster_endpoint_public_access = false
cluster_endpoint_private_access = true
```

## Incident Response

### Security Event Response
1. **Detection**: CloudWatch alarms, GuardDuty findings
2. **Isolation**: Network policies, security group updates
3. **Investigation**: CloudWatch logs, VPC Flow Logs, audit logs
4. **Remediation**: Patch, update, rotate credentials
5. **Recovery**: Restore from backups, redeploy
6. **Post-mortem**: Document, improve controls

### Emergency Contacts
- Security Team: security@example.com
- On-Call: oncall@example.com
- AWS Support: Open ticket in AWS Console

## Additional Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
