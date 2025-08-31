# VPC Outputs
output "gateway_vpc_id" {
  description = "ID of the Gateway VPC"
  value       = module.vpc_gateway.vpc_id
}

output "backend_vpc_id" {
  description = "ID of the Backend VPC"
  value       = module.vpc_backend.vpc_id
}

output "gateway_vpc_cidr" {
  description = "CIDR block of Gateway VPC"
  value       = module.vpc_gateway.vpc_cidr
}

output "backend_vpc_cidr" {
  description = "CIDR block of Backend VPC"
  value       = module.vpc_backend.vpc_cidr
}

# EKS Outputs
output "gateway_cluster_endpoint" {
  description = "Endpoint for Gateway EKS cluster"
  value       = module.eks_gateway.cluster_endpoint
  sensitive   = true
}

output "backend_cluster_endpoint" {
  description = "Endpoint for Backend EKS cluster"
  value       = module.eks_backend.cluster_endpoint
  sensitive   = true
}

output "gateway_cluster_name" {
  description = "Name of the Gateway EKS cluster"
  value       = module.eks_gateway.cluster_name
}

output "backend_cluster_name" {
  description = "Name of the Backend EKS cluster"
  value       = module.eks_backend.cluster_name
}

# ECR Outputs
output "backend_ecr_repository_url" {
  description = "URL of the Backend ECR repository"
  value       = aws_ecr_repository.backend.repository_url
}

output "gateway_ecr_repository_url" {
  description = "URL of the Gateway ECR repository"
  value       = aws_ecr_repository.gateway.repository_url
}

# Networking Outputs
output "peering_connection_id" {
  description = "ID of the VPC peering connection"
  value       = module.networking.peering_connection_id
}

# Commands for kubectl configuration
output "update_kubeconfig_commands" {
  description = "Commands to update kubeconfig for both clusters"
  value = {
    gateway = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks_gateway.cluster_name}"
    backend = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks_backend.cluster_name}"
  }
}