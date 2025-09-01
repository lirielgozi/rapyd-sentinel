# EKS Cluster for Backend Layer
module "eks_backend" {
  source = "../../modules/eks"

  cluster_name    = local.backend_cluster_name
  cluster_version = var.eks_cluster_version
  region          = var.region
  
  vpc_id     = module.vpc_backend.vpc_id
  subnet_ids = module.vpc_backend.private_subnet_ids
  
  # API endpoint access - Backend is completely private
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false
  cluster_endpoint_public_access_cidrs = []
  
  # Encryption
  enable_cluster_encryption = true
  
  # Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  # Node group configuration
  node_group_name         = "backend-nodes"
  node_group_desired_size = var.node_group_desired_size
  node_group_min_size     = var.node_group_min_size
  node_group_max_size     = var.node_group_max_size
  node_instance_types     = var.node_instance_types
  node_capacity_type      = var.node_capacity_type
  node_disk_size          = 30
  
  # IRSA
  enable_irsa = true
  
  # Use EKS Access Entries for Lambda role (works with private clusters)
  manage_aws_auth = false
  additional_iam_roles = []
  
  # Lambda role configured via EKS Access Entries
  enable_lambda_access = true
  lambda_deployer_role_arn = aws_iam_role.lambda_deployer.arn
  
  environment = var.environment
  tags        = local.common_tags
  
  # Kubernetes provider configuration
  providers = {
    kubernetes = kubernetes.backend
  }
}