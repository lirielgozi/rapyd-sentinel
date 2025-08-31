output "peering_connection_id" {
  description = "ID of the VPC peering connection"
  value       = aws_vpc_peering_connection.gateway_to_backend.id
}

output "peering_connection_status" {
  description = "Status of the VPC peering connection"
  value       = aws_vpc_peering_connection.gateway_to_backend.accept_status
}

output "gateway_to_backend_routes" {
  description = "Route IDs from Gateway to Backend"
  value       = aws_route.gateway_private_to_backend[*].id
}

output "backend_to_gateway_routes" {
  description = "Route IDs from Backend to Gateway"
  value       = aws_route.backend_to_gateway[*].id
}