variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "rapyd-sentinel"
}

# VPC Configuration
variable "gateway_vpc_cidr" {
  description = "CIDR block for Gateway VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "backend_vpc_cidr" {
  description = "CIDR block for Backend VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "azs" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# EKS Configuration
variable "eks_cluster_version" {
  description = "Kubernetes version for EKS clusters"
  type        = string
  default     = "1.33"
}

variable "node_instance_types" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  description = "Desired size of node groups"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum size of node groups"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum size of node groups"
  type        = number
  default     = 4
}

# Cost Optimization
variable "single_nat_gateway" {
  description = "Use single NAT gateway per VPC for cost optimization"
  type        = bool
  default     = true
}

variable "node_capacity_type" {
  description = "Capacity type for nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}