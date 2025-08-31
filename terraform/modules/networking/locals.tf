# Local values for the networking module
locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "RapydSentinel"
      Module      = "networking"
    }
  )
}