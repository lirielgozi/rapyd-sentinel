# EKS Cluster for Gateway Layer
module "eks_gateway" {
  source = "../../modules/eks"

  cluster_name    = local.gateway_cluster_name
  cluster_version = var.eks_cluster_version
  region          = var.region
  
  vpc_id     = module.vpc_gateway.vpc_id
  subnet_ids = module.vpc_gateway.private_subnet_ids
  
  # API endpoint access - Gateway can have limited public access
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] # Restrict this in production
  
  # Encryption
  enable_cluster_encryption = true
  
  # Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  # Node group configuration
  node_group_name         = "gateway-nodes"
  node_group_desired_size = var.node_group_desired_size
  node_group_min_size     = var.node_group_min_size
  node_group_max_size     = var.node_group_max_size
  node_instance_types     = var.node_instance_types
  node_capacity_type      = var.node_capacity_type
  node_disk_size          = 30
  
  # IRSA
  enable_irsa = true
  
  # Use EKS Access Entries for Lambda role (consistent with Backend)
  manage_aws_auth = false
  additional_iam_roles = []
  
  # Lambda role configured via EKS Access Entries
  lambda_deployer_role_arn = aws_iam_role.lambda_deployer.arn
  
  environment = var.environment
  tags        = local.common_tags
  
  # Kubernetes provider configuration
  providers = {
    kubernetes = kubernetes.gateway
  }
}