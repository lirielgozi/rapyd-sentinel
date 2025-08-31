# Routes from Gateway VPC to Backend VPC (Private Routes)
resource "aws_route" "gateway_private_to_backend" {
  count = length(var.gateway_private_route_table_ids)

  route_table_id            = var.gateway_private_route_table_ids[count.index]
  destination_cidr_block    = var.backend_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.gateway_to_backend.id
}

# Routes from Gateway VPC to Backend VPC (Public Routes if they exist)
resource "aws_route" "gateway_public_to_backend" {
  count = length(var.gateway_public_route_table_ids)

  route_table_id            = var.gateway_public_route_table_ids[count.index]
  destination_cidr_block    = var.backend_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.gateway_to_backend.id
}

# Routes from Backend VPC to Gateway VPC
resource "aws_route" "backend_to_gateway" {
  count = length(var.backend_private_route_table_ids)

  route_table_id            = var.backend_private_route_table_ids[count.index]
  destination_cidr_block    = var.gateway_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.gateway_to_backend.id
}