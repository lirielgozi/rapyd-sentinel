# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  # Enable API authentication mode to support EKS Access Entries
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  encryption_config {
    provider {
      key_arn = var.enable_cluster_encryption ? (
        var.cluster_encryption_kms_key_id != "" ? 
        var.cluster_encryption_kms_key_id : 
        aws_kms_key.eks[0].arn
      ) : ""
    }
    resources = var.enable_cluster_encryption ? ["secrets"] : []
  }

  enabled_cluster_log_types = var.cluster_enabled_log_types

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller
  ]

  # Ignore changes to endpoint access since we manage this via deploy-all.sh
  lifecycle {
    ignore_changes = [
      vpc_config[0].endpoint_public_access,
      vpc_config[0].endpoint_private_access,
      vpc_config[0].public_access_cidrs
    ]
  }
}