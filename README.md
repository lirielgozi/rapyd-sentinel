# Rapyd Sentinel - Multi-VPC EKS Infrastructure

## Overview

Rapyd Sentinel is a secure, scalable multi-VPC EKS infrastructure demonstrating complete network isolation and automated deployment on AWS. The architecture separates concerns into two isolated domains with automated cross-cluster deployment capabilities:

1. **Gateway Layer (Public)** - Internet-facing NGINX proxy in isolated VPC
2. **Backend Layer (Private)** - Internal services accessible only through Gateway
3. **Lambda Deployer** - Automated deployment to both EKS clusters using container images

## Architecture

```
Internet
    ↓
[Load Balancer] (Public Subnet)
    ↓
[Gateway VPC] - vpc-gateway (10.0.0.0/16)
    ├── Public Subnets: 10.0.101.0/24, 10.0.102.0/24
    ├── Private Subnets: 10.0.1.0/24, 10.0.2.0/24
    └── EKS Cluster: eks-gateway
        └── NGINX Proxy → 
                ↓
         [VPC Peering]
                ↓
[Backend VPC] - vpc-backend (10.1.0.0/16)
    ├── Private Subnets: 10.1.1.0/24, 10.1.2.0/24
    └── EKS Cluster: eks-backend
        └── Backend Service (Internal Only)
```

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured
- Terraform >= 1.5.0
- kubectl
- Docker
- GitHub account (for CI/CD)

## Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/lirielgozi/rapyd-sentinel
cd rapyd-sentinel
```

### 2. Configure AWS Credentials
```bash
aws configure
# Or use AWS SSO
aws sso login
```

### 3. Complete Automated Deployment
```bash
# Deploy everything automatically (infrastructure + services)
./scripts/deploy-all.sh

# This will:
# 1. Create VPCs and networking (with VPC peering)
# 2. Deploy two EKS clusters (Gateway and Backend)
# 3. Configure EKS Access Entries for Lambda and current user
# 4. Build and push Docker images to ECR
# 5. Deploy Lambda function for automated deployments
# 6. Deploy backend and gateway services via Lambda
```

### 4. Access the Application
After deployment completes, you'll see the Gateway URL. Test it:
```bash
# The deploy-all.sh script will output the Gateway URL
# Example: http://a03ff947d357c4a0e93affa272074887-2140612237.us-west-2.elb.amazonaws.com/

# Test the endpoint (Gateway proxies to Backend)
curl http://<GATEWAY_URL>/
# Response: Hello from backend pod:<pod-name> on node:<node-name>

# Test health endpoint
curl http://<GATEWAY_URL>/health
# Response: healthy
```

### 5. Manage Deployments with Lambda
```bash
# Check deployment status
aws lambda invoke --function-name rapyd-sentinel-eks-deployer \
  --payload $(echo '{"action": "status", "target": "both"}' | base64) \
  /tmp/status.json --region us-west-2

# Redeploy services
aws lambda invoke --function-name rapyd-sentinel-eks-deployer \
  --payload $(echo '{"action": "deploy", "target": "both"}' | base64) \
  /tmp/deploy.json --region us-west-2
```

## Project Structure

```
.
├── terraform/
│   ├── modules/
│   │   ├── vpc/              # Reusable VPC module
│   │   ├── eks/              # EKS cluster module with Access Entries
│   │   ├── networking/       # VPC peering and routing
│   │   └── lambda-deployer/  # Lambda-based deployment module
│   └── environments/
│       └── production/       # Production environment config
├── kubernetes/
│   ├── backend/             # Backend service (BusyBox HTTP server)
│   └── gateway/             # Gateway proxy (NGINX)
├── scripts/
│   ├── deploy-all.sh        # Complete automated deployment
│   ├── destroy.sh           # Clean up all resources
│   └── validate.sh          # Infrastructure validation
└── README.md
```

## Security Features

### Network Isolation
- **VPC Separation**: Gateway and Backend operate in isolated VPCs
- **Private Subnets**: All EKS nodes run in private subnets
- **No Public EC2**: No direct internet access to compute resources

### Access Control
- **EKS Access Entries**: Modern API-based authentication (no aws-auth ConfigMap manipulation)
- **Security Groups**: Least-privilege rules for cross-VPC communication
- **IAM Roles**: Service-specific permissions using IRSA
- **Lambda Execution Role**: Automated deployment permissions for both clusters

### Data Protection
- **Encryption at Rest**: EKS secrets encrypted with KMS
- **Flow Logs**: VPC flow logs for security monitoring
- **Private Endpoints**: Backend cluster API is completely private

## Networking Configuration

### VPC Peering
- Bidirectional peering between Gateway and Backend VPCs
- DNS resolution enabled across peered VPCs
- Route tables configured for private communication

### Security Groups
- Gateway → Backend: Allowed on ports 80, 443, 8080
- Backend → Gateway: Response traffic only
- Cluster → Nodes: Required Kubernetes communication

### Service Communication
- Gateway NGINX proxies all requests to Backend via internal LoadBalancer
- Backend services only accessible through VPC peering
- Cross-VPC DNS resolution for service discovery

## Automated Deployment Features

### Lambda-Based Deployment
- **Container-based Lambda**: Uses Docker image with kubectl and AWS CLI
- **Multi-cluster Support**: Deploys to both Gateway and Backend clusters
- **EKS Access Entries**: Uses modern AWS API for authentication
- **Dynamic Configuration**: Automatically configures NGINX proxy with Backend URL

### Complete Automation
- **No Manual Steps**: Everything from infrastructure to service deployment is automated
- **Idempotent**: Can be safely run multiple times
- **Self-configuring**: Lambda gets cluster details from Terraform outputs
- **Cross-VPC Aware**: Handles internal LoadBalancer DNS resolution

## Cost Optimization

- **Single NAT Gateway**: Option to use one NAT per VPC (development)
- **SPOT Instances**: Support for SPOT capacity in node groups
- **Auto-scaling**: Nodes scale based on workload (min: 1, max: 4)
- **ECR Lifecycle**: Automatic cleanup of old container images

## Monitoring & Observability

- **CloudWatch Logs**: EKS control plane logging enabled
- **VPC Flow Logs**: Network traffic monitoring
- **Application Metrics**: Basic metrics exposed by services

## Key Achievements

This infrastructure demonstrates:

1. **Complete Network Isolation**: Two VPCs with controlled communication via VPC peering
2. **Automated Deployment**: Lambda-based deployment to both EKS clusters
3. **Modern Authentication**: EKS Access Entries instead of ConfigMap manipulation
4. **Zero Manual Steps**: Fully automated from `terraform destroy` to working application
5. **Production Patterns**: Internal LoadBalancers, private subnets, security groups

## Future Improvements

### Security Enhancements
- [ ] change terraform to open tofu
- [ ] AWS WAF on Load Balancer
- [ ] Secrets management with HashiCorp Vault with AWS Secrets Manager
- [ ] Pod Security Standards enforcement

### Operational Excellence
- [ ] GitOps with ArgoCD (not a fan to be honest)
- [ ] Prometheus + Grafana monitoring

### Scalability
- [ ] Horizontal Pod Autoscaling
- [ ] Cluster Autoscaler
- [ ] Multi-region deployment
- [ ] Database layer with RDS

## Validation & Testing

### Test End-to-End Connectivity
```bash
# Get Gateway URL (output from deploy-all.sh)
GATEWAY_URL="http://<your-gateway-lb>.elb.amazonaws.com/"

# Test Gateway -> Backend proxy
curl $GATEWAY_URL
# Expected: Hello from backend pod:<pod-name> on node:<node-name>

# Test multiple times to see load balancing
for i in {1..5}; do curl -s $GATEWAY_URL; echo; done
```

### Verify Deployment via Lambda
```bash
# Check deployment status
aws lambda invoke --function-name rapyd-sentinel-eks-deployer \
  --payload $(echo '{"action": "status", "target": "both"}' | base64) \
  /tmp/status.json --region us-west-2
cat /tmp/status.json | jq .

# Get logs from pods
aws lambda invoke --function-name rapyd-sentinel-eks-deployer \
  --payload $(echo '{"action": "logs", "target": "both"}' | base64) \
  /tmp/logs.json --region us-west-2
cat /tmp/logs.json | jq .
```

### Verify Infrastructure
```bash
# Check VPC peering
aws ec2 describe-vpc-peering-connections --region us-west-2

# Check EKS clusters
aws eks list-clusters --region us-west-2

# Check Lambda function
aws lambda get-function --function-name rapyd-sentinel-eks-deployer --region us-west-2
```

## Cleanup

To destroy all resources:
```bash
cd terraform/environments/production
terraform destroy -auto-approve

# This will remove:
# - Both EKS clusters and node groups
# - VPCs and all networking components
# - Lambda function and ECR repositories
# - All IAM roles and policies
# - CloudWatch log groups
```

## Troubleshooting

### Common Issues and Solutions

#### "502 Bad Gateway" from Gateway
- **Cause**: Backend pods not ready or LoadBalancer DNS issues
- **Solution**: Redeploy backend via Lambda:
  ```bash
  aws lambda invoke --function-name rapyd-sentinel-eks-deployer \
    --payload $(echo '{"action": "deploy", "target": "backend"}' | base64) \
    /tmp/deploy.json --region us-west-2
  ```

#### Cannot see pods in AWS Console
- **Cause**: IAM user not in EKS Access Entries
- **Solution**: Added automatically by deploy-all.sh, or add manually in EKS console under "Access" tab

#### Lambda deployment fails
- **Cause**: Lambda role not in cluster access entries
- **Solution**: Terraform automatically configures this via EKS Access Entries API

#### Cross-VPC communication issues
- **Cause**: Security groups or VPC peering misconfigured
- **Solution**: Check security group rules allow traffic on port 80 between VPCs

## CI/CD with GitHub Actions

The project includes GitHub Actions workflow for continuous deployment:

### Workflow Triggers
- **Push to main**: Automatically deploys new versions
- **Pull Request**: Builds and validates without deploying
- **Manual dispatch**: Deploy on-demand via GitHub UI

### Deployment Pipeline
```yaml
name: Deploy Services

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-west-2
      
      - name: Login to Amazon ECR
        run: |
          aws ecr get-login-password --region us-west-2 | \
          docker login --username AWS --password-stdin \
          ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.us-west-2.amazonaws.com
      
      - name: Build and push Backend image
        run: |
          docker build -t rapyd-sentinel/backend kubernetes/backend/
          docker tag rapyd-sentinel/backend:latest \
            ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.us-west-2.amazonaws.com/rapyd-sentinel/backend:${{ github.sha }}
          docker push ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.us-west-2.amazonaws.com/rapyd-sentinel/backend:${{ github.sha }}
          docker push ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.us-west-2.amazonaws.com/rapyd-sentinel/backend:latest
      
      - name: Build and push Gateway image  
        run: |
          docker build -t rapyd-sentinel/gateway kubernetes/gateway/
          docker tag rapyd-sentinel/gateway:latest \
            ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.us-west-2.amazonaws.com/rapyd-sentinel/gateway:${{ github.sha }}
          docker push ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.us-west-2.amazonaws.com/rapyd-sentinel/gateway:${{ github.sha }}
          docker push ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.us-west-2.amazonaws.com/rapyd-sentinel/gateway:latest
      
      - name: Deploy via Lambda
        run: |
          aws lambda invoke \
            --function-name rapyd-sentinel-eks-deployer \
            --payload '{"action": "deploy", "target": "both", "image_tag": "${{ github.sha }}"}' \
            --cli-binary-format raw-in-base64-out \
            /tmp/deploy-result.json
          
          # Check deployment status
          if grep -q '"success":true' /tmp/deploy-result.json; then
            echo "✅ Deployment successful"
          else
            echo "❌ Deployment failed"
            cat /tmp/deploy-result.json
            exit 1
          fi
```

### Required GitHub Secrets
Configure these in your repository settings:
- `AWS_ACCESS_KEY_ID`: IAM user access key
- `AWS_SECRET_ACCESS_KEY`: IAM user secret key
- `AWS_ACCOUNT_ID`: Your AWS account ID (e.g., 992553183326)

### Deployment Flow
1. **Code Push**: Developer pushes to main branch
2. **Image Build**: GitHub Actions builds Docker images
3. **ECR Push**: Images pushed to ECR with git SHA tag
4. **Lambda Invoke**: Lambda deployer updates both EKS clusters
5. **Verification**: Lambda returns success/failure status

### Rollback
To rollback to a previous version:
```bash
# Deploy specific image tag
aws lambda invoke --function-name rapyd-sentinel-eks-deployer \
  --payload '{"action": "deploy", "target": "both", "image_tag": "<previous-git-sha>"}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/rollback.json
```

## License

MIT

## Contact

For questions or issues, please open a GitHub issue.