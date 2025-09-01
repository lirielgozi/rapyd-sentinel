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

echo -e "${GREEN}Rapyd Sentinel Status Check${NC}"
echo "============================"
echo ""

# Check infrastructure status
echo -e "${YELLOW}Checking infrastructure...${NC}"

# Check VPCs
VPC_GATEWAY=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vpc-gateway" --region us-west-2 --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")
VPC_BACKEND=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vpc-backend" --region us-west-2 --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")

if [ -n "$VPC_GATEWAY" ] && [ "$VPC_GATEWAY" != "None" ]; then
    echo -e "  ${GREEN}✓ Gateway VPC: $VPC_GATEWAY${NC}"
else
    echo -e "  ${RED}✗ Gateway VPC: Not found${NC}"
fi

if [ -n "$VPC_BACKEND" ] && [ "$VPC_BACKEND" != "None" ]; then
    echo -e "  ${GREEN}✓ Backend VPC: $VPC_BACKEND${NC}"
else
    echo -e "  ${RED}✗ Backend VPC: Not found${NC}"
fi

# Check EKS clusters
echo ""
echo -e "${YELLOW}Checking EKS clusters...${NC}"

GATEWAY_CLUSTER=$(aws eks describe-cluster --name eks-gateway --region us-west-2 --query "cluster.status" --output text 2>/dev/null || echo "")
BACKEND_CLUSTER=$(aws eks describe-cluster --name eks-backend --region us-west-2 --query "cluster.status" --output text 2>/dev/null || echo "")

if [ "$GATEWAY_CLUSTER" = "ACTIVE" ]; then
    echo -e "  ${GREEN}✓ Gateway Cluster: ACTIVE${NC}"
else
    echo -e "  ${RED}✗ Gateway Cluster: $GATEWAY_CLUSTER${NC}"
fi

if [ "$BACKEND_CLUSTER" = "ACTIVE" ]; then
    echo -e "  ${GREEN}✓ Backend Cluster: ACTIVE${NC}"
else
    echo -e "  ${RED}✗ Backend Cluster: $BACKEND_CLUSTER${NC}"
fi

# Check Lambda function
echo ""
echo -e "${YELLOW}Checking Lambda function...${NC}"

LAMBDA_STATE=$(aws lambda get-function --function-name rapyd-sentinel-eks-deployer --region us-west-2 --query "Configuration.State" --output text 2>/dev/null || echo "")

if [ "$LAMBDA_STATE" = "Active" ]; then
    echo -e "  ${GREEN}✓ Lambda Deployer: Active${NC}"
else
    echo -e "  ${RED}✗ Lambda Deployer: $LAMBDA_STATE${NC}"
fi

# Get deployment status from Lambda
echo ""
echo -e "${YELLOW}Checking deployment status...${NC}"

if [ "$LAMBDA_STATE" = "Active" ]; then
    aws lambda invoke \
        --function-name rapyd-sentinel-eks-deployer \
        --payload $(echo '{"action": "status", "target": "both"}' | base64) \
        --region us-west-2 \
        /tmp/status-check.json \
        --cli-read-timeout 60 > /dev/null 2>&1
    
    STATUS_BODY=$(cat /tmp/status-check.json | jq -r '.body' 2>/dev/null)
    
    # Check pods in clusters
    if echo "$STATUS_BODY" | grep -q "Gateway cluster pods:.*nginx-proxy"; then
        echo -e "  ${GREEN}✓ Gateway: nginx-proxy is running${NC}"
    else
        echo -e "  ${RED}✗ Gateway: nginx-proxy not found${NC}"
    fi
    
    if echo "$STATUS_BODY" | grep -q "Backend cluster pods:.*backend-service"; then
        echo -e "  ${GREEN}✓ Backend: backend-service is running${NC}"
    else
        echo -e "  ${RED}✗ Backend: backend-service not found${NC}"
    fi
    
    # Extract and test Gateway URL
    GATEWAY_URL=$(echo "$STATUS_BODY" | grep -oP '(?<=Gateway URL: )[^\s]+' | head -1)
    
    if [ -z "$GATEWAY_URL" ] && [ -f "$PROJECT_ROOT/.gateway_url" ]; then
        GATEWAY_URL=$(cat "$PROJECT_ROOT/.gateway_url")
    fi
    
    if [ -n "$GATEWAY_URL" ]; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}🌐 Gateway URL: $GATEWAY_URL${NC}"
        echo -e "${GREEN}========================================${NC}"
        
        echo ""
        echo "Testing connectivity..."
        response=$(curl -s -m 5 "$GATEWAY_URL" 2>/dev/null || echo "Connection failed")
        
        if [[ "$response" == *"Hello from backend pod:"* ]]; then
            echo -e "${GREEN}✅ End-to-end connectivity: WORKING${NC}"
            echo "Response: $response"
        elif [[ "$response" == "Connection failed" ]]; then
            echo -e "${RED}✗ Cannot connect to Gateway URL${NC}"
        else
            echo -e "${YELLOW}⚠️  Gateway responding but backend proxy may have issues${NC}"
            echo "Response: $response"
        fi
    else
        echo -e "${YELLOW}Gateway URL not available${NC}"
    fi
else
    echo -e "${RED}Lambda function not active - cannot check deployment status${NC}"
fi

echo ""
echo "====================================="
echo "Status check complete"