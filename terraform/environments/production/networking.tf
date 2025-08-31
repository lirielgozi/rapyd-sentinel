# VPC Peering and Cross-VPC Networking
module "networking" {
  source = "../../modules/networking"

  # VPC IDs
  gateway_vpc_id = module.vpc_gateway.vpc_id
  backend_vpc_id = module.vpc_backend.vpc_id
  
  # VPC CIDRs
  gateway_vpc_cidr = var.gateway_vpc_cidr
  backend_vpc_cidr = var.backend_vpc_cidr
  
  # Route Tables
  gateway_private_route_table_ids = module.vpc_gateway.private_route_table_ids
  gateway_public_route_table_ids  = module.vpc_gateway.public_route_table_ids
  backend_private_route_table_ids = module.vpc_backend.private_route_table_ids
  
  # Security Groups
  gateway_cluster_security_group_id = module.eks_gateway.cluster_security_group_id
  backend_cluster_security_group_id = module.eks_backend.cluster_security_group_id
  gateway_node_security_group_id    = module.eks_gateway.node_security_group_id
  backend_node_security_group_id    = module.eks_backend.node_security_group_id
  
  # DNS
  enable_dns_resolution = true
  
  environment = var.environment
  tags        = local.common_tags
  
  depends_on = [
    module.vpc_gateway,
    module.vpc_backend,
    module.eks_gateway,
    module.eks_backend
  ]
}