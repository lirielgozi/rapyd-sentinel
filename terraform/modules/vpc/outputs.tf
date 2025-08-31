output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = local.create_public_resources ? aws_subnet.public[*].id : []
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = local.create_public_resources ? aws_subnet.public[*].cidr_block : []
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "List of public IPs assigned to NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = local.create_public_resources ? aws_internet_gateway.main[0].id : null
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = aws_route_table.private[*].id
}

output "public_route_table_ids" {
  description = "List of public route table IDs"
  value       = local.create_public_resources ? aws_route_table.public[*].id : []
}

output "vpc_type" {
  description = "Type of VPC (gateway or backend)"
  value       = var.vpc_type
}

output "azs" {
  description = "Availability zones used"
  value       = var.azs
}