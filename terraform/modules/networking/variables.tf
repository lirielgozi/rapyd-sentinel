variable "gateway_vpc_id" {
  description = "ID of the Gateway VPC"
  type        = string
}

variable "backend_vpc_id" {
  description = "ID of the Backend VPC"
  type        = string
}

variable "gateway_vpc_cidr" {
  description = "CIDR block of the Gateway VPC"
  type        = string
}

variable "backend_vpc_cidr" {
  description = "CIDR block of the Backend VPC"
  type        = string
}

variable "gateway_private_route_table_ids" {
  description = "List of private route table IDs in Gateway VPC"
  type        = list(string)
}

variable "backend_private_route_table_ids" {
  description = "List of private route table IDs in Backend VPC"
  type        = list(string)
}

variable "gateway_public_route_table_ids" {
  description = "List of public route table IDs in Gateway VPC"
  type        = list(string)
  default     = []
}

variable "gateway_cluster_security_group_id" {
  description = "Security group ID of the Gateway EKS cluster"
  type        = string
}

variable "backend_cluster_security_group_id" {
  description = "Security group ID of the Backend EKS cluster"
  type        = string
}

variable "gateway_node_security_group_id" {
  description = "Security group ID of the Gateway EKS nodes"
  type        = string
}

variable "backend_node_security_group_id" {
  description = "Security group ID of the Backend EKS nodes"
  type        = string
}

variable "enable_dns_resolution" {
  description = "Enable DNS resolution across peered VPCs"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}