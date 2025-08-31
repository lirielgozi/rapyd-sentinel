# VPC Peering Connection
resource "aws_vpc_peering_connection" "gateway_to_backend" {
  vpc_id      = var.gateway_vpc_id
  peer_vpc_id = var.backend_vpc_id
  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = var.enable_dns_resolution
  }

  requester {
    allow_remote_vpc_dns_resolution = var.enable_dns_resolution
  }

  tags = merge(
    local.common_tags,
    {
      Name = "gateway-to-backend-peering"
      From = "gateway"
      To   = "backend"
    }
  )
}