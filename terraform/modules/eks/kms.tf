# KMS key for EKS cluster encryption
resource "aws_kms_key" "eks" {
  count = var.enable_cluster_encryption && var.cluster_encryption_kms_key_id == "" ? 1 : 0

  description             = "EKS Secret Encryption Key for ${var.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-eks-cmk"
    }
  )
}

resource "aws_kms_alias" "eks" {
  count = var.enable_cluster_encryption && var.cluster_encryption_kms_key_id == "" ? 1 : 0

  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks[0].key_id
}