# Local values for the VPC module
locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      VPCType     = var.vpc_type
      ManagedBy   = "Terraform"
      Project     = "RapydSentinel"
    }
  )
  
  # Determine if we need public resources (both VPCs need them)
  create_public_resources = length(var.public_subnet_cidrs) > 0 ? true : false
  
  # NAT Gateway configuration
  nat_gateway_count = var.enable_nat_gateway && local.create_public_resources ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0
}