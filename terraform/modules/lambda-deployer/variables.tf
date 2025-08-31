variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "use_existing_role" {
  description = "Whether to use an existing IAM role for the Lambda function"
  type        = bool
  default     = false
}

variable "existing_role_arn" {
  description = "ARN of an existing IAM role for the Lambda function (required if use_existing_role is true)"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC ID where Lambda will run"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs where Lambda will run"
  type        = list(string)
}

variable "backend_cluster_name" {
  description = "Name of the backend EKS cluster"
  type        = string
}

variable "gateway_cluster_name" {
  description = "Name of the gateway EKS cluster"
  type        = string
}

variable "backend_cluster_endpoint" {
  description = "Backend EKS cluster endpoint"
  type        = string
}

variable "gateway_cluster_endpoint" {
  description = "Gateway EKS cluster endpoint"
  type        = string
}

variable "backend_cluster_ca" {
  description = "Backend EKS cluster certificate authority data"
  type        = string
  sensitive   = true
}

variable "gateway_cluster_ca" {
  description = "Gateway EKS cluster certificate authority data"
  type        = string
  sensitive   = true
}

variable "backend_ecr_url" {
  description = "Backend ECR repository URL"
  type        = string
}

variable "gateway_ecr_url" {
  description = "Gateway ECR repository URL"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}