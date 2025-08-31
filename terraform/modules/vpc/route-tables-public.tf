# Route Table for Public Subnets (Gateway VPC only)
resource "aws_route_table" "public" {
  count = local.create_public_resources ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.vpc_name}-public-rt"
      Type = "Public"
    }
  )
}

# Route to Internet Gateway for Public Subnets
resource "aws_route" "public_internet" {
  count = local.create_public_resources ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count = local.create_public_resources ? length(var.public_subnet_cidrs) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}