# Allow Lambda to access backend EKS cluster API (same VPC)
resource "aws_security_group_rule" "lambda_to_backend_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = module.lambda_deployer.security_group_id
  security_group_id        = module.eks_backend.cluster_security_group_id
  description              = "Allow Lambda deployer to access Backend EKS API"
}

# Allow Gateway EKS cluster to accept connections from Lambda (cross-VPC via peering)
# Must use CIDR blocks for cross-VPC rules, not security group references
resource "aws_security_group_rule" "gateway_cluster_from_lambda" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [module.vpc_backend.vpc_cidr]  # Backend VPC CIDR where Lambda runs
  security_group_id = module.eks_gateway.cluster_security_group_id
  description       = "Allow Lambda deployer (from Backend VPC) to access Gateway EKS API"
}

# Lambda module already includes egress to 0.0.0.0/0, so we don't need to add it again