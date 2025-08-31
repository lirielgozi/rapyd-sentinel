# Gateway VPC - Public facing layer
module "vpc_gateway" {
  source = "../../modules/vpc"

  vpc_name = "vpc-gateway"
  vpc_type = "gateway"
  vpc_cidr = var.gateway_vpc_cidr
  
  azs                  = var.azs
  private_subnet_cidrs = local.gateway_private_subnet_cidrs
  public_subnet_cidrs  = local.gateway_public_subnet_cidrs
  
  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_flow_logs     = true
  
  environment = var.environment
  tags        = local.common_tags
}