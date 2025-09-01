#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}Rapyd Sentinel Complete Deployment${NC}"
echo "===================================="

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check for required tools
    for tool in terraform aws kubectl docker; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${RED}Error: $tool is not installed${NC}"
            exit 1
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}Error: AWS credentials not configured${NC}"
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All prerequisites met${NC}"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    echo -e "${YELLOW}Deploying infrastructure with Terraform...${NC}"
    cd "$PROJECT_ROOT/terraform/environments/production"
    
    # Initialize Terraform
    terraform init
    
    # Apply Terraform configuration
    terraform apply -auto-approve
    
    # Export outputs for later use
    terraform output -json > "$PROJECT_ROOT/terraform-outputs.json"
    
    cd "$PROJECT_ROOT"
    echo -e "${GREEN}Infrastructure deployed successfully${NC}"
}

# Function to wait for Lambda to be ready
wait_for_lambda() {
    echo -e "${YELLOW}Waiting for Lambda function to be ready...${NC}"
    
    LAMBDA_NAME="rapyd-sentinel-eks-deployer"
    
    for i in {1..30}; do
        STATE=$(aws lambda get-function \
            --function-name $LAMBDA_NAME \
            --region us-east-1 \
            --query 'Configuration.State' \
            --output text 2>/dev/null || echo "")

        if [ "$STATE" = "Active" ]; then
            echo -e "${GREEN}Lambda function is active${NC}"
            return 0
        fi

        echo "Waiting for Lambda to be active... (attempt $i/30, current state: $STATE)"
        sleep 5
    done

    echo -e "${RED}Lambda function did not become active in time${NC}"
    return 1
}

# Function to configure aws-auth for both clusters
configure_aws_auth() {
    echo -e "${YELLOW}Verifying aws-auth configuration for EKS clusters...${NC}"

    # Both clusters' aws-auth are now configured by Terraform during cluster creation
    # This solves the chicken-and-egg problem for the Backend cluster
    # and ensures consistency for both clusters

    echo -e "${GREEN}Gateway cluster aws-auth configured by Terraform${NC}"
    echo -e "${GREEN}Backend cluster aws-auth configured by Terraform${NC}"

    # COMMENTED OUT - Cannot reach backend cluster from outside VPC
    # Even with public access enabled, the cluster in private subnets is not reachable
    #
    # # Configure Backend cluster aws-auth (needs temporary public access)
    # echo "Configuring Backend cluster aws-auth..."
    #
    # # Check current public access state
    # CURRENT_PUBLIC_ACCESS=$(aws eks describe-cluster --name eks-backend --region us-east-1 --query 'cluster.resourcesVpcConfig.endpointPublicAccess' --output text)
    #
    # if [ "$CURRENT_PUBLIC_ACCESS" = "false" ]; then
    #     # Enable public access temporarily
    #     echo "Enabling public access for backend cluster temporarily..."
    #     aws eks update-cluster-config \
    #         --name eks-backend \
    #         --region us-east-1 \
    #         --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true \
    #         --output json > /dev/null
    #
    #     # Wait for update to complete
    #     echo "Waiting for backend cluster update to complete..."
    #     aws eks wait cluster-active --name eks-backend --region us-east-1
    # else
    #     echo "Backend cluster public access is already enabled"
    # fi
    #
    # ... rest of backend configuration commented out ...

    echo -e "${GREEN}Both clusters are now configured for Lambda access${NC}"
}

# Function to deploy services to EKS clusters
deploy_services() {
    echo -e "${YELLOW}Deploying services to EKS clusters...${NC}"

    LAMBDA_NAME="rapyd-sentinel-eks-deployer"

    # Deploy to both clusters
    echo "Invoking Lambda to deploy services..."
    aws lambda invoke \
        --function-name $LAMBDA_NAME \
        --payload $(echo '{"action": "deploy", "target": "both"}' | base64) \
        --region us-east-1 \
        /tmp/deploy-result.json \
        --cli-read-timeout 300

    # Check deployment result
    if grep -q '"statusCode": 200' /tmp/deploy-result.json; then
        echo -e "${GREEN}Services deployed successfully${NC}"
        cat /tmp/deploy-result.json | jq -r '.body' 2>/dev/null || cat /tmp/deploy-result.json
    else
        echo -e "${RED}Service deployment failed${NC}"
        cat /tmp/deploy-result.json
        return 1
    fi
}

# Function to verify deployment
verify_deployment() {
    echo -e "${YELLOW}Getting deployment status...${NC}"

    LAMBDA_NAME="rapyd-sentinel-eks-deployer"

    # Wait a bit for services to initialize
    echo "Waiting for services to initialize..."
    sleep 20

    # Get status from Lambda
    aws lambda invoke \
        --function-name $LAMBDA_NAME \
        --payload $(echo '{"action": "status", "target": "both"}' | base64) \
        --region us-east-1 \
        /tmp/status-result.json \
        --cli-read-timeout 60 > /dev/null 2>&1

    # Parse the response
    STATUS_BODY=$(cat /tmp/status-result.json | jq -r '.body' 2>/dev/null)

    # Extract the Gateway service URL from the status output
    GATEWAY_URL=$(echo "$STATUS_BODY" | grep -oP 'Service gateway-service URL: \K[^\s]+' | head -1)

    if [ -z "$GATEWAY_URL" ]; then
        # Try to get it from terraform outputs as fallback
        cd "$PROJECT_ROOT/terraform/environments/production"
        GATEWAY_LB=$(terraform output -raw gateway_load_balancer_dns 2>/dev/null || echo "")
        cd "$PROJECT_ROOT"
        if [ -n "$GATEWAY_LB" ]; then
            GATEWAY_URL="http://$GATEWAY_LB"
        fi
    fi

    # Display the Gateway URL prominently
    echo ""
    if [ -n "$GATEWAY_URL" ]; then
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}🌐 Your application is available at:${NC}"
        echo -e "${GREEN}   $GATEWAY_URL${NC}"
        echo -e "${GREEN}================================================${NC}"

        # Save the URL for easy access
        echo "$GATEWAY_URL" > "$PROJECT_ROOT/.gateway_url"

        # Quick connectivity test
        echo ""
        echo "Testing connectivity..."
        response=$(curl -s -m 5 "$GATEWAY_URL" 2>/dev/null || echo "")

        if [[ "$response" == *"Hello from backend pod:"* ]]; then
            echo -e "${GREEN}✅ End-to-end connectivity verified!${NC}"
            echo "Response: $response"
        elif [ -n "$response" ]; then
            echo -e "${YELLOW}⚠️  Gateway is responding. Backend connection may take a moment.${NC}"
        else
            echo -e "${YELLOW}⚠️  Services are starting up. Try the URL in a few moments.${NC}"
        fi
    else
        echo -e "${RED}Could not determine Gateway URL${NC}"
        echo "Run the following to check status:"
        echo "  ./scripts/check-status.sh"
    fi
}

# Function to display access information
display_access_info() {
    echo ""
    echo "====================================="
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo "====================================="
    echo ""

    # Display the Gateway URL prominently if available
    if [ -f "$PROJECT_ROOT/.gateway_url" ]; then
        GATEWAY_URL=$(cat "$PROJECT_ROOT/.gateway_url")
        echo -e "${GREEN}🌐 Access your application at:${NC}"
        echo -e "${GREEN}   $GATEWAY_URL${NC}"
        echo ""
    fi

    echo "Useful Commands:"
    echo "----------------"
    echo ""
    echo "Check deployment status:"
    echo "  aws lambda invoke --function-name rapyd-sentinel-eks-deployer \\"
    echo "    --payload \$(echo '{\"action\": \"status\", \"target\": \"both\"}' | base64) \\"
    echo "    /tmp/status.json --region us-east-1"
    echo "  cat /tmp/status.json | jq -r '.body'"
    echo ""
    echo "Redeploy services:"
    echo "  aws lambda invoke --function-name rapyd-sentinel-eks-deployer \\"
    echo "    --payload \$(echo '{\"action\": \"deploy\", \"target\": \"both\"}' | base64) \\"
    echo "    /tmp/deploy.json --region us-east-1"
    echo ""
    echo "Access Gateway cluster directly:"
    echo "  kubectl get all -n default --context arn:aws:eks:us-east-1:\$(aws sts get-caller-identity --query Account --output text):cluster/eks-gateway"
    echo ""
    echo "View Lambda logs:"
    echo "  aws logs tail /aws/lambda/rapyd-sentinel-eks-deployer --follow"
    echo ""
    echo "Destroy everything:"
    echo "  $SCRIPT_DIR/destroy.sh"
}

# Main execution
main() {
    echo "Starting full deployment at $(date)"
    
    # Check prerequisites
    check_prerequisites
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Wait for Lambda to be ready
    wait_for_lambda
    
    # Configure aws-auth for both clusters
    configure_aws_auth
    
    # Additional wait to ensure everything is stable
    echo "Waiting for infrastructure to stabilize..."
    sleep 30
    
    # Deploy services
    deploy_services
    
    # Verify deployment
    verify_deployment
    
    # Display access information
    display_access_info
    
    echo ""
    echo "Deployment completed at $(date)"
}

# Run main function
main "$@"