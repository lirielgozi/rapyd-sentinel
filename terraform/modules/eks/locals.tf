# Local values for the EKS module
locals {
  common_tags = merge(
    var.tags,
    {
      Environment  = var.environment
      ManagedBy    = "Terraform"
      Project      = "RapydSentinel"
      ClusterName  = var.cluster_name
    }
  )
}