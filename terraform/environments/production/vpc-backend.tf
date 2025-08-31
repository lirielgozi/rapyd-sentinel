# Backend VPC - Private internal layer
module "vpc_backend" {
  source = "../../modules/vpc"

  vpc_name = "vpc-backend"
  vpc_type = "backend"
  vpc_cidr = var.backend_vpc_cidr
  
  azs                  = var.azs
  private_subnet_cidrs = local.backend_private_subnet_cidrs
  public_subnet_cidrs  = local.backend_public_subnet_cidrs
  
  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_flow_logs     = true
  
  environment = var.environment
  tags        = local.common_tags
}