# Internet Gateway (only for Gateway VPC)
resource "aws_internet_gateway" "main" {
  count = local.create_public_resources ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.vpc_name}-igw"
    }
  )
}