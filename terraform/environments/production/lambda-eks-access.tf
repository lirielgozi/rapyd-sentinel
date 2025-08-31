# Allow Lambda to access backend EKS cluster API
resource "aws_security_group_rule" "lambda_to_backend_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = module.lambda_deployer.security_group_id
  security_group_id        = module.eks_backend.cluster_security_group_id
  description              = "Allow Lambda deployer to access Backend EKS API"
}

# Allow Lambda to access gateway EKS cluster API (via VPC peering)
resource "aws_security_group_rule" "lambda_to_gateway_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = module.lambda_deployer.security_group_id
  security_group_id        = module.eks_gateway.cluster_security_group_id
  description              = "Allow Lambda deployer to access Gateway EKS API"
}