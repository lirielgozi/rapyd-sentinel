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

echo -e "${GREEN}Rapyd Sentinel Validation Script${NC}"
echo "================================="

# Validate Terraform
validate_terraform() {
    echo -e "${YELLOW}Validating Terraform configuration...${NC}"
    
    # Check formatting
    terraform fmt -check -recursive "$PROJECT_ROOT/terraform/" || {
        echo -e "${RED}Terraform formatting issues found. Run 'terraform fmt -recursive terraform/'${NC}"
        exit 1
    }
    
    # Validate modules
    for module in "$PROJECT_ROOT"/terraform/modules/*; do
        if [ -d "$module" ]; then
            echo "Validating module: $(basename $module)"
            terraform -chdir="$module" init -backend=false
            terraform -chdir="$module" validate
        fi
    done
    
    # Validate production environment
    cd "$PROJECT_ROOT/terraform/environments/production"
    terraform init -backend=false
    terraform validate
    cd "$PROJECT_ROOT"
    
    echo -e "${GREEN}Terraform validation passed!${NC}"
}

# Validate Kubernetes manifests
validate_kubernetes() {
    echo -e "${YELLOW}Validating Kubernetes manifests...${NC}"
    
    # Install kubeval if not present
    if ! command -v kubeval &> /dev/null; then
        echo "Installing kubeval..."
        wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz
        tar xf kubeval-linux-amd64.tar.gz
        sudo mv kubeval /usr/local/bin
        rm kubeval-linux-amd64.tar.gz
    fi
    
    # Validate backend manifests
    for file in "$PROJECT_ROOT"/kubernetes/backend/*.yaml; do
        echo "Validating: $file"
        kubeval "$file" --ignore-missing-schemas
    done
    
    # Validate gateway manifests
    for file in "$PROJECT_ROOT"/kubernetes/gateway/*.yaml; do
        echo "Validating: $file"
        kubeval "$file" --ignore-missing-schemas
    done
    
    echo -e "${GREEN}Kubernetes manifests validation passed!${NC}"
}

# Test connectivity
test_connectivity() {
    echo -e "${YELLOW}Testing connectivity...${NC}"
    
    # Get LoadBalancer URL
    kubectl config use-context arn:aws:eks:us-west-2:$(aws sts get-caller-identity --query Account --output text):cluster/eks-gateway
    LB_URL=$(kubectl get svc gateway-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    if [ -z "$LB_URL" ]; then
        echo -e "${RED}LoadBalancer URL not found${NC}"
        exit 1
    fi
    
    echo "Testing endpoint: http://${LB_URL}"
    
    # Test health endpoint
    curl -f http://${LB_URL}/health || {
        echo -e "${RED}Health check failed${NC}"
        exit 1
    }
    
    # Test main endpoint
    curl -f http://${LB_URL}/ || {
        echo -e "${RED}Main endpoint test failed${NC}"
        exit 1
    }
    
    echo -e "${GREEN}Connectivity tests passed!${NC}"
}

# Check security configurations
check_security() {
    echo -e "${YELLOW}Checking security configurations...${NC}"
    
    # Check NetworkPolicies
    kubectl config use-context arn:aws:eks:us-west-2:$(aws sts get-caller-identity --query Account --output text):cluster/eks-backend
    kubectl get networkpolicies -n default
    
    kubectl config use-context arn:aws:eks:us-west-2:$(aws sts get-caller-identity --query Account --output text):cluster/eks-gateway
    kubectl get networkpolicies -n default
    
    # Check Security Groups
    echo "Checking VPC Security Groups..."
    aws ec2 describe-security-groups --filters "Name=tag:Project,Values=RapydSentinel" --query 'SecurityGroups[*].[GroupName,Description]' --output table
    
    echo -e "${GREEN}Security checks complete!${NC}"
}

# Main execution
main() {
    echo -e "${YELLOW}Choose validation option:${NC}"
    echo "1) Full validation"
    echo "2) Terraform only"
    echo "3) Kubernetes only"
    echo "4) Connectivity test"
    echo "5) Security check"
    read -p "Enter choice [1-5]: " choice
    
    case $choice in
        1)
            validate_terraform
            validate_kubernetes
            test_connectivity
            check_security
            ;;
        2)
            validate_terraform
            ;;
        3)
            validate_kubernetes
            ;;
        4)
            test_connectivity
            ;;
        5)
            check_security
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}All validations passed!${NC}"
}

main