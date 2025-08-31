#!/bin/bash
set -o xtrace

# Bootstrap EKS node
/etc/eks/bootstrap.sh ${cluster_name}

# Wait for node to be ready
sleep 30

# Configure kubectl
aws eks update-kubeconfig --name ${cluster_name} --region ${region}

# Update aws-auth ConfigMap to include Lambda deployer role
if [ -n "${lambda_deployer_role_arn}" ]; then
  echo "Adding Lambda deployer role to aws-auth ConfigMap..."
  
  # Check if aws-auth exists
  if kubectl get configmap aws-auth -n kube-system >/dev/null 2>&1; then
    echo "aws-auth ConfigMap exists, patching it..."
    
    # Get current aws-auth
    kubectl get configmap aws-auth -n kube-system -o yaml > /tmp/aws-auth.yaml
    
    # Check if Lambda role already exists
    if ! grep -q "${lambda_deployer_role_arn}" /tmp/aws-auth.yaml; then
      # Create the updated aws-auth ConfigMap
      cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${node_role_arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: ${lambda_deployer_role_arn}
      username: lambda-deployer
      groups:
        - system:masters
EOF
      echo "Lambda deployer role added to aws-auth"
    else
      echo "Lambda deployer role already in aws-auth"
    fi
  else
    echo "aws-auth ConfigMap not found, creating it..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${node_role_arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: ${lambda_deployer_role_arn}
      username: lambda-deployer
      groups:
        - system:masters
EOF
    echo "aws-auth ConfigMap created with Lambda deployer role"
  fi
fi

echo "User data script completed"