#!/bin/bash
set -e

# Parse arguments
ACTION="${1:-deploy}"
TARGET="${2:-both}"
IMAGE_TAG="${3:-latest}"

# Environment variables (set by Lambda)
REGION="${REGION}"
BACKEND_CLUSTER="${BACKEND_CLUSTER_NAME}"
GATEWAY_CLUSTER="${GATEWAY_CLUSTER_NAME}"
BACKEND_ECR="${BACKEND_ECR_URL}"
GATEWAY_ECR="${GATEWAY_ECR_URL}"

# Function to update kubeconfig
update_kubeconfig() {
    local cluster_name=$1
    echo "Updating kubeconfig for cluster: $cluster_name"
    rm -f /tmp/kubeconfig
    aws eks update-kubeconfig --name "$cluster_name" --region "$REGION" --kubeconfig /tmp/kubeconfig
    export KUBECONFIG=/tmp/kubeconfig
    
    # Test connectivity
    echo "Testing cluster connectivity..."
    kubectl cluster-info 2>&1 | head -1 || echo "Cluster info failed"
}

# Function to deploy backend
deploy_backend() {
    echo "Deploying backend service..."
    
    # Deploy a simple backend that returns node information
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-service
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: busybox:latest
        command: ["/bin/sh"]
        args: 
        - -c
        - |
          while true; do
            printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nHello from backend pod:%s on node:%s\r\n" "\$POD_NAME" "\$NODE_NAME" | nc -l -p 5678
          done
        ports:
        - containerPort: 5678
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: default
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 5678
    protocol: TCP
EOF
}

# Function to get backend service URL
get_backend_url() {
    echo "Getting backend service URL..."
    update_kubeconfig "$BACKEND_CLUSTER"
    
    # Wait for load balancer to be ready
    for i in {1..30}; do
        BACKEND_URL=$(kubectl get service backend-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$BACKEND_URL" ]; then
            echo "Backend URL: $BACKEND_URL"
            break
        fi
        echo "Waiting for backend load balancer... (attempt $i/30)"
        sleep 5
    done
    
    if [ -z "$BACKEND_URL" ]; then
        echo "Warning: Could not get backend URL, using placeholder"
        BACKEND_URL="backend-not-available"
    fi
}

# Function to deploy gateway
deploy_gateway() {
    echo "Deploying gateway with nginx"
    
    # First, get the backend service LoadBalancer URL
    echo "Getting backend LoadBalancer URL..."
    # Switch to backend cluster
    aws eks update-kubeconfig --name "$BACKEND_CLUSTER" --region "$REGION" --kubeconfig /tmp/kubeconfig
    export KUBECONFIG=/tmp/kubeconfig
    
    # Get backend LB hostname or IP
    BACKEND_LB=""
    for i in {1..20}; do
        # Try to get hostname first, then IP
        BACKEND_LB=$(kubectl get service backend-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -z "$BACKEND_LB" ]; then
            BACKEND_LB=$(kubectl get service backend-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        fi
        if [ -n "$BACKEND_LB" ]; then
            echo "Backend LoadBalancer URL: $BACKEND_LB"
            # For cross-VPC access, we need to use port 80 explicitly
            break
        fi
        echo "Waiting for backend LoadBalancer... (attempt $i/20)"
        sleep 3
    done
    
    # Switch back to gateway cluster
    aws eks update-kubeconfig --name "$GATEWAY_CLUSTER" --region "$REGION" --kubeconfig /tmp/kubeconfig
    export KUBECONFIG=/tmp/kubeconfig
    
    # Delete old ConfigMap and create new one to force update
    echo "Deleting old nginx-config ConfigMap..."
    kubectl delete configmap nginx-config -n default --ignore-not-found=true || echo "Delete failed or not found"
    echo "ConfigMap delete command completed"
    
    # Create ConfigMap for nginx config
    echo "Creating new nginx-config ConfigMap with backend URL: ${BACKEND_LB:-not-available}"
    
    if [ -n "$BACKEND_LB" ]; then
        # Config with backend proxy
        kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: default
data:
  default.conf: |
    server {
        listen 80;
        server_name _;
        
        location /health {
            access_log off;
            return 200 "healthy\\n";
            add_header Content-Type text/plain;
        }
        
        location / {
            proxy_pass http://${BACKEND_LB}:80/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_connect_timeout 10s;
            proxy_read_timeout 10s;
        }
    }
EOF
    else
        # Config without backend proxy
        kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: default
data:
  default.conf: |
    server {
        listen 80;
        server_name _;
        
        location /health {
            access_log off;
            return 200 "healthy\\n";
            add_header Content-Type text/plain;
        }
        
        location / {
            return 200 "Gateway ready. Backend LoadBalancer not available yet.\\n";
            add_header Content-Type text/plain;
        }
    }
EOF
    fi

    # Deploy nginx gateway
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gateway-proxy
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gateway
  template:
    metadata:
      labels:
        app: gateway
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
---
apiVersion: v1
kind: Service
metadata:
  name: gateway-service
  namespace: default
spec:
  type: LoadBalancer
  selector:
    app: gateway
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
EOF
    
    # Restart gateway pods to pick up new config
    echo "Restarting gateway pods to apply new configuration..."
    kubectl rollout restart deployment/gateway-proxy -n default
    echo "Gateway deployment restarted"
}

# Function to get status
get_status() {
    echo "Getting deployment status..."
    kubectl get deployments -o json | jq '{
        deployments: [.items[] | {
            name: .metadata.name,
            namespace: .metadata.namespace,
            replicas: .status.replicas,
            ready: .status.readyReplicas
        }]
    }'
}

# Function to rollback
rollback() {
    echo "Rolling back deployments..."
    kubectl get deployments -o name | while read deployment; do
        echo "Restarting $deployment"
        kubectl rollout restart "$deployment"
    done
}

# Main execution
echo "Starting deployment script"
echo "Action: $ACTION, Target: $TARGET, Image Tag: $IMAGE_TAG"

# Handle logs action
if [ "$ACTION" = "logs" ]; then
    echo "Fetching logs..."
    
    if [ "$TARGET" = "gateway" ] || [ "$TARGET" = "both" ]; then
        echo "=== Gateway Nginx Logs ==="
        update_kubeconfig "$GATEWAY_CLUSTER"
        kubectl logs deployment/gateway-proxy -n default --tail=30 2>&1 || echo "No logs available"
    fi
    
    if [ "$TARGET" = "backend" ] || [ "$TARGET" = "both" ]; then
        echo "=== Backend Service Logs ==="
        update_kubeconfig "$BACKEND_CLUSTER"
        kubectl logs deployment/backend-service -n default --tail=30 2>&1 || echo "No logs available"
    fi
    
    exit 0
fi

# Handle test action
if [ "$ACTION" = "test" ]; then
    echo "Testing Lambda container..."
    echo "AWS CLI version: $(aws --version 2>&1)"
    echo "kubectl version: $(kubectl version --client -o json 2>/dev/null | jq -r .clientVersion.gitVersion || echo 'not found')"
    echo "Region: $REGION"
    echo "Backend cluster: $BACKEND_CLUSTER"
    echo "Gateway cluster: $GATEWAY_CLUSTER"
    exit 0
fi

# Handle configure action - adds Lambda role to backend cluster aws-auth
if [ "$ACTION" = "configure" ]; then
    echo "Configuring Lambda access to backend cluster..."
    
    # Get Lambda execution role ARN from metadata
    LAMBDA_ROLE_ARN=$(aws sts get-caller-identity --query Arn --output text | sed 's/:assumed-role/role/' | sed 's/\/[^\/]*$//')
    echo "Lambda role ARN: $LAMBDA_ROLE_ARN"
    
    # Update kubeconfig for backend cluster
    update_kubeconfig "$BACKEND_CLUSTER"
    
    # Try to get aws-auth ConfigMap
    if kubectl get configmap aws-auth -n kube-system >/dev/null 2>&1; then
        echo "aws-auth ConfigMap exists, updating..."
        
        # Apply the updated aws-auth with Lambda role
        kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::992553183326:role/eks-backend-node-role
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: $LAMBDA_ROLE_ARN
      username: lambda-deployer
      groups:
        - system:masters
EOF
        echo "Backend cluster aws-auth updated with Lambda role"
    else
        echo "Error: aws-auth ConfigMap not found"
        exit 1
    fi
    
    exit 0
fi

# Process based on target
case "$TARGET" in
    backend|both)
        update_kubeconfig "$BACKEND_CLUSTER"
        case "$ACTION" in
            deploy)
                deploy_backend
                ;;
            status)
                get_status
                ;;
            rollback)
                rollback
                ;;
            delete)
                echo "Deleting backend service..."
                kubectl delete service backend-service -n default --ignore-not-found=true
                kubectl delete deployment backend-service -n default --ignore-not-found=true
                echo "Backend service deleted"
                ;;
            *)
                echo "Unknown action: $ACTION"
                ;;
        esac
        
        if [ "$TARGET" = "backend" ]; then
            exit 0
        fi
        ;;
esac

case "$TARGET" in
    gateway|both)
        update_kubeconfig "$GATEWAY_CLUSTER"
        case "$ACTION" in
            deploy)
                deploy_gateway
                ;;
            status)
                get_status
                ;;
            rollback)
                rollback
                ;;
        esac
        ;;
esac

echo "Deployment script completed successfully"