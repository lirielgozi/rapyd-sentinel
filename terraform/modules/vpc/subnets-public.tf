# Public Subnets (only for Gateway VPC to host NAT Gateways and Load Balancers)
resource "aws_subnet" "public" {
  count = local.create_public_resources ? length(var.public_subnet_cidrs) : 0

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name                                         = "${var.vpc_name}-public-${var.azs[count.index]}"
      Type                                         = "Public"
      "kubernetes.io/role/elb"                    = "1"
      "kubernetes.io/cluster/eks-${var.vpc_type}" = "shared"
    }
  )
}