locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Region      = var.region
  }

  # Gateway VPC subnet configuration
  gateway_private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  gateway_public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]

  # Backend VPC subnet configuration
  backend_private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
  backend_public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24"]

  # Cluster names
  gateway_cluster_name = "eks-gateway"
  backend_cluster_name = "eks-backend"
}