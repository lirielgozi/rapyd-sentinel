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

echo -e "${RED}Rapyd Sentinel Destroy Script${NC}"
echo "=============================="
echo -e "${RED}WARNING: This will destroy all resources!${NC}"

# Confirmation
confirm_destroy() {
    read -p "Are you sure you want to destroy all resources? Type 'yes' to confirm: " confirmation
    if [ "$confirmation" != "yes" ]; then
        echo -e "${YELLOW}Destruction cancelled${NC}"
        exit 0
    fi
}

# Destroy Kubernetes resources
destroy_kubernetes() {
    echo -e "${YELLOW}Destroying Kubernetes resources...${NC}"
    
    # Check if clusters exist
    GATEWAY_EXISTS=$(aws eks describe-cluster --name eks-gateway --region us-east-1 2>/dev/null && echo "yes" || echo "no")
    BACKEND_EXISTS=$(aws eks describe-cluster --name eks-backend --region us-east-1 2>/dev/null && echo "yes" || echo "no")
    
    # Update kubeconfig only if clusters exist
    if [ "$GATEWAY_EXISTS" = "yes" ]; then
        aws eks update-kubeconfig --region us-east-1 --name eks-gateway 2>/dev/null || true
    fi
    if [ "$BACKEND_EXISTS" = "yes" ]; then
        aws eks update-kubeconfig --region us-east-1 --name eks-backend 2>/dev/null || true
    fi
    
    # Destroy all resources in default namespace for both clusters
    if [ "$GATEWAY_EXISTS" = "yes" ]; then
        echo "Cleaning gateway cluster..."
        kubectl config use-context arn:aws:eks:us-east-1:$(aws sts get-caller-identity --query Account --output text):cluster/eks-gateway 2>/dev/null && {
            # Delete services first (this triggers LB deletion)
            echo "  Deleting services..."
            kubectl delete services --all -n default --ignore-not-found=true
            
            # Delete deployments and other resources
            echo "  Deleting deployments and pods..."
            kubectl delete deployments,pods,replicasets --all -n default --ignore-not-found=true
            
            # Delete configmaps
            echo "  Deleting configmaps..."
            kubectl delete configmap --all -n default --ignore-not-found=true
            
            # Also try to delete from kubernetes/gateway if it exists
            [ -d "$PROJECT_ROOT/kubernetes/gateway/" ] && kubectl delete -f "$PROJECT_ROOT/kubernetes/gateway/" --ignore-not-found=true
        } || echo "Could not access gateway cluster"
    fi
    
    if [ "$BACKEND_EXISTS" = "yes" ]; then
        echo "Cleaning backend cluster..."
        kubectl config use-context arn:aws:eks:us-east-1:$(aws sts get-caller-identity --query Account --output text):cluster/eks-backend 2>/dev/null && {
            # Delete services first (this triggers LB deletion)
            echo "  Deleting services..."
            kubectl delete services --all -n default --ignore-not-found=true
            
            # Delete deployments and other resources
            echo "  Deleting deployments and pods..."
            kubectl delete deployments,pods,replicasets --all -n default --ignore-not-found=true
            
            # Delete configmaps
            echo "  Deleting configmaps..."
            kubectl delete configmap --all -n default --ignore-not-found=true
            
            # Also try to delete from kubernetes/backend if it exists
            [ -d "$PROJECT_ROOT/kubernetes/backend/" ] && kubectl delete -f "$PROJECT_ROOT/kubernetes/backend/" --ignore-not-found=true
        } || echo "Could not access backend cluster"
    fi
    
    # Wait for load balancers to be deleted
    echo "Waiting for Kubernetes load balancers to be deleted..."
    sleep 60
    
    # Clean up any orphaned load balancers
    echo "Checking for orphaned load balancers..."
    
    # Delete ALL Classic ELBs in our VPCs (more aggressive cleanup)
    for lb in $(aws elb describe-load-balancers --region us-east-1 --query "LoadBalancerDescriptions[].LoadBalancerName" --output text 2>/dev/null); do
        # Check if this LB is in one of our VPCs
        vpc_id=$(aws elb describe-load-balancers --load-balancer-names "$lb" --region us-east-1 --query "LoadBalancerDescriptions[0].VPCId" --output text 2>/dev/null || echo "")
        if [ ! -z "$vpc_id" ]; then
            # Check if VPC has our project tag
            project_tag=$(aws ec2 describe-vpcs --vpc-ids "$vpc_id" --region us-east-1 --query "Vpcs[0].Tags[?Key=='Project'].Value" --output text 2>/dev/null || echo "")
            if [ "$project_tag" = "RapydSentinel" ] || [[ "$lb" == *"a03ff"* ]] || [[ "$lb" == *"ab9c4"* ]]; then
                echo "Deleting Classic ELB: $lb"
                aws elb delete-load-balancer --load-balancer-name "$lb" --region us-east-1 || true
            fi
        fi
    done
    
    for arn in $(aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[*].LoadBalancerArn" --output text 2>/dev/null); do
        tags=$(aws elbv2 describe-tags --resource-arns "$arn" --region us-east-1 --query "TagDescriptions[0].Tags[?Key=='kubernetes.io/cluster/eks-gateway' || Key=='kubernetes.io/cluster/eks-backend'].Value" --output text 2>/dev/null)
        if [ ! -z "$tags" ]; then
            echo "Deleting orphaned ALB/NLB: $arn"
            aws elbv2 delete-load-balancer --load-balancer-arn "$arn" --region us-east-1 || true
        fi
    done
    
    # Clean up orphaned target groups created by Kubernetes
    echo "Checking for orphaned target groups..."
    for tg_arn in $(aws elbv2 describe-target-groups --region us-east-1 --query "TargetGroups[?starts_with(TargetGroupName, 'k8s-')].TargetGroupArn" --output text 2>/dev/null); do
        echo "Deleting orphaned target group: $(echo $tg_arn | cut -d'/' -f2)"
        aws elbv2 delete-target-group --target-group-arn "$tg_arn" --region us-east-1 || true
    done
    
    # Clean up orphaned security groups created by Kubernetes
    echo "Checking for orphaned security groups..."
    # Wait a bit for ENIs to detach after LB deletion
    sleep 10
    for sg_id in $(aws ec2 describe-security-groups --region us-east-1 --query "SecurityGroups[?contains(GroupName, 'k8s-elb') || contains(GroupName, 'k8s-traffic') || contains(Tags[?Key=='kubernetes.io/cluster/eks-gateway'].Value, 'owned') || contains(Tags[?Key=='kubernetes.io/cluster/eks-backend'].Value, 'owned')].GroupId" --output text 2>/dev/null); do
        sg_name=$(aws ec2 describe-security-groups --group-ids "$sg_id" --region us-east-1 --query "SecurityGroups[0].GroupName" --output text 2>/dev/null)
        echo "Deleting orphaned security group: $sg_name ($sg_id)"
        # First, remove all ingress and egress rules to avoid dependency issues
        aws ec2 revoke-security-group-ingress --group-id "$sg_id" --region us-east-1 --source-group "$sg_id" --protocol all 2>/dev/null || true
        aws ec2 revoke-security-group-egress --group-id "$sg_id" --region us-east-1 --source-group "$sg_id" --protocol all 2>/dev/null || true
        # Then delete the security group
        aws ec2 delete-security-group --group-id "$sg_id" --region us-east-1 || true
    done
    
    echo -e "${GREEN}Kubernetes resources destroyed${NC}"
}

# Clean up network dependencies
cleanup_network_dependencies() {
    echo -e "${YELLOW}Cleaning up network dependencies...${NC}"
    
    # Clean up Elastic IPs
    echo "Checking for unassociated Elastic IPs..."
    for eip in $(aws ec2 describe-addresses --region us-east-1 --query "Addresses[?AssociationId==null].AllocationId" --output text 2>/dev/null); do
        echo "Releasing Elastic IP: $eip"
        aws ec2 release-address --allocation-id "$eip" --region us-east-1 || true
    done
    
    # Clean up orphaned Network Interfaces
    echo "Checking for orphaned network interfaces..."
    for vpc_id in $(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=RapydSentinel" --region us-east-1 --query "Vpcs[].VpcId" --output text 2>/dev/null); do
        for eni in $(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$vpc_id" --region us-east-1 --query "NetworkInterfaces[?Status=='available'].NetworkInterfaceId" --output text 2>/dev/null); do
            echo "Deleting orphaned ENI: $eni"
            aws ec2 delete-network-interface --network-interface-id "$eni" --region us-east-1 || true
        done
        
        # Force detach and delete ENIs that are still attached
        for eni in $(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$vpc_id" --region us-east-1 --query "NetworkInterfaces[?contains(Description, 'ELB')].NetworkInterfaceId" --output text 2>/dev/null); do
            attachment=$(aws ec2 describe-network-interfaces --network-interface-ids "$eni" --region us-east-1 --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text 2>/dev/null || echo "")
            if [ ! -z "$attachment" ] && [ "$attachment" != "None" ]; then
                echo "Force detaching ENI: $eni"
                aws ec2 detach-network-interface --attachment-id "$attachment" --force --region us-east-1 || true
                sleep 5
            fi
            echo "Deleting ENI: $eni"
            aws ec2 delete-network-interface --network-interface-id "$eni" --region us-east-1 || true
        done
    done
    
    # Wait for network interfaces to be released
    sleep 20
}

# Destroy Terraform infrastructure
destroy_terraform() {
    echo -e "${YELLOW}Destroying Terraform infrastructure...${NC}"
    cd "$PROJECT_ROOT/terraform/environments/production"
    
    # Initialize terraform with backend config
    terraform init -reconfigure
    
    # First attempt
    terraform destroy -auto-approve || {
        echo -e "${YELLOW}First destroy attempt failed, cleaning up dependencies...${NC}"
        
        # Clean up network dependencies that might be blocking
        cleanup_network_dependencies
        
        # Second attempt
        echo -e "${YELLOW}Retrying terraform destroy...${NC}"
        terraform destroy -auto-approve || {
            echo -e "${RED}Some resources may require manual cleanup${NC}"
            echo "Check AWS Console for remaining resources"
        }
    }
    
    cd "$PROJECT_ROOT"
    echo -e "${GREEN}Terraform infrastructure destroyed${NC}"
}

# Clean up local files
cleanup_local() {
    echo -e "${YELLOW}Cleaning up local files...${NC}"
    
    rm -f "$PROJECT_ROOT/terraform-outputs.json"
    rm -f "$PROJECT_ROOT/terraform/environments/production/tfplan"
    rm -f "$PROJECT_ROOT/terraform/environments/production/.terraform.lock.hcl"
    rm -rf "$PROJECT_ROOT/terraform/environments/production/.terraform"
    
    echo -e "${GREEN}Local cleanup complete${NC}"
}

# Main execution
main() {
    confirm_destroy
    
    echo -e "${YELLOW}Starting full destruction process...${NC}"
    
    # Always do full destroy - Kubernetes first, then Terraform, then local cleanup
    destroy_kubernetes
    destroy_terraform
    cleanup_local
    
    echo -e "${GREEN}Destruction complete!${NC}"
}

main