# Allow Gateway VPC to communicate with Backend cluster
resource "aws_security_group_rule" "gateway_to_backend_cluster" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = var.backend_cluster_security_group_id
  cidr_blocks       = [var.gateway_vpc_cidr]
  description       = "Allow Gateway VPC to communicate with Backend cluster API"
}

# Allow Gateway VPC to communicate with Backend nodes
resource "aws_security_group_rule" "gateway_to_backend_nodes" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = var.backend_node_security_group_id
  cidr_blocks       = [var.gateway_vpc_cidr]
  description       = "Allow Gateway VPC to communicate with Backend services"
}

# Allow Backend VPC to respond to Gateway nodes
resource "aws_security_group_rule" "backend_to_gateway_nodes" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = var.gateway_node_security_group_id
  cidr_blocks       = [var.backend_vpc_cidr]
  description       = "Allow Backend VPC to respond to Gateway nodes"
}

# Allow HTTPS traffic from Gateway to Backend
resource "aws_security_group_rule" "gateway_to_backend_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = var.backend_node_security_group_id
  cidr_blocks       = [var.gateway_vpc_cidr]
  description       = "Allow HTTPS from Gateway VPC"
}

# Allow HTTP traffic from Gateway to Backend (for internal services)
resource "aws_security_group_rule" "gateway_to_backend_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = var.backend_node_security_group_id
  cidr_blocks       = [var.gateway_vpc_cidr]
  description       = "Allow HTTP from Gateway VPC"
}

# Allow custom application ports from Gateway to Backend
resource "aws_security_group_rule" "gateway_to_backend_app" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = var.backend_node_security_group_id
  cidr_blocks       = [var.gateway_vpc_cidr]
  description       = "Allow application traffic from Gateway VPC"
}

# Allow DNS resolution between VPCs
resource "aws_security_group_rule" "gateway_to_backend_dns_tcp" {
  type              = "ingress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  security_group_id = var.backend_node_security_group_id
  cidr_blocks       = [var.gateway_vpc_cidr]
  description       = "Allow DNS TCP from Gateway VPC"
}

resource "aws_security_group_rule" "gateway_to_backend_dns_udp" {
  type              = "ingress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  security_group_id = var.backend_node_security_group_id
  cidr_blocks       = [var.gateway_vpc_cidr]
  description       = "Allow DNS UDP from Gateway VPC"
}