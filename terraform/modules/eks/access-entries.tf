# EKS Access Entries - Modern way to manage cluster access via AWS API
# This works even with private clusters since it uses AWS API, not Kubernetes API

# Access entry for Lambda deployer role
resource "aws_eks_access_entry" "lambda_deployer" {
  count = var.enable_lambda_access ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.lambda_deployer_role_arn
  type         = "STANDARD"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-lambda-access"
    }
  )
}

# Grant cluster admin permissions to Lambda deployer
resource "aws_eks_access_policy_association" "lambda_deployer_admin" {
  count = var.enable_lambda_access ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.lambda_deployer_role_arn
  policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  
  access_scope {
    type = "cluster"
  }
  
  depends_on = [aws_eks_access_entry.lambda_deployer]
}