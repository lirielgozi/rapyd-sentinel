# Private Subnets (for both VPC types - EKS nodes go here)
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(
    local.common_tags,
    {
      Name                                         = "${var.vpc_name}-private-${var.azs[count.index]}"
      Type                                         = "Private"
      "kubernetes.io/role/internal-elb"           = "1"
      "kubernetes.io/cluster/eks-${var.vpc_type}" = "shared"
    }
  )
}